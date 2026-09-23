"""
BT disconnect workflow: disable BT, wait, re-enable.
Simulates the S-Patch moving out of Bluetooth range.
"""
import logging
import re
import subprocess
import xml.etree.ElementTree as ET

from src.driver import AndroidDriver
from src.sleep_utils import sleep_with_heartbeat

log = logging.getLogger(__name__)


def _dump_xml(driver: AndroidDriver) -> str | None:
    """Same fallback chain as AndroidDriver.get_tab_badge_count: raw adb
    dump first, Appium's own page_source if that fails."""
    try:
        xml = driver.dump_ui_xml_via_adb()
    except Exception:
        xml = None
    if xml:
        return xml
    try:
        return driver.drv.page_source
    except Exception:
        return None


def _find_coords_in_xml(xml_str: str, texts: list[str]) -> tuple[int, int] | None:
    """Center (cx, cy) of the first node whose text or content-desc
    contains any of `texts`. None if not found or the XML doesn't parse."""
    try:
        root = ET.fromstring(xml_str)
    except Exception:
        return None
    for node in root.iter():
        node_text = node.get("text", "")
        node_desc = node.get("content-desc", "")
        for t in texts:
            if t and (t in node_text or t in node_desc):
                m = re.match(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
                if m:
                    x1, y1, x2, y2 = (int(g) for g in m.groups())
                    return (x1 + x2) // 2, (y1 + y2) // 2
    return None


def _tap_by_text_via_adb(driver: AndroidDriver, adb: list[str], texts: list[str]) -> bool:
    """Finds an on-screen element by text and taps it with a raw
    `adb shell input tap` -- deliberately NOT Appium's own tap_text/click,
    which goes through the UiAutomator2 instrumentation's RPC endpoint.

    Confirmed live (2026-09-21) as the real fix for a second, more serious
    failure mode than the SecurityException this fallback itself exists
    for: tapping "허용" on the REQUEST_ENABLE/DISABLE system dialog via
    Appium crashed the UiAutomator2 instrumentation process itself
    ("cannot be proxied to UiAutomator2 server because the instrumentation
    process is not running (probably crashed)") -- every later step in the
    same run then failed too, since the whole Appium session was left
    unusable. The instrumentation is bound to the driver's own target app
    context; interacting with a totally different foreground app (system
    Settings, in this case) through it is exactly the kind of context
    mismatch that appears to trigger this. `adb shell input tap` is a
    plain OS-level input event injection -- it has no concept of
    "instrumentation" or "target app" at all, so it can't destabilize it.
    The coordinates are still found dynamically from a fresh XML dump each
    time (not hardcoded), so this stays just as device/resolution-agnostic
    as the Appium-based version was -- only *how* the tap is delivered
    changed, not how the target is located."""
    xml = _dump_xml(driver)
    if not xml:
        return False
    coords = _find_coords_in_xml(xml, texts)
    if not coords:
        return False
    subprocess.run(adb + ["shell", "input", "tap", str(coords[0]), str(coords[1])],
                    capture_output=True, timeout=10)
    return True


def _bt_is_on(adb: list[str]) -> bool | None:
    """Ground-truth Bluetooth radio state, read straight from Settings --
    `svc bluetooth` can fail silently (see this module's own comment below)
    so a caller cannot trust its own success just because the command
    returned. Returns None if the state itself couldn't be read (treat as
    unknown, not as a specific on/off answer)."""
    try:
        r = subprocess.run(adb + ["shell", "settings", "get", "global", "bluetooth_on"],
                            capture_output=True, timeout=10, text=True)
        val = (r.stdout or "").strip()
        return val == "1" if val in ("0", "1") else None
    except Exception:
        return None


_REQUEST_ACTION = {
    True: "android.bluetooth.adapter.action.REQUEST_ENABLE",
    False: "android.bluetooth.adapter.action.REQUEST_DISABLE",
}
_ALLOW_TEXT = ["허용", "Allow"]


def _svc_bluetooth(driver: AndroidDriver, enable: bool) -> tuple[bool, str]:
    """Toggles Bluetooth and verifies the radio actually changed state, not
    just that a command exited -- tries the fast plain-`svc` path first,
    then falls back to the standard Android consent-dialog flow if that
    didn't really work.

    Confirmed live (2026-09-21, Galaxy A32 / Android 11 / One UI) as a real,
    silent failure mode: `svc bluetooth disable` can throw a
    SecurityException ("Need BLUETOOTH_ADMIN permission: Neither user 2000
    nor current process has android.permission.BLUETOOTH_ADMIN") on this
    device/OS combo -- the adb shell command process gets killed
    (returncode 137) but `subprocess.run()` doesn't raise on a nonzero
    returncode, so the old code always logged bt_disconnect_done
    unconditionally. A tester watching the actual phone screen confirmed
    Bluetooth never visibly turned off despite the automation reporting
    success on every one of these runs -- this device's shell simply isn't
    granted BLUETOOTH_ADMIN, a permission the same command has on other
    test devices (e.g. the Pixel 7) without issue.

    Rather than hardcode a per-device branch (tester-unfriendly -- every
    tester only ever watches the web dashboard, never the phone itself, so
    this has to resolve on its own with no human tap), the fallback uses
    `BluetoothAdapter.ACTION_REQUEST_ENABLE/DISABLE` -- the same public,
    non-permission-gated intent a normal app uses to ask the user for
    Bluetooth, which brings up a standard system consent dialog ("앱에서
    블루투스 끄기를 요청합니다" / "허용"·"거부") regardless of OEM skin or
    Android version. Finding the Allow button by bilingual TEXT (not
    hardcoded pixel coordinates -- confirmed live that guessing coordinates
    from a screenshot was off by ~750px here) makes this resolve the same
    way on any device/language automatically. Falls back to the fast path
    first since it's a single adb call with no UI disruption on devices
    where it already works (e.g. the Pixel 7); the dialog flow briefly
    leaves the target app (handled by the caller re-foregrounding it)."""
    udid = driver.cfg.get("udid", "")
    adb = ["adb"] + (["-s", udid] if udid else [])
    action = "enable" if enable else "disable"

    result = subprocess.run(adb + ["shell", "svc", "bluetooth", action],
                             capture_output=True, timeout=10, text=True)
    if result.returncode == 0 and _bt_is_on(adb) == enable:
        return True, ""

    log.info("[bt_disconnect] svc bluetooth %s didn't take -- falling back to consent-dialog flow", action)
    subprocess.run(adb + ["shell", "am", "start", "-a", _REQUEST_ACTION[enable]],
                    capture_output=True, timeout=10)
    driver.wait_idle(1.5)
    tap_error = None
    try:
        _tap_by_text_via_adb(driver, adb, _ALLOW_TEXT)
    except Exception as e:
        tap_error = e
    driver.wait_idle(1.0)

    state = _bt_is_on(adb)
    # The REQUEST_ENABLE/DISABLE intent always opens the system Settings
    # app on top of whatever was running (confirmed live -- it does not
    # stay within the target app's own context), so the scenario is left
    # on the Bluetooth settings screen, not the app under test, regardless
    # of whether the toggle itself succeeded. Restoring foreground here --
    # not left to the caller -- means every _svc_bluetooth caller gets this
    # for free and a tester watching only the web dashboard never sees the
    # run stuck looking like it's doing nothing on a screen they can't see.
    driver.bring_to_foreground()

    if tap_error is not None:
        return False, f"svc bluetooth {action} failed and the consent-dialog fallback also failed: {tap_error}"
    if state is None:
        return False, f"svc bluetooth {action} and the consent-dialog fallback both ran, but bluetooth_on state could not be read afterward"
    if state != enable:
        return False, f"svc bluetooth {action} and the consent-dialog fallback both ran, but bluetooth_on is still {'on' if state else 'off'} afterward"
    return True, ""


def _verify_disconnected_ui(driver: AndroidDriver) -> None:
    """After the disable half of _svc_bluetooth reports success, confirms
    the app itself actually shows a disconnected state -- symmetric to
    _ensure_reconnected's own "did it actually reconnect" check on the
    re-enable side, and for the same reason: `_bt_is_on` only reads the OS
    radio setting, which says nothing about whether the app's own BLE/GATT
    session to the patch actually dropped.

    Ported from EX-Medi-UAT-Automation's actions.py, where this exact gap
    was found and fixed first: every caller of run_bt_disconnect
    (bluetooth_disconnect_cycle, e.g. EX Test 19's "15분씩 끊었다 재연결 3번
    반복") went straight from a successful disable into the long
    sleep_with_heartbeat wait with no check that the app itself had
    actually noticed -- an OS-level "radio is off" success could still
    leave the run sitting through the entire wait never having shown a
    genuinely disconnected app screen, with nothing downstream to catch it.

    Polls (not a single check) since the app may take a moment to notice
    the radio went away -- same generous budget as _ensure_reconnected's
    own loop, not a tight single timeout."""
    driver.bring_to_foreground()
    disconnect = driver.sel.get("device_disconnect_text", ["연결 끊김", "Disconnected", "Connection Lost"])
    bt_off_popup = driver.sel.get(
        "bluetooth_disabled_popup_text",
        ["블루투스 기능 꺼져 있음", "Bluetooth is turned off", "Bluetooth Disabled"],
    )
    for attempt in range(6):
        if driver.is_visible_text(disconnect, timeout=3) or driver.is_visible_text(bt_off_popup, timeout=3):
            driver.reporter.log_event("bt_disconnect_confirmed_in_app", {"attempt": attempt + 1})
            return
        driver.wait_idle(2.0)
    driver.reporter.log_event("bt_disconnect_not_confirmed_in_app", {})
    raise RuntimeError(
        "bt_disconnect: OS radio reports off, but the app never showed a "
        "disconnected state (no '연결 끊김' banner or 'Bluetooth is turned "
        "off' popup appeared)"
    )


def run_bt_disconnect(driver: AndroidDriver, disconnect_minutes: float) -> None:
    """Disable Bluetooth for `disconnect_minutes`, then re-enable. Raises
    RuntimeError (does NOT silently return) if either toggle didn't
    actually take effect -- see _svc_bluetooth's own docstring for why a
    caller can't trust a clean subprocess exit alone here."""
    driver.reporter.log_event("bt_disconnect_start", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] Disabling BT for %.1f min", disconnect_minutes)

    ok, err = _svc_bluetooth(driver, enable=False)
    if not ok:
        log.warning("[bt_disconnect] disable failed: %s", err)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "disable", "error": err})
        raise RuntimeError(f"bt_disconnect: disable failed: {err}")

    _verify_disconnected_ui(driver)

    sleep_with_heartbeat(driver, disconnect_minutes * 60, log_prefix="bt_disconnect")

    ok, err = _svc_bluetooth(driver, enable=True)
    if not ok:
        log.warning("[bt_disconnect] re-enable failed: %s", err)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "enable", "error": err})
        raise RuntimeError(f"bt_disconnect: re-enable failed: {err}")

    _ensure_reconnected(driver)

    driver.reporter.log_event("bt_disconnect_done", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] BT re-enabled after %.1f min", disconnect_minutes)


