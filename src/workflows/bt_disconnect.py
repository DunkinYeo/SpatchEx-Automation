"""
BT disconnect workflow: disable BT, wait, re-enable.
Simulates the S-Patch moving out of Bluetooth range.
"""
import logging
import subprocess

from src.driver import AndroidDriver
from src.sleep_utils import sleep_with_heartbeat

log = logging.getLogger(__name__)


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
        if driver.is_visible_text(_ALLOW_TEXT, timeout=5):
            driver.tap_text(_ALLOW_TEXT, timeout=5)
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

    sleep_with_heartbeat(driver, disconnect_minutes * 60, log_prefix="bt_disconnect")

    ok, err = _svc_bluetooth(driver, enable=True)
    if not ok:
        log.warning("[bt_disconnect] re-enable failed: %s", err)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "enable", "error": err})
        raise RuntimeError(f"bt_disconnect: re-enable failed: {err}")

    driver.reporter.log_event("bt_disconnect_done", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] BT re-enabled after %.1f min", disconnect_minutes)
