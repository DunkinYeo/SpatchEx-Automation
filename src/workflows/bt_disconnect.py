"""
BT disconnect workflow: disable BT, wait, re-enable.
Simulates the S-Patch moving out of Bluetooth range.
"""
import logging
import subprocess
import time

from src.driver import AndroidDriver

log = logging.getLogger(__name__)


def run_bt_disconnect(driver: AndroidDriver, disconnect_minutes: float) -> None:
    """Disable Bluetooth for `disconnect_minutes`, then re-enable."""
    udid = driver.cfg.get("udid", "")
    adb = ["adb"] + (["-s", udid] if udid else [])

    driver.reporter.log_event("bt_disconnect_start", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] Disabling BT for %.1f min", disconnect_minutes)

    try:
        subprocess.run(adb + ["shell", "svc", "bluetooth", "disable"],
                       capture_output=True, timeout=10)
    except Exception as e:
        log.warning("[bt_disconnect] disable failed: %s", e)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "disable", "error": str(e)})
        return

    time.sleep(disconnect_minutes * 60)

    try:
        subprocess.run(adb + ["shell", "svc", "bluetooth", "enable"],
                       capture_output=True, timeout=10)
    except Exception as e:
        log.warning("[bt_disconnect] re-enable failed: %s", e)
        driver.reporter.log_event("bt_disconnect_failed", {"phase": "enable", "error": str(e)})
        return

    driver.reporter.log_event("bt_disconnect_done", {"minutes": disconnect_minutes})
    log.info("[bt_disconnect] BT re-enabled after %.1f min", disconnect_minutes)
