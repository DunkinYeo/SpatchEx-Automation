"""
Failure artifact collector.

Collects three pieces of evidence whenever a test fails:
  - screenshot.png   — current screen at the moment of failure
  - logcat.txt       — full ADB logcat dump
  - error.txt        — exception type, message, and traceback

Output folder: artifacts/YYYYMMDD_HHMMSS/  (at project root)

Usage:
    from automation.artifact_manager import save_failure_artifacts

    try:
        run_test()
    except Exception as e:
        save_failure_artifacts(driver, e)
        raise
"""

import datetime
import os
import subprocess
import traceback
from pathlib import Path

# Project root is one level above this file (automation/ -> root)
_ROOT = Path(__file__).resolve().parent.parent
ARTIFACTS_DIR = _ROOT / "artifacts"


def save_failure_artifacts(
    driver, exception: Exception, label: str = "runtime_failure"
) -> Path:
    """
    Collect failure evidence into a new timestamped folder.

    Args:
        driver:    Appium WebDriver instance, or an AndroidDriver wrapper
                   that exposes the underlying WebDriver as `.drv`.
        exception: The exception that caused the test to fail.
        label:     Short name embedded in the folder name for easy identification.

    Returns:
        Path to the created artifact folder.
    """
    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    out = ARTIFACTS_DIR / f"{ts}_{label}"
    out.mkdir(parents=True, exist_ok=True)

    _save_screenshot(driver, out / "screenshot.png")
    _save_logcat(driver, out / "logcat.txt")
    _save_error(exception, out / "error.txt")

    return out


# ------------------------------------------------------------------
# Internal helpers — each is best-effort and never raises
# ------------------------------------------------------------------

def _save_screenshot(driver, path: Path) -> None:
    try:
        # Support both a raw WebDriver and an AndroidDriver wrapper (.drv)
        wd = getattr(driver, "drv", driver)
        wd.save_screenshot(str(path))
    except Exception as e:
        _write_note(path, f"screenshot failed: {e}")


def _save_logcat(driver, path: Path) -> None:
    try:
        udid = _get_udid(driver)
        cmd = ["adb"]
        if udid:
            cmd += ["-s", udid]
        cmd += ["logcat", "-d"]

        # On macOS, Homebrew-installed adb may not be on the default PATH;
        # wrapping in bash -lc sources the login shell's PATH.
        if os.name != "nt":
            cmd = ["bash", "-lc", " ".join(cmd)]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
        path.write_text(result.stdout or "(no logcat output)", encoding="utf-8")
    except Exception as e:
        _write_note(path, f"logcat failed: {e}")


def _save_error(exception: Exception, path: Path) -> None:
    try:
        tb = traceback.format_exc()
        text = f"{type(exception).__name__}: {exception}\n\n{tb}"
        path.write_text(text, encoding="utf-8")
    except Exception as e:
        _write_note(path, f"error capture failed: {e}")


def _get_udid(driver) -> str:
    """Best-effort UDID extraction from session capabilities."""
    try:
        wd = getattr(driver, "drv", driver)
        caps = wd.capabilities or {}
        return caps.get("udid") or caps.get("deviceUDID") or ""
    except Exception:
        return ""


def save_failure(driver, name: str = "failure") -> str:
    """
    Lightweight screenshot-only helper.

    Saves a single PNG to artifacts/screenshots/<name>_YYYYMMDD_HHMMSS.png.
    Use this for quick mid-test snapshots. For full evidence collection
    (screenshot + logcat + error text) use save_failure_artifacts() instead.

    Returns the saved file path, or an empty string on failure.
    """
    screenshots_dir = ARTIFACTS_DIR / "screenshots"
    screenshots_dir.mkdir(parents=True, exist_ok=True)

    ts = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    path = screenshots_dir / f"{name}_{ts}.png"

    try:
        wd = getattr(driver, "drv", driver)
        wd.save_screenshot(str(path))
        print(f"[artifact] screenshot saved: {path}")
        return str(path)
    except Exception as e:
        print(f"[artifact] screenshot failed: {e}")
        return ""


def _write_note(path: Path, message: str) -> None:
    """Write a plain-text note when the primary collection step fails."""
    try:
        path.write_text(message, encoding="utf-8")
    except Exception:
        pass
