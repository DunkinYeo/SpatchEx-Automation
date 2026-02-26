import os
import datetime
import subprocess

class ArtifactManager:
    def __init__(self, out_dir: str):
        self.out_dir = out_dir
        self.ss_dir = os.path.join(out_dir, "screenshots")
        self.log_dir = os.path.join(out_dir, "logs")
        os.makedirs(self.ss_dir, exist_ok=True)
        os.makedirs(self.log_dir, exist_ok=True)

    def _ts(self):
        return datetime.datetime.now().strftime("%Y%m%d_%H%M%S")

    def screenshot(self, driver, name: str):
        path = os.path.join(self.ss_dir, f"{self._ts()}_{name}.png")
        try:
            driver.get_screenshot_as_file(path)
        except Exception:
            pass
        return path

    def collect_android_logcat(self, name: str = "logcat", seconds: int = 2):
        # best-effort short capture
        path = os.path.join(self.log_dir, f"{self._ts()}_{name}.txt")
        try:
            out = subprocess.check_output(["bash","-lc", f"adb logcat -d -t {seconds}"], stderr=subprocess.STDOUT).decode("utf-8", errors="ignore")
            with open(path, "w", encoding="utf-8") as f:
                f.write(out)
        except Exception:
            pass
        return path
