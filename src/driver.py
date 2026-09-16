import logging
import subprocess
import time

from appium import webdriver
from appium.options.android.uiautomator2.base import UiAutomator2Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from selenium.common.exceptions import (
    TimeoutException,
    WebDriverException,
    InvalidSessionIdException,
)

from src.retry import retry
from src.artifacts import ArtifactManager
from src.reporter import RunReporter

# Substrings in exception messages that indicate the Appium session or ADB
# connection is gone rather than a normal UI timeout.
_SESSION_ERROR_PHRASES = (
    "invalid session id",
    "session not created",
    "no such session",
    "socket hang up",
    "connection reset",
    "connection refused",
    "adb connection",
    "broken pipe",
)


class AndroidDriver:
    def __init__(
        self,
        a_cfg: dict,
        selectors: dict,
        artifacts: ArtifactManager,
        reporter: RunReporter,
    ):
        self.cfg = a_cfg
        self.sel = selectors
        self.artifacts = artifacts
        self.reporter = reporter
        self._last_adb_reconnect_at: float = 0.0
        self.drv = self._connect()

    # ------------------------------------------------------------------
    # Connection
    # ------------------------------------------------------------------

    def _build_options(self) -> UiAutomator2Options:
        opts = UiAutomator2Options()
        opts.platform_name = "Android"
        opts.automation_name = "UiAutomator2"
        opts.device_name = self.cfg.get("device_name", "Android")
        opts.no_reset = bool(self.cfg.get("no_reset", True))
        opts.new_command_timeout = int(self.cfg.get("new_command_timeout", 3600))
        udid = self.cfg.get("udid", "")
        if not udid:
            # No UDID in config — try adb_wifi_device.json written by run.command/run.bat
            import json, os
            cache = "automation/runtime/adb_wifi_device.json"
            if os.path.exists(cache):
                try:
                    with open(cache) as _f:
                        _d = json.load(_f)
                    _ip = _d.get("wifi_ip", "")
                    _port = _d.get("tcp_port", 5555)
                    if _ip:
                        udid = f"{_ip}:{_port}"
                except Exception:
                    pass
        if udid:
            opts.udid = udid
        if self.cfg.get("app_package"):
            opts.app_package = self.cfg["app_package"]
        if self.cfg.get("app_activity"):
            opts.app_activity = self.cfg["app_activity"]
        return opts

    def _connect(self) -> webdriver.Remote:
        server = self.cfg.get("appium_server_url", "http://127.0.0.1:4723")
        self.reporter.log_event("appium_connect", {"server": server})
        return webdriver.Remote(server, options=self._build_options())

    def _ensure_adb_connected(self) -> None:
        """
        Re-establish WiFi ADB before creating a new Appium session.
        The ADB WiFi TCP connection is dropped when the host computer sleeps.
        Reads the cached address from automation/runtime/adb_wifi_device.json,
        or uses the UDID directly if it is already an ip:port address.
        Non-blocking — errors are logged but never raised.
        """
        import json
        import os

        udid = self.cfg.get("udid", "")
        wifi_addr = None

        # Case 1: UDID is already a WiFi address (ip:port, no leading slash)
        if udid and ":" in udid and not udid.startswith("/"):
            wifi_addr = udid

        # Case 2: read cached address written by run.command / run.bat
        if not wifi_addr:
            cache = "automation/runtime/adb_wifi_device.json"
            if os.path.exists(cache):
                try:
                    with open(cache) as f:
                        data = json.load(f)
                    ip = data.get("wifi_ip", "")
                    port = data.get("tcp_port", 5555)
                    if ip:
                        wifi_addr = f"{ip}:{port}"
                except Exception:
                    pass

        if not wifi_addr:
            return

        # Cooldown: skip if already attempted within the last 30 seconds.
        # Prevents duplicate reconnect calls within the same injection cycle
        # regardless of where ensure_session() is invoked.
        now = time.monotonic()
        if now - self._last_adb_reconnect_at < 30:
            return
        self._last_adb_reconnect_at = now

        try:
            self.reporter.log_event("adb_reconnect_attempt", {"addr": wifi_addr})
            result = subprocess.run(
                ["adb", "connect", wifi_addr],
                capture_output=True, text=True, timeout=10,
            )
            output = result.stdout.strip()
            self.reporter.log_event("adb_reconnect_result", {"addr": wifi_addr, "output": output})
            # Only sleep for a genuinely new connection, not "already connected"
            if "connected" in output.lower() and "already" not in output.lower():
                time.sleep(2)  # let ADB stabilize before Appium connects
        except Exception as e:
            self.reporter.log_event("adb_reconnect_failed", {"addr": wifi_addr, "error": str(e)})

    def reconnect(self):
        """
        Re-establish Appium session after a crash or timeout.
        Re-establishes the ADB WiFi connection first (dropped on host sleep),
        then creates a new Appium session and brings the app to foreground.
        """
        logging.warning("[SESSION] recreating driver")
        self.reporter.log_event("session_recreating", {})
        self._last_adb_reconnect_at = 0.0  # reset cooldown: real disconnection must always reconnect
        self._ensure_adb_connected()
        try:
            self.drv.quit()
        except Exception:
            pass
        self.drv = self._connect()
        try:
            self.bring_to_foreground()
        except Exception:
            pass
        logging.info("[SESSION] recovery success")
        self.reporter.log_event("session_recovery_success", {})

    def is_session_alive(self) -> bool:
        """
        Probe the Appium session by making a real network round-trip.
        current_activity exercises the underlying socket, so it will raise
        InvalidSessionIdException, WebDriverException (connection refused),
        or OSError (socket hang up / broken pipe) when the session is gone.
        """
        try:
            _ = self.drv.current_activity
            return True
        except Exception:
            return False

    def ensure_session(self):
        """Check session health; reconnect if dead.
        After host sleep/wake the ADB TCP connection drops, which makes
        is_session_alive() raise a socket/connection error → False.
        reconnect() then calls _ensure_adb_connected() to restore the
        WiFi ADB link before recreating the Appium session.
        """
        if not self.is_session_alive():
            logging.warning("[SESSION] driver lost — session not alive")
            self.reporter.log_event("session_lost", {"reason": "session_not_alive"})
            self.reconnect()

    def close(self):
        try:
            self.drv.quit()
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Locator helpers — priority: resource-id > content-desc > text > xpath
    # ------------------------------------------------------------------

    def _locators_for(self, value: str) -> list[tuple]:
        """
        Build a priority-ordered list of (By, selector) pairs for a given value.
        Callers can also pass a pre-built (By, selector) tuple directly.
        """
        return [
            (By.ID, value),                           # resource-id
            (By.ACCESSIBILITY_ID, value),             # content-desc / accessibility-id
            (By.ANDROID_UIAUTOMATOR, f'new UiSelector().text("{value}")'),
            (By.ANDROID_UIAUTOMATOR, f'new UiSelector().textContains("{value}")'),
        ]

    def find(
        self,
        value: str,
        timeout: int = 10,
        contains: bool = False,
    ):
        """
        Find element trying priority order of selectors.
        If `contains=True`, skip resource-id/accessibility attempts and go
        straight to textContains (useful for partial Korean text).
        """
        if contains:
            locator = (
                By.ANDROID_UIAUTOMATOR,
                f'new UiSelector().textContains("{value}")',
            )
            return WebDriverWait(self.drv, timeout).until(
                EC.presence_of_element_located(locator)
            )

        last_exc = None
        for locator in self._locators_for(value):
            try:
                return WebDriverWait(self.drv, 2).until(
                    EC.presence_of_element_located(locator)
                )
            except Exception as e:
                last_exc = e

        # Final wait with textContains as fallback
        try:
            locator = (
                By.ANDROID_UIAUTOMATOR,
                f'new UiSelector().textContains("{value}")',
            )
            return WebDriverWait(self.drv, timeout).until(
                EC.presence_of_element_located(locator)
            )
        except Exception as e:
            last_exc = e

        raise last_exc

    # Legacy alias used by workflows
    def find_text(self, text: str, timeout: int = 10, contains: bool = False):
        return self.find(text, timeout=timeout, contains=contains)

    @retry(tries=3, delay=2)
    def tap_text(self, text: str | list, timeout: int = 10, contains: bool = True):
        texts = [text] if isinstance(text, str) else text
        per = max(timeout // len(texts), 2)
        last_exc: Exception = Exception(f"Could not find any of: {texts}")
        for t in texts:
            try:
                el = self.find(t, timeout=per, contains=contains)
                loc = el.location
                sz = el.size
                cx = loc["x"] + sz["width"] // 2
                cy = loc["y"] + sz["height"] // 2
                self.drv.tap([(cx, cy)])
                return True
            except Exception as e:
                last_exc = e
        raise last_exc

    def is_visible_text(self, text: str | list, contains: bool = True, timeout: int = 2) -> bool:
        texts = [text] if isinstance(text, str) else text
        for t in texts:
            try:
                self.find(t, timeout=timeout, contains=contains)
                return True
            except Exception:
                pass
        return False

    # ------------------------------------------------------------------
    # Session-safe action wrappers
    # ------------------------------------------------------------------

    def _is_session_error(self, exc: Exception) -> bool:
        """
        Return True if exc indicates a lost Appium session or ADB disconnect
        rather than a normal UI timeout or element-not-found error.
        Catches both typed exceptions and socket-level errors embedded in
        WebDriverException messages (e.g. "socket hang up", "connection reset").
        """
        if isinstance(exc, (InvalidSessionIdException, OSError)):
            return True
        msg = str(exc).lower()
        return any(phrase in msg for phrase in _SESSION_ERROR_PHRASES)

    def safe_tap(self, text: str | list, timeout: int = 10, contains: bool = True) -> bool:
        """
        tap_text wrapper that detects a lost session, recreates the driver,
        then retries the tap once. Use this for all UI taps in long-running
        workflows where the session may drop between interactions.

        Raises the original exception unchanged if the error is not session-related.
        """
        try:
            return self.tap_text(text, timeout=timeout, contains=contains)
        except Exception as exc:
            if self._is_session_error(exc):
                logging.warning("[SESSION] driver lost during tap — %s", exc)
                self.reporter.log_event("session_lost", {"action": "tap", "error": str(exc)})
                self.reconnect()
                return self.tap_text(text, timeout=timeout, contains=contains)
            raise

    def safe_send_keys(self, locator: str, text: str, timeout: int = 10) -> None:
        """
        find + send_keys wrapper that detects a lost session, recreates the
        driver, then retries the action once. Use this for all text input in
        long-running workflows.

        Raises the original exception unchanged if the error is not session-related.
        """
        try:
            el = self.find(locator, timeout=timeout)
            el.send_keys(text)
        except Exception as exc:
            if self._is_session_error(exc):
                logging.warning("[SESSION] driver lost during send_keys — %s", exc)
                self.reporter.log_event("session_lost", {"action": "send_keys", "error": str(exc)})
                self.reconnect()
                el = self.find(locator, timeout=timeout)
                el.send_keys(text)
            else:
                raise

    # ------------------------------------------------------------------
    # Artifact helpers
    # ------------------------------------------------------------------

    def screenshot(self, name: str) -> str:
        return self.artifacts.screenshot(self.drv, name)

    def logcat(self, name: str = "logcat") -> str:
        """
        Capture device logcat via ArtifactManager and emit reporter events.

        Returns the path to the saved log file on success, or None on failure.
        """
        seconds = 2
        try:
            self.reporter.log_event("artifact_logcat_start", {"name": name, "seconds": seconds})
        except Exception:
            # best-effort: don't fail if reporter logging errors
            pass

        try:
            path = self.artifacts.collect_android_logcat(name, seconds=seconds)
            if path:
                try:
                    self.reporter.log_event("artifact_logcat_done", {"name": name, "path": path})
                except Exception:
                    pass
            else:
                try:
                    self.reporter.log_event("artifact_logcat_failed", {"name": name, "error": "collect_android_logcat returned None"})
                except Exception:
                    pass
            return path
        except Exception as e:
            try:
                self.reporter.log_event("artifact_logcat_failed", {"name": name, "error": str(e)})
            except Exception:
                pass
            return None

    # ------------------------------------------------------------------
    # State helpers
    # ------------------------------------------------------------------

    def bring_to_foreground(self):
        pkg = self.cfg.get("app_package")
        if not pkg:
            return
        try:
            # activate_app resumes the app without recreating the Activity
            self.drv.activate_app(pkg)
        except Exception:
            # fallback: start_activity (may recreate Activity on some devices)
            act = self.cfg.get("app_activity")
            if act:
                try:
                    self.drv.start_activity(pkg, act)
                except Exception:
                    pass

    def recover_session(self, step: int = 1) -> bool:
        """
        Attempt to recover a stuck/frozen session in 3 escalating steps.
        Returns True if recovery succeeded, False otherwise.

        Args:
            step: 1 (back key), 2 (start_activity), or 3 (kill/relaunch)
        """
        pkg = self.cfg.get("app_package")
        act = self.cfg.get("app_activity")

        try:
            if step == 1:
                # Step 1: Send back key and wait for app to settle
                self.reporter.log_event("recovery_step_1", {"action": "press_back"})
                self.drv.press_keycode(4)  # KEYCODE_BACK
                self.wait_idle(1.0)
                return True

            elif step == 2:
                # Step 2: Force the app to foreground via activate_app
                self.reporter.log_event("recovery_step_2", {"action": "activate_app"})
                if pkg:
                    self.drv.activate_app(pkg)
                    self.wait_idle(1.5)
                    return True

            elif step == 3:
                # Step 3: Kill the app and restart it
                self.reporter.log_event("recovery_step_3", {"action": "kill_and_relaunch"})
                if pkg:
                    try:
                        self.drv.terminate_app(pkg)
                    except Exception:
                        pass
                    self.wait_idle(1.0)
                    try:
                        self.drv.activate_app(pkg)
                    except Exception:
                        if act:
                            self.drv.start_activity(pkg, act)
                    self.wait_idle(2.0)
                    return True

            return False
        except Exception as e:
            self.reporter.log_event(
                "recovery_failed",
                {"step": step, "error": str(e)},
            )
            # Re-raise so _attempt_recovery in scheduler.py can detect
            # UiAutomator2 instrumentation crashes and call reconnect().
            raise

    def wait_for_symptom_success(self, timeout: int = 10) -> str:
        """
        Wait for confirmation that a symptom was actually registered.

        `symptom_add_text` ("back on the main measurement screen") is NOT a
        valid success signal on its own -- confirmed live (2026-09-16) as a
        real false-positive bug: that screen is what the picker closes back
        to on ANY dismissal, tap-succeeded or not (e.g. a coordinate tap
        that misses the target, or a stray dismiss), so treating it as
        success let a run report "ok" while the Diary tab held only a
        stale entry from a much earlier, genuinely-successful run -- no new
        entry was ever created. When `symptom_success_signal_text` is
        configured, it is the only accepted proof (a real toast/confirmation
        the app only shows after an actual registration); `symptom_add_text`
        is checked only to detect that the attempt is *over* (so the caller
        can stop waiting and fail fast) -- reaching it without the success
        signal is a failure, not a maybe-success. Only when no
        `symptom_success_signal_text` is configured at all (nothing better
        available for that app) does `symptom_add_text` remain the fallback
        signal, same as before.

        Returns the name of the signal that was detected.
        Raises RuntimeError if success was not confirmed within timeout.
        """
        success_signal = self.sel.get("symptom_success_signal_text")
        main_indicator = self.sel.get("symptom_add_text", "Add Symptom")

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if success_signal:
                if self.is_visible_text(success_signal):
                    return "success_signal"
                if self.is_visible_text(main_indicator):
                    # Attempt is over (back on the main screen) but the one
                    # real success signal never showed -- fail now rather
                    # than keep polling for something that isn't coming.
                    raise RuntimeError(
                        f"Symptom success not confirmed: back on the main "
                        f"screen ('{main_indicator}') without seeing the "
                        f"expected confirmation '{success_signal}' -- the "
                        f"tap likely didn't actually register anything."
                    )
            elif self.is_visible_text(main_indicator):
                return "main_screen"
            time.sleep(0.5)

        raise RuntimeError(
            f"Symptom success not confirmed within {timeout}s: "
            f"neither '{success_signal}' nor '{main_indicator}' appeared"
        )

    def assert_ui_health(self):
        """
        Assert that the measurement running screen is visible.
        Uses symptom_add_text selector as the indicator (it's only visible
        when measurement is active and the screen is unobstructed).
        Raises RuntimeError if the indicator is not found — callers should
        treat this as a recoverable failure.
        """
        indicator = self.sel.get("symptom_add_text", "Add Symptom")
        self.reporter.log_event("ui_health_check", {"indicator": indicator})
        if not self.is_visible_text(indicator):
            try:
                self.screenshot("ui_health_failed")
            except Exception:
                pass
            raise RuntimeError(f"UI health check failed: '{indicator}' not visible on screen")
        self.reporter.log_event("ui_health_ok", {"indicator": indicator})

    def wait_idle(self, seconds: float = 1.0):
        time.sleep(seconds)

    def get_device_info(self) -> dict:
        """Query model, manufacturer, Android version via adb shell getprop."""
        udid = self.cfg.get("udid", "")

        def _prop(name: str) -> str:
            try:
                cmd = ["adb"] + (["-s", udid] if udid else []) + ["shell", "getprop", name]
                return subprocess.check_output(cmd, timeout=5).decode().strip()
            except Exception:
                return ""

        return {
            "model": _prop("ro.product.model"),
            "manufacturer": _prop("ro.product.manufacturer"),
            "android_version": _prop("ro.build.version.release"),
            "udid": udid,
        }

    def dump_ui_xml_via_adb(self, timeout: float = 5.0) -> str | None:
        """UI hierarchy XML via the plain `adb shell uiautomator dump` binary,
        bypassing Appium's own `driver.page_source` entirely. Returns None on
        any failure (caller should fall back to `driver.page_source`).

        Confirmed live (2026-09-16) as the fix for a real, reproducible bug:
        Appium's `page_source` call goes through the on-device UiAutomator2
        *instrumentation* (an Appium-injected accessibility service), and
        that call itself can dismiss a transient React Native bottom sheet
        (e.g. the symptom picker) as a side effect — this is why
        `_tap_symptom_item` (symptom_inject.py) already avoids calling
        page_source while the picker is open, per its own comment. But its
        "strategy 0" fallback still needs *some* one-shot XML dump to find
        tap coordinates without polling (polling via find_element has the
        same dismissal risk). The plain `uiautomator dump` shell command
        talks to Android's UiAutomator service directly, not through
        Appium's injected instrumentation, so it doesn't trigger the same
        accessibility-event side effect — confirmed by direct comparison on
        a real device: an Appium `page_source` call during an open picker
        returned XML with no trace of the picker's own items, while an
        `adb shell uiautomator dump` immediately after found them (correct
        `content-desc` on the tappable container) with the picker still
        open afterward, unaffected by the query."""
        udid = self.cfg.get("udid", "")
        adb = ["adb"] + (["-s", udid] if udid else [])
        remote_path = "/sdcard/exautomation_ui_dump.xml"
        try:
            dump_proc = subprocess.run(
                adb + ["shell", "uiautomator", "dump", remote_path],
                capture_output=True, timeout=timeout,
            )
            if dump_proc.returncode != 0:
                self.reporter.log_event("dump_ui_xml_via_adb_failed", {
                    "stage": "dump", "returncode": dump_proc.returncode,
                    "stderr": dump_proc.stderr.decode("utf-8", errors="replace")[:500],
                    "stdout": dump_proc.stdout.decode("utf-8", errors="replace")[:500],
                })
                return None
            out = subprocess.check_output(
                adb + ["shell", "cat", remote_path], timeout=timeout,
            )
            return out.decode("utf-8", errors="replace")
        except Exception as e:
            self.reporter.log_event("dump_ui_xml_via_adb_failed", {
                "stage": "exception", "error": str(e),
            })
            return None

    def get_tab_badge_count(self, tab_text: str | list[str]) -> int:
        """Numeric badge count shown on a bottom-nav-style tab (e.g. the
        "Diary" tab's own unread-count pill), read from a fresh
        `dump_ui_xml_via_adb()` dump. Returns 0 if the tab isn't found, has
        no badge, or the dump itself fails -- callers should treat 0 as
        "no evidence of a badge", not necessarily "definitely zero".

        Added (2026-09-16) as a genuine, app-state-verifying success signal
        for symptom injection: confirmed live that this app shows NO
        distinct success toast at all after registering a symptom (a
        configured `symptom_success_signal_text` selector for one was
        simply wrong -- no such text exists in this app build) -- it only
        silently increments this badge. Comparing this count before/after
        is the one thing that's actually proof a tap registered, as
        opposed to "we're back on the main screen", which is equally true
        whether the tap worked or not.

        Tries `dump_ui_xml_via_adb()` first, falling back to
        `driver.page_source`. Unlike `_tap_symptom_item`'s own strategy-0
        (which must avoid page_source while the picker is open -- see that
        function's comments), this method is only ever called with no
        picker open (right before opening it, and after it has already
        closed), so page_source's dismissal side effect does not apply
        here -- it's a safe, always-available fallback for exactly the
        adb-dump-vs-active-Appium-session conflict documented on
        `dump_ui_xml_via_adb` (SIGKILL/returncode 137 while a session is
        live)."""
        texts = [tab_text] if isinstance(tab_text, str) else list(tab_text)
        xml = self.dump_ui_xml_via_adb() or self.drv.page_source
        if not xml:
            return 0
        import re
        import xml.etree.ElementTree as ET
        try:
            root = ET.fromstring(xml)
        except Exception:
            return 0

        def _bounds(node):
            m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
            return tuple(int(g) for g in m.groups()) if m else None

        tab_bounds = None
        for node in root.iter():
            node_text = node.get("text", "")
            node_desc = node.get("content-desc", "")
            if any(t and (t == node_text or t == node_desc) for t in texts):
                b = _bounds(node)
                if b:
                    tab_bounds = b
                    break
        if not tab_bounds:
            return 0
        tx1, ty1, tx2, ty2 = tab_bounds
        # The badge is a numeric-only TextView positioned over the tab
        # (confirmed live: NOT a DOM descendant of the tab's own node --
        # it's a sibling overlay whose bounds spatially overlap the tab's)
        # -- so this matches by bounds containment, not tree structure.
        for node in root.iter():
            ct = (node.get("text") or "").strip()
            if not ct.isdigit():
                continue
            b = _bounds(node)
            if not b:
                continue
            bx1, by1, bx2, by2 = b
            if bx1 >= tx1 - 10 and bx2 <= tx2 + 10 and by1 >= ty1 - 10 and by2 <= ty2 + 10:
                return int(ct)
        return 0
