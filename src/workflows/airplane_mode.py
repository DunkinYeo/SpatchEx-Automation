"""
Airplane mode workflow: enable airplane mode, wait, disable.
Only runs when connected via USB — airplane mode cuts WiFi, which
would break a WiFi ADB session and make the device unreachable.
"""
import logging
import subprocess
import time

from src.driver import AndroidDriver

log = logging.getLogger(__name__)


def _is_usb(driver: AndroidDriver) -> bool:
    """Return True when ADB is over USB (udid has no colon, e.g. serial number)."""
    udid = driver.cfg.get("udid", "")
    return not (udid and ":" in udid and not udid.startswith("/"))


def run_airplane_mode(driver: AndroidDriver, airplane_minutes: float) -> None:
    """Enable airplane mode for `airplane_minutes`, then disable. USB-only."""
    if not _is_usb(driver):
        log.info("[airplane_mode] Skipped — WiFi ADB (USB required)")
        driver.reporter.log_event("airplane_mode_skipped", {"reason": "wifi_adb"})
        return

    udid = driver.cfg.get("udid", "")
    adb = ["adb"] + (["-s", udid] if udid else [])

    driver.reporter.log_event("airplane_mode_start", {"minutes": airplane_minutes})
    log.info("[airplane_mode] Enabling airplane mode for %.1f min", airplane_minutes)

    try:
        subprocess.run(adb + ["shell", "settings", "put", "global", "airplane_mode_on", "1"],
                       capture_output=True, timeout=10)
        subprocess.run(
            adb + ["shell", "am", "broadcast", "-a",
                   "android.intent.action.AIRPLANE_MODE", "--ez", "state", "true"],
            capture_output=True, timeout=10,
        )
    except Exception as e:
        log.warning("[airplane_mode] enable failed: %s", e)
        driver.reporter.log_event("airplane_mode_failed", {"phase": "enable", "error": str(e)})
        return

    time.sleep(airplane_minutes * 60)

    try:
        subprocess.run(adb + ["shell", "settings", "put", "global", "airplane_mode_on", "0"],
                       capture_output=True, timeout=10)
        subprocess.run(
            adb + ["shell", "am", "broadcast", "-a",
                   "android.intent.action.AIRPLANE_MODE", "--ez", "state", "false"],
            capture_output=True, timeout=10,
        )
    except Exception as e:
        log.warning("[airplane_mode] disable failed: %s", e)
        driver.reporter.log_event("airplane_mode_failed", {"phase": "disable", "error": str(e)})
        return

    driver.reporter.log_event("airplane_mode_done", {"minutes": airplane_minutes})
    log.info("[airplane_mode] Airplane mode disabled after %.1f min", airplane_minutes)
