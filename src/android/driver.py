import time
from appium import webdriver
from selenium.webdriver.common.by import By
from selenium.common.exceptions import NoSuchElementException, TimeoutException, WebDriverException
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

from src.utils.retry import retry
from src.utils.artifacts import ArtifactManager
from src.orchestrator.reporting import RunReporter

class AndroidDriver:
    def __init__(self, a_cfg: dict, selectors: dict, artifacts: ArtifactManager, reporter: RunReporter):
        self.cfg = a_cfg
        self.sel = selectors
        self.artifacts = artifacts
        self.reporter = reporter
        self.drv = self._connect()

    def _connect(self):
        caps = {
            "platformName": "Android",
            "appium:automationName": "UiAutomator2",
            "appium:deviceName": self.cfg.get("device_name","Android"),
            "appium:noReset": bool(self.cfg.get("no_reset", True)),
            "appium:newCommandTimeout": int(self.cfg.get("new_command_timeout", 3600)),
        }
        if self.cfg.get("udid"):
            caps["appium:udid"] = self.cfg["udid"]
        if self.cfg.get("app_package"):
            caps["appium:appPackage"] = self.cfg["app_package"]
        if self.cfg.get("app_activity"):
            caps["appium:appActivity"] = self.cfg["app_activity"]

        self.reporter.log_event("appium_connect", {"server": self.cfg.get("appium_server_url")})
        return webdriver.Remote(self.cfg.get("appium_server_url"), caps)

    def close(self):
        try:
            self.drv.quit()
        except Exception:
            pass

    # ---------- find/click helpers ----------
    def _by_text(self, text: str):
        # robust: match exact or contains
        # UiAutomator strategy
        return (By.ANDROID_UIAUTOMATOR, f'new UiSelector().text("{text}")')

    def _by_text_contains(self, text: str):
        return (By.ANDROID_UIAUTOMATOR, f'new UiSelector().textContains("{text}")')

    def find_text(self, text: str, timeout: int = 10, contains: bool = False):
        by = self._by_text_contains(text) if contains else self._by_text(text)
        wait = WebDriverWait(self.drv, timeout)
        return wait.until(EC.presence_of_element_located(by))

    @retry(tries=3, delay=2)
    def tap_text(self, text: str, timeout: int = 10, contains: bool = True):
        el = self.find_text(text, timeout=timeout, contains=contains)
        el.click()
        return True

    def is_visible_text(self, text: str, contains: bool = True) -> bool:
        try:
            self.find_text(text, timeout=2, contains=contains)
            return True
        except Exception:
            return False

    def screenshot(self, name: str):
        self.artifacts.screenshot(self.drv, name)

    # ---------- state helpers ----------
    def bring_to_foreground(self):
        # start activity again
        pkg = self.cfg.get("app_package")
        act = self.cfg.get("app_activity")
        if pkg and act:
            try:
                self.drv.start_activity(pkg, act)
            except Exception:
                pass

    def wait_idle(self, seconds: float = 1.0):
        time.sleep(seconds)
