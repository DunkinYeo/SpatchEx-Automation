"""
SpatchEx Long-run Test — Web UI backend
Run:  python web/app.py   (from project root)
"""
import json
import subprocess
import sys
import threading
import time
from pathlib import Path

import yaml
from flask import Flask, jsonify, render_template, request

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

app = Flask(__name__)

# ── Shared state (single-user local tool) ────────────────────────────────────
_state: dict = {"proc": None, "out_dir": None, "start_ts": None}
_lock = threading.Lock()

# ── Selectors embedded for spatch-ex (bilingual) ─────────────────────────────
SPATCH_EX_SELECTORS = {
    "start_now_text": "Start Now",
    "consent_agree_text": ["동의", "Agree"],
    "use_spatch_text": ["S-Patch 사용하기", "Use S-Patch"],
    "duration_sheet_title": ["검사 기간을 선택해주세요", "Select a test period"],
    "duration_24h_text": ["24 시간", "24 Hours"],
    "duration_48h_text": ["48 시간", "48 Hours"],
    "duration_72h_text": ["72 시간", "72 Hours"],
    "confirm_text": ["확인", "Confirm", "OK"],
    "offline_mode_text": ["오프라인", "Offline"],
    "symptom_add_text": ["증상 추가", "Add Symptom"],
    "symptom_picker_title": ["증상을 선택해주세요.", "Check your symptoms"],
    # symptom_confirm_text / symptom_done_text intentionally omitted
    # → English app auto-closes picker; Korean app handled via optional check
}


# ── Helpers ───────────────────────────────────────────────────────────────────

def get_devices() -> list[str]:
    try:
        r = subprocess.run(["adb", "devices"], capture_output=True, text=True, timeout=5)
        return [
            line.split("\t")[0].strip()
            for line in r.stdout.splitlines()[1:]
            if "\t" in line and line.split("\t")[1].strip() == "device"
        ]
    except Exception:
        return []


def appium_ok() -> bool:
    try:
        import urllib.request
        with urllib.request.urlopen("http://127.0.0.1:4723/status", timeout=2) as r:
            return json.loads(r.read()).get("value", {}).get("ready", False)
    except Exception:
        return False


def read_events(out_dir: str | None) -> list[dict]:
    if not out_dir:
        return []
    p = Path(out_dir) / "events.jsonl"
    if not p.exists():
        return []
    events = []
    for line in p.read_text(encoding="utf-8").splitlines():
        if line.strip():
            try:
                events.append(json.loads(line))
            except Exception:
                pass
    return events


def find_latest_output_dir(since: float) -> str | None:
    """Find the most recent output dir created at/after `since` timestamp."""
    out = ROOT / "output"
    if not out.exists():
        return None
    dirs = [d for d in out.iterdir() if d.is_dir() and d.stat().st_mtime >= since - 1]
    dirs.sort(key=lambda d: d.stat().st_mtime, reverse=True)
    return str(dirs[0]) if dirs else None


# ── Routes ────────────────────────────────────────────────────────────────────

@app.route("/")
def index():
    return render_template("index.html")


@app.route("/api/init")
def api_init():
    """Called on page load — returns devices + appium status."""
    return jsonify({"devices": get_devices(), "appium": appium_ok()})


@app.route("/api/appium/start", methods=["POST"])
def api_appium_start():
    """Try to start the Appium server."""
    try:
        subprocess.Popen(
            ["appium", "--port", "4723"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(2.5)
        return jsonify({"ok": True, "running": appium_ok()})
    except FileNotFoundError:
        return jsonify({"error": "appium 명령을 찾을 수 없습니다. Appium이 설치되어 있는지 확인하세요."}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/api/status")
def api_status():
    with _lock:
        proc = _state["proc"]
        out_dir = _state["out_dir"]
        start_ts = _state["start_ts"]
        running = bool(proc and proc.poll() is None)

        # Lazy output-dir detection
        if not out_dir and start_ts:
            found = find_latest_output_dir(start_ts)
            if found:
                _state["out_dir"] = found
                out_dir = found

        events = read_events(out_dir)
        exit_code = proc.poll() if proc else None

        return jsonify({
            "running": running,
            "exit_code": exit_code,
            "events": events[-50:],
        })


@app.route("/api/start", methods=["POST"])
def api_start():
    with _lock:
        if _state["proc"] and _state["proc"].poll() is None:
            return jsonify({"error": "이미 실행 중입니다."}), 400

        data = request.json or {}
        device = data.get("device", "")
        symptoms = data.get("symptoms") or ["Chest Pain", "Palpitations", "Dizziness", "Short Breath"]

        cfg = {
            "platform": "android",
            "run": {
                "name": data.get("run_name") or "uat_run",
                "duration_hours": int(data.get("duration_hours", 24)),
                "symptom_interval_hours": float(data.get("interval_hours", 4)),
                "start_immediately": True,
            },
            "android": {
                "appium_server_url": "http://127.0.0.1:4723",
                "device_name": device,
                "udid": device,
                "app_package": "com.wellysis.spatchcardio.ex",
                "app_activity": "com.wellysis.spatchcardio.ex.MainActivity",
                "no_reset": True,
                "new_command_timeout": 3600,
            },
            "selectors": {"android": SPATCH_EX_SELECTORS},
            "symptom_plan": [],
            "symptom_catalog": symptoms,
            "slack": {"enabled": False, "webhook_url": "", "mention": ""},
        }

        cfg_path = ROOT / "config" / "_web_run.yaml"
        with open(cfg_path, "w", encoding="utf-8") as f:
            yaml.dump(cfg, f, allow_unicode=True, default_flow_style=False)

        start_ts = time.time()
        _state["start_ts"] = start_ts
        _state["out_dir"] = None
        _state["proc"] = subprocess.Popen(
            [sys.executable, str(ROOT / "main.py"), "--config", str(cfg_path)],
            cwd=str(ROOT),
        )

        return jsonify({"ok": True})


@app.route("/api/stop", methods=["POST"])
def api_stop():
    with _lock:
        proc = _state["proc"]
        if proc and proc.poll() is None:
            proc.terminate()
        _state["proc"] = None
    return jsonify({"ok": True})


# ── Entry point ───────────────────────────────────────────────────────────────

if __name__ == "__main__":
    import webbrowser
    threading.Timer(1.2, lambda: webbrowser.open("http://127.0.0.1:5001")).start()
    print("\n  ✓ SpatchEx 테스트 UI → http://127.0.0.1:5001\n")
    app.run(host="127.0.0.1", port=5001, debug=False, threaded=True)
