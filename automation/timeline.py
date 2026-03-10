import json
import os
from datetime import datetime
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
TIMELINE_FILE = _ROOT / "artifacts" / "timeline.json"


def log_event(event: str):
    os.makedirs(TIMELINE_FILE.parent, exist_ok=True)

    if not TIMELINE_FILE.exists():
        TIMELINE_FILE.write_text("[]", encoding="utf-8")

    with open(TIMELINE_FILE, "r", encoding="utf-8") as f:
        data = json.load(f)

    data.append({
        "time": datetime.now().strftime("%H:%M:%S"),
        "event": event
    })

    with open(TIMELINE_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
