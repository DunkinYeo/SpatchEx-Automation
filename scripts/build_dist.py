"""
Build distribution ZIPs for Windows and Mac testers.

Creates two ZIPs:
  SpatchEx-UAT-Windows-YYYYMMDD.zip
  SpatchEx-UAT-Mac-YYYYMMDD.zip

Root structure in each ZIP:
  Windows: install.bat / run.bat / STOP.bat + README KR/EN + automation/
  Mac:     install.command / run.command / STOP.command + README KR/EN + automation/

Launcher scripts are patched on-the-fly so internal file references
(web/app.py, requirements.txt, runtime/) point to automation/ in the ZIP.
The actual repo files are NOT modified.

Usage:
  python scripts/build_dist.py
  python scripts/build_dist.py --out ~/Desktop
"""

import argparse
import datetime
import os
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TODAY = datetime.date.today().strftime("%Y%m%d")

# ── Path substitutions for launcher scripts ────────────────────────────────
# Applied to run.bat, install.bat, run.command, scripts/setup_env.sh
WIN_SUBS = [
    # web/app.py references
    ('"web\\app.py"',               '"automation\\web\\app.py"'),
    ('web\\app.py\n',               'automation\\web\\app.py\n'),
    ('web\\app.py\r\n',             'automation\\web\\app.py\r\n'),
    # requirements.txt
    ('-r requirements.txt',          '-r automation\\requirements.txt'),
    # runtime paths (adb, node, appium)
    ('"runtime\\platform-tools\\',  '"automation\\runtime\\platform-tools\\'),
    ('"runtime\\android-sdk\\',     '"automation\\runtime\\android-sdk\\'),
    ('"runtime\\node\\',            '"automation\\runtime\\node\\'),
    ('"runtime\\appium\\',          '"automation\\runtime\\appium\\'),
    ('%CD%\\runtime"',              '%CD%\\automation\\runtime"'),
    ('%CD%\\runtime\\',             '%CD%\\automation\\runtime\\'),
    ("DestinationPath 'runtime'",   "DestinationPath 'automation\\runtime'"),
    # WiFi cache file path (single-quoted in PowerShell strings, double-quoted in IF EXIST)
    ("'runtime\\adb_wifi_device.json'",  "'automation\\runtime\\adb_wifi_device.json'"),
    ('"runtime\\adb_wifi_device.json"',  '"automation\\runtime\\adb_wifi_device.json"'),
    # IF NOT EXIST guards -- must come before mkdir substitutions
    ('IF NOT EXIST "logs"',         'IF NOT EXIST "automation\\logs"'),
    # mkdir runtime / logs
    ('"runtime" mkdir runtime',     '"automation\\runtime" mkdir automation\\runtime'),
    ('mkdir runtime\n',             'mkdir automation\\runtime\n'),
    ('mkdir runtime\r\n',           'mkdir automation\\runtime\r\n'),
    ('mkdir logs\n',                'mkdir automation\\logs\n'),
    ('mkdir logs\r\n',              'mkdir automation\\logs\r\n'),
    ('logs"    mkdir logs',         'automation\\logs"    mkdir automation\\logs'),
    ('logs" mkdir runtime',         'automation\\logs" mkdir automation\\runtime'),
]

MAC_SUBS = [
    # web/app.py references
    ('"web/app.py"',                '"automation/web/app.py"'),
    ('$PYTHON web/app.py',          '$PYTHON automation/web/app.py'),
    ('python web/app.py',           'python automation/web/app.py'),
    # requirements.txt (pip install + file-existence check)
    ('-r requirements.txt',          '-r automation/requirements.txt'),
    ('-f "requirements.txt"',        '-f "automation/requirements.txt"'),
    # install.command: setup_env.sh path
    ('chmod +x scripts/setup_env.sh', 'chmod +x automation/scripts/setup_env.sh'),
    ('bash scripts/setup_env.sh',   'bash automation/scripts/setup_env.sh'),
    # setup_env.sh: cd goes up one extra level in the packaged layout.
    # Dev:  scripts/../        = project root (no patch)
    # Pkg:  automation/scripts/../../ = ZIP root  (patched here)
    # This MUST be matched before any shorter cd patterns.
    ('cd "$(dirname "$0")/.."',     'cd "$(dirname "$0")/../.."'),
    # runtime paths (with trailing slash)
    ('"runtime/android-sdk/',       '"automation/runtime/android-sdk/'),
    ('"runtime/platform-tools/',    '"automation/runtime/platform-tools/'),
    ('"$PWD/runtime/',              '"$PWD/automation/runtime/'),
    # runtime path (no trailing slash -- e.g. ANDROID_HOME="$PWD/runtime")
    ('"$PWD/runtime"',              '"$PWD/automation/runtime"'),
    # mkdir
    ('mkdir -p logs runtime',       'mkdir -p automation/logs automation/runtime'),
    ('mkdir -p runtime',            'mkdir -p automation/runtime'),
    # WiFi cache file path (single-quoted in shell strings, double-quoted in if checks)
    ("'runtime/adb_wifi_device.json'",  "'automation/runtime/adb_wifi_device.json'"),
    ('"runtime/adb_wifi_device.json"',  '"automation/runtime/adb_wifi_device.json"'),
]


