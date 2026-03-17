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
        if self.cfg.get("udid"):
            opts.udid = self.cfg["udid"]
        if self.cfg.get("app_package"):
            opts.app_package = self.cfg["app_package"]
        if self.cfg.get("app_activity"):
            opts.app_activity = self.cfg["app_activity"]
        return opts

    def _connect(self) -> webdriver.Remote:
        server = self.cfg.get("appium_server_url", "http://127.0.0.1:4723")
        self.reporter.log_event("appium_connect", {"server": server})
        return webdriver.Remote(server, options=self._build_options())

    def reconnect(self):
        """
        Re-establish Appium session after a crash or timeout.
        After reconnecting, brings the app to foreground so the recovered
        session lands on the right screen. The scheduler's health checks
        (ensure_measurement_started) will verify UI state.
        """
        logging.warning("[SESSION] recreating driver")
        self.reporter.log_event("session_recreating", {})
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
        """Check session health; reconnect if dead."""
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
                # Step 2: Force start the activity (may recreate)
                self.reporter.log_event("recovery_step_2", {"action": "start_activity"})
                if pkg and act:
                    self.drv.start_activity(pkg, act)
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
            return False

    def wait_for_symptom_success(self, timeout: int = 10) -> str:
        """
        Wait for one of two success signals after symptom submission:
          1. symptom_success_signal_text  — configured toast/confirmation text
          2. symptom_add_text             — back on main measurement screen

        Returns the name of the signal that was detected first.
        Raises RuntimeError if neither appears within timeout.
        """
        success_signal = self.sel.get("symptom_success_signal_text")
        main_indicator = self.sel.get("symptom_add_text", "Add Symptom")

        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if success_signal and self.is_visible_text(success_signal):
                return "success_signal"
            if self.is_visible_text(main_indicator):
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