def _ensure_reconnected(driver: AndroidDriver) -> None:
    """Turning the radio back on is necessary but not sufficient: the EX
    app does NOT auto-reconnect to the patch on its own while already
    foregrounded -- it keeps showing a "연결 끊김"/"Disconnected" banner
    with a "재연결"/"Reconnect" button that must be tapped before the main
    screen is usable again (same selector keys and default text
    symptom_inject.py's own disconnect-popup handling already uses, for
    consistency).

    Confirmed live (2026-09-21) as a real gap: every current caller of
    run_bt_disconnect (bluetooth_disconnect_cycle, used by EX Test 19's
    "15분씩 끊었다 재연결 3번 반복" step among others) goes straight from
    this call into a long `wait` with no verify_app_alive/verify_connected
    step in between -- without this, the app would sit on the Reconnect
    banner for that entire remaining wait (17h15m for Test 19), never
    actually reconnected, and nothing downstream would catch it until the
    scenario's own final verify step at the very end, if it has one at
    all."""
    udid = driver.cfg.get("udid", "")
    adb = ["adb"] + (["-s", udid] if udid else [])
    disconnect = driver.sel.get("device_disconnect_text", ["연결 끊김", "Disconnected", "Connection Lost"])
    reconnect = driver.sel.get("device_reconnect_text", ["재연결", "Reconnect", "다시 연결"])
    bt_off_popup = driver.sel.get(
        "bluetooth_disabled_popup_text",
        ["블루투스 기능 꺼져 있음", "Bluetooth is turned off", "Bluetooth Disabled"],
    )
    confirm = driver.sel.get("confirm_text", ["확인", "Confirm", "OK"])
    main_screen = driver.sel.get("symptom_add_text", "Add Symptom")
    # Gate on EITHER the banner's own title OR the app-level "블루투스
    # 기능 꺼져 있음" popup -- confirmed live (2026-09-21) via a saved
    # debug screenshot that these two can appear INDEPENDENTLY of each
    # other (one cycle showed only the popup, no "연결 끊김" banner behind
    # it at all), so gating on the banner alone missed that case entirely
    # and silently returned without ever dismissing the popup.
    if not driver.is_visible_text(disconnect, timeout=4) and not driver.is_visible_text(bt_off_popup, timeout=4):
        return
    driver.reporter.log_event("bt_disconnect_reconnect_banner_detected", {})
    for attempt in range(10):
        if driver.is_visible_text(main_screen, timeout=2) and not driver.is_visible_text(bt_off_popup, timeout=2):
            driver.reporter.log_event("bt_disconnect_reconnected", {"attempt": attempt})
            return
        # The app's own "S-Patch 기기 검색을 위해 휴대폰의 블루투스 기능을
        # 켜주세요" popup can render directly ON TOP of the Reconnect
        # banner's own button -- confirmed live (2026-09-21) via a raw XML
        # dump that both occupy the *exact same* screen bounds
        # ([467,2092][611,2171] vs [491,2093][587,2172]). Blindly tapping
        # "재연결" coordinates while this popup is showing actually taps
        # its own "확인" button instead (topmost view wins), which just
        # dismisses the popup without ever triggering a real reconnect --
        # this, not a tap failure, was the actual reason a tester watching
        # the phone kept seeing "reconnect_tap" logged with nothing
        # visibly happening. Must be closed first; only then is the real
        # Reconnect button underneath actually reachable.
        if driver.is_visible_text(bt_off_popup, timeout=2):
            if _tap_by_text_via_adb(driver, adb, confirm):
                driver.reporter.log_event("bt_disconnect_popup_dismissed", {"attempt": attempt + 1})
            driver.wait_idle(2.0)
            continue
        # Raw adb tap, not Appium's tap_text -- see _tap_by_text_via_adb's
        # own docstring for why (the same UiAutomator2-instrumentation-
        # crash risk applies to any tap right after a system-level BT
        # state change, not just the consent dialog's own Allow button).
        if _tap_by_text_via_adb(driver, adb, reconnect):
            driver.reporter.log_event("bt_disconnect_reconnect_tapped", {"attempt": attempt + 1})
        driver.wait_idle(3.0)
    driver.reporter.log_event("bt_disconnect_reconnect_timeout", {})
    raise RuntimeError("bt_disconnect: BT radio re-enabled but the app never left the Disconnected/Reconnect screen")