def _patch(text: str, subs: list) -> str:
    for old, new in subs:
        text = text.replace(old, new)
    return text


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def _add(zf: zipfile.ZipFile, src: Path, arc: str, subs: list = None):
    """Add a file to the ZIP, optionally applying text substitutions."""
    if not src.exists():
        return
    if subs:
        content = _patch(_read(src), subs)
        zf.writestr(arc, content)
    else:
        zf.write(src, arc)


def _add_dir(zf: zipfile.ZipFile, src_dir: Path, arc_prefix: str, subs: list = None):
    """Recursively add a directory. Python/shell files get path-patched if subs given."""
    SKIP = {"__pycache__", ".pyc", ".DS_Store", ".git", ".pytest_cache"}
    TEXT_EXT = {".py", ".bat", ".sh", ".command", ".txt", ".yaml", ".yml",
                ".html", ".json", ".md", ".cfg", ".ini", ".ps1", ".cmd"}
    for f in src_dir.rglob("*"):
        if f.is_file() and not any(s in str(f) for s in SKIP):
            arc = arc_prefix + "/" + f.relative_to(src_dir).as_posix()
            if subs and f.suffix.lower() in TEXT_EXT:
                content = _patch(_read(f), subs)
                zf.writestr(arc, content)
            else:
                zf.write(f, arc)


EXCLUDE_CONFIG = {"_web_run.yaml", "_web_run.example.yaml"}
TEST_CONFIG_PREFIXES = ("test_",)


def _add_config(zf: zipfile.ZipFile, arc_prefix: str):
    config_dir = ROOT / "config"
    for f in sorted(config_dir.iterdir()):
        if f.is_file():
            if f.name in EXCLUDE_CONFIG:
                continue
            if any(f.name.startswith(p) for p in TEST_CONFIG_PREFIXES):
                continue
            zf.write(f, f"{arc_prefix}/{f.name}")


def build_windows(out_dir: Path):
    name = f"SpatchEx-UAT-Windows-{TODAY}.zip"
    path = out_dir / name
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
        # ── Root launcher scripts (path-patched) ─────────────────────
        _add(zf, ROOT / "install.bat",          "install.bat",  WIN_SUBS)
        _add(zf, ROOT / "run.bat",              "run.bat",      WIN_SUBS)
        _add(zf, ROOT / "STOP.bat",             "STOP.bat")

        # ── READMEs at root ──────────────────────────────────────────
        for fname in [
            "README_WINDOWS_KR.txt", "README_WINDOWS_EN.txt",
            "README_TEAM_DASHBOARD_KR.txt", "README_TEAM_DASHBOARD_EN.txt",
        ]:
            _add(zf, ROOT / fname, fname)

        # ── automation/ internals ────────────────────────────────────
        P = "automation"
        _add(zf, ROOT / "unblock_and_run.ps1",  f"{P}/tools/unblock_and_run.ps1")
        _add(zf, ROOT / "requirements.txt",    f"{P}/requirements.txt")
        _add(zf, ROOT / "selftest.bat",         f"{P}/selftest.bat", WIN_SUBS)

        _add_dir(zf, ROOT / "src",        f"{P}/src")
        _add_dir(zf, ROOT / "web",        f"{P}/web")
        _add_dir(zf, ROOT / "automation", f"{P}/automation")
        _add_dir(zf, ROOT / "scripts",    f"{P}/scripts", MAC_SUBS)

        _add_config(zf, f"{P}/config")

    print(f"Windows ZIP: {path}  ({path.stat().st_size // 1024} KB)")
    return path


def build_mac(out_dir: Path):
    name = f"SpatchEx-UAT-Mac-{TODAY}.zip"
    path = out_dir / name
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zf:
        # ── Root launcher scripts (path-patched) ─────────────────────
        _add(zf, ROOT / "install.command",  "install.command",  MAC_SUBS)
        _add(zf, ROOT / "run.command",      "run.command",      MAC_SUBS)
        _add(zf, ROOT / "STOP.command",     "STOP.command")

        # ── READMEs at root ──────────────────────────────────────────
        for fname in [
            "README_MAC_KR.txt", "README_MAC_EN.txt",
            "README_TEAM_DASHBOARD_KR.txt", "README_TEAM_DASHBOARD_EN.txt",
        ]:
            _add(zf, ROOT / fname, fname)

        # ── automation/ internals ────────────────────────────────────
        P = "automation"
        _add(zf, ROOT / "requirements.txt", f"{P}/requirements.txt")

        _add_dir(zf, ROOT / "src",        f"{P}/src")
        _add_dir(zf, ROOT / "web",        f"{P}/web")
        _add_dir(zf, ROOT / "automation", f"{P}/automation")
        _add_dir(zf, ROOT / "scripts",    f"{P}/scripts", MAC_SUBS)

        _add_config(zf, f"{P}/config")

    print(f"Mac ZIP:     {path}  ({path.stat().st_size // 1024} KB)")
    return path


def main():
    ap = argparse.ArgumentParser(description="Build SpatchEx distribution ZIPs")
    ap.add_argument("--out", default=str(Path.home() / "Desktop"),
                    help="Output directory (default: ~/Desktop)")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    print(f"Building distribution ZIPs → {out}\n")
    build_windows(out)
    build_mac(out)
    print("\nDone.")


if __name__ == "__main__":
    main()
