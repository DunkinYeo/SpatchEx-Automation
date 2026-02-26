# spatch-longrun-automation

Long-running app test orchestrator for S-PATCH EX style apps (24/48/72h) with **scheduled symptom injection**.
Android first (Appium + UiAutomator2). iOS stub included for later.

## What this does (MVP)
- Starts a measurement (handles online/offline consent path)
- While test is running: injects symptoms every N hours (or by a plan)
- Collects artifacts on every injection (screenshot + logs)
- Watchdog: retries, brings app to foreground, and attempts recovery
- Outputs: `output/<run_id>/...` with JSONL event log + HTML summary

## Requirements
- Python 3.10+
- Appium Server 2.x
- Android device connected via USB (adb works)
- UiAutomator2 driver installed (Appium doctor helps)

## Setup (Android)
```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Start appium in a separate terminal
appium --relaxed-security
```

Create `config/run.yaml` from the example:
```bash
cp config/run.example.yaml config/run.yaml
```

Run:
```bash
python main.py --config config/run.yaml
```

## Notes on selectors
This project prefers **text/accessibility-id** selectors.
If your Android build uses resource-id, add it in `selectors.android.*` in the YAML.

## Safety
Long-running tests fail in reality. This tool:
- retries UI actions
- captures artifacts on failure
- logs everything with timestamps

---

If you want, we can extend to multi-node (miniPC/RPi) orchestration and Slack notifications.
