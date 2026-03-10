import json
import os
from datetime import datetime
from pathlib import Path

_ROOT = Path(__file__).resolve().parent.parent
TIMELINE_FILE = str(_ROOT / "artifacts" / "timeline.json")


def log_event(event: str):
    os.makedirs(os.path.dirname(TIMELINE_FILE), exist_ok=True)

    if not os.path.exists(TIMELINE_FILE):
        with open(TIMELINE_FILE, "w") as f:
            json.dump([], f)

    with open(TIMELINE_FILE, "r") as f:
        data = json.load(f)

    data.append({
        "time": datetime.now().strftime("%H:%M:%S"),
        "event": event
    })

    with open(TIMELINE_FILE, "w") as f:
        json.dump(data, f, indent=2)
