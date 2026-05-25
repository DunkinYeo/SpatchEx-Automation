"""
Cross-platform sleep prevention.

macOS : launches `caffeinate -i -s` in a watchdog thread — restarts if it dies.
Windows: calls SetThreadExecutionState in a background thread every 30s.
Other  : no-op.

Usage:
    guard = KeepAwake()
    guard.start()
    ...
    guard.stop()   # or just let it die with the process
"""
import logging
import platform
import subprocess
import threading

log = logging.getLogger(__name__)

_ES_CONTINUOUS        = 0x80000000
_ES_SYSTEM_REQUIRED   = 0x00000001


class KeepAwake:
    def __init__(self):
        self._proc   = None
        self._stop   = threading.Event()
        self._thread = None

    def start(self):
        system = platform.system()
        if system == "Darwin":
            self._start_macos()
        elif system == "Windows":
            self._start_windows()
        else:
            log.info("[keep_awake] platform '%s' — no sleep prevention applied", system)

    def _start_macos(self):
        def _watch():
            while not self._stop.is_set():
                # (Re)start caffeinate if it's not running
                if self._proc is None or self._proc.poll() is not None:
                    try:
                        self._proc = subprocess.Popen(
                            ["caffeinate", "-d", "-i", "-m", "-s"],
                            stdout=subprocess.DEVNULL,
                            stderr=subprocess.DEVNULL,
                        )
                        log.info("[keep_awake] caffeinate (re)started pid=%d", self._proc.pid)
                    except FileNotFoundError:
                        log.warning("[keep_awake] caffeinate not found — sleep prevention disabled")
                        return
                    except Exception as e:
                        log.warning("[keep_awake] caffeinate failed: %s", e)
                self._stop.wait(60)

        self._thread = threading.Thread(target=_watch, daemon=True, name="keep-awake-mac")
        self._thread.start()

    def _start_windows(self):
        try:
            import ctypes
            kernel32 = ctypes.windll.kernel32  # type: ignore[attr-defined]
        except Exception as e:
            log.warning("[keep_awake] Windows ctypes unavailable: %s", e)
            return

        def _keep():
            flags = _ES_CONTINUOUS | _ES_SYSTEM_REQUIRED
            kernel32.SetThreadExecutionState(flags)
            log.info("[keep_awake] Windows SetThreadExecutionState active")
            while not self._stop.wait(30):
                kernel32.SetThreadExecutionState(flags)
            kernel32.SetThreadExecutionState(_ES_CONTINUOUS)
            log.info("[keep_awake] Windows sleep prevention released")

        self._thread = threading.Thread(target=_keep, daemon=True, name="keep-awake-win")
        self._thread.start()

    def stop(self):
        self._stop.set()
        if self._proc and self._proc.poll() is None:
            self._proc.terminate()
            log.info("[keep_awake] caffeinate terminated")
