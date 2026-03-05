"""
DeviceManager — single-device wrapper, multi-device ready.

Current design: manages one AndroidDriver.
Multi-device extension path:
  - Accept config["devices"] as a list
  - Create one AndroidDriver + ArtifactManager sub-dir per device UDID
  - Yield drivers via iteration, not a single `.driver` property
  - Run jobs concurrently with threading or multiprocessing
  No global singletons are used, so callers are already compatible.
"""

from src.driver import AndroidDriver


class DeviceManager:
    """
    Wraps a single AndroidDriver.

    Designed so future multi-device implementations can replace this class
    without changing the caller interface — the driver is accessed via the
    `.driver` property, which can later become `.__iter__()`.
    """

    def __init__(
        self,
        device_cfg: dict,
        selectors: dict,
        artifacts,
        reporter,
    ):
        self._udid = device_cfg.get("udid", "device")
        self._driver = AndroidDriver(device_cfg, selectors, artifacts, reporter)

    # ------------------------------------------------------------------
    # Single-device interface
    # ------------------------------------------------------------------

    @property
    def driver(self) -> AndroidDriver:
        """Return the single managed driver."""
        return self._driver

    @property
    def udid(self) -> str:
        return self._udid

    def close(self):
        try:
            self._driver.close()
        except Exception:
            pass
