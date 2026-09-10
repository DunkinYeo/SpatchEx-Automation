"""Shared long-wait helper for workflows that disable something on the
device and need to sleep through a multi-hour/day window before re-enabling
it (bt_disconnect.py, airplane_mode.py).
"""
import logging
import time

log = logging.getLogger(__name__)

_HEARTBEAT_SECONDS = 300  # 5 min


def sleep_with_heartbeat(driver, total_seconds: float, log_prefix: str = "sleep") -> None:
    """Sleep in chunks, checking the Appium session between them, instead of
    one blind time.sleep() for the whole duration. For a real multi-hour
    disconnect window this matters two ways: a host sleep/wake, app crash,
    or backgrounding during the wait previously went unnoticed until
    whatever ran next (possibly hours later), and with no command reaching
    Appium for that long, the session's own new_command_timeout could kill
    it from pure inactivity before the disconnect period was even over.
    ensure_session() serves as both the check and the fix (it reconnects a
    dead session itself). Never lets a failed check shorten the wait."""
    remaining = total_seconds
    while remaining > 0:
        chunk = min(remaining, _HEARTBEAT_SECONDS)
        time.sleep(chunk)
        remaining -= chunk
        if remaining <= 0:
            continue
        try:
            driver.ensure_session()
        except Exception as e:
            log.warning("[%s] heartbeat check failed: %s", log_prefix, e)
            driver.reporter.log_event(f"{log_prefix}_heartbeat_failed", {"error": str(e)})
