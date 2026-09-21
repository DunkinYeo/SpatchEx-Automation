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


def _svc_bluetooth(adb: list[str], enable: bool) -> tuple[bool, str]:
    """Runs `svc bluetooth enable|disable` and verifies the radio actually
    changed state, not just that the command exited.

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
    test devices (e.g. the Pixel 7) without issue. Checking the exit code
    alone isn't enough either (a stale/async settings read could still lag
    behind a genuinely-successful toggle), so this also re-reads the actual
    setting afterward and only calls it success if the state matches what
    was requested."""
    action = "enable" if enable else "disable"
    result = subprocess.run(adb + ["shell", "svc", "bluetooth", action],
                             capture_output=True, timeout=10, text=True)
    if result.returncode != 0:
        return False, f"svc bluetooth {action} exited {result.returncode}: {(result.stderr or result.stdout or '').strip()[:200]}"
    state = _bt_is_on(adb)
    if state is None:
        return False, "svc bluetooth {} exited 0 but bluetooth_on state could not be read afterward".format(action)
    if state != enable:
        return False, f"svc bluetooth {action} exited 0 but bluetooth_on is still {'on' if state else 'off'} afterward -- likely a permission/OEM restriction on this device, not a real toggle"
    return True, ""


def run_bt_disconnect(driver: AndroidDriver, disconnect_minutes: float) -> None:
    """Disable Bluetooth for `disconnect_minutes`, then re-enable. Raises
    RuntimeError (does NOT silently return) if either toggle didn't
    actually take effect -- see _svc_bluetooth's own docstring for why a
    caller can't trust a clean subprocess exit alone here."""
    udid = driver.cfg.get("udid", "")
    adb = ["adb"] + (["-s", udid] if udid else [])

    driver.reporter.log_event("bt_disconnect_start", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] Disabling BT for %.1f min", disconnect_minutes)

    ok, err = _svc_bluetooth(adb, enable=False)
    if not ok:
        log.warning("[bt_disconnect] disable failed: %s", err)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "disable", "error": err})
        raise RuntimeError(f"bt_disconnect: disable failed: {err}")

    sleep_with_heartbeat(driver, disconnect_minutes * 60, log_prefix="bt_disconnect")

    ok, err = _svc_bluetooth(adb, enable=True)
    if not ok:
        log.warning("[bt_disconnect] re-enable failed: %s", err)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "enable", "error": err})
        raise RuntimeError(f"bt_disconnect: re-enable failed: {err}")

    driver.reporter.log_event("bt_disconnect_done", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] BT re-enabled after %.1f min", disconnect_minutes)
