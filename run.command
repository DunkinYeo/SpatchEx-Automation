#!/bin/bash
# ============================================================
# SpatchEx -- Launch Test Environment
# run.command  (project root)
#
#  Double-click this file in Finder to start.
#  Browser opens automatically when the server is ready.
#  Leave this window OPEN during the test.
#  To stop: run STOP.command or press Ctrl+C here.
# ============================================================

# Ensure this script is executable
chmod +x "$0" 2>/dev/null || true

# Change to script directory -- critical for Finder double-click
cd "$(dirname "$0")" || {
    echo "ERROR: Failed to change to script directory."
    read -r _; exit 1
}

LOG_FILE="/tmp/spatch_run_$(date +%Y%m%d_%H%M%S).log"
echo "SpatchEx run started $(date)" >> "$LOG_FILE"

echo ""
echo "  =============================================="
echo "  |   SpatchEx -- Launch Test Environment      |"
echo "  =============================================="
echo ""
echo "  Log: $LOG_FILE"
echo ""

# ── [1] Verify project root ──────────────────────────────────
if [ ! -f "web/app.py" ]; then
    echo "  ERROR: web/app.py not found."
    echo "  Run run.command from inside the SpatchEx-Automation folder."
    echo ""
    echo "[run] FAIL: web/app.py not found" >> "$LOG_FILE"
    read -r -p "  Press Enter to close... " _
    exit 1
fi

# ── [2] Check .venv ──────────────────────────────────────────
if [ ! -f ".venv/bin/activate" ]; then
    echo "  ERROR: Python environment not set up."
    echo ""
    echo "  Please run install.command first, then re-run run.command."
    echo ""
    echo "[run] FAIL: .venv not found" >> "$LOG_FILE"
    read -r -p "  Press Enter to close... " _
    exit 1
fi

# ── [3] Activate virtual environment ─────────────────────────
echo "  Activating Python environment..."
# shellcheck disable=SC1091
source .venv/bin/activate
echo "[run] .venv activated" >> "$LOG_FILE"

# ── [4] ADB / Android SDK detection ──────────────────────────
# Try bundled runtime first, then common macOS SDK locations
if [ -f "runtime/android-sdk/platform-tools/adb" ]; then
    export ANDROID_HOME="$PWD/runtime/android-sdk"
    export ANDROID_SDK_ROOT="$PWD/runtime/android-sdk"
    export PATH="$PWD/runtime/android-sdk/platform-tools:$PATH"
elif [ -z "$ANDROID_HOME" ]; then
    for SDK_PATH in \
        "$HOME/Library/Android/sdk" \
        "$HOME/Android/Sdk" \
        "/usr/local/share/android-sdk" \
        "/opt/android-sdk" \
        "/opt/homebrew/share/android-sdk"; do
        if [ -f "$SDK_PATH/platform-tools/adb" ]; then
            export ANDROID_HOME="$SDK_PATH"
            export ANDROID_SDK_ROOT="$SDK_PATH"
            export PATH="$SDK_PATH/platform-tools:$PATH"
            break
        fi
    done
fi

# ── [5] ADB device check (warn only -- does NOT block startup) ─
echo "  Checking connected devices..."
if ! command -v adb >/dev/null 2>&1; then
    echo "  WARN  ADB not found. Device check skipped."
    echo "[run] WARN: adb not found" >> "$LOG_FILE"
else
    DEV_OK=0
    while IFS= read -r line; do
        case "$line" in
            *$'\t'device) DEV_OK=1 ;;
        esac
    done < <(adb devices 2>/dev/null | tail -n +2)

    if [ "$DEV_OK" -eq 1 ]; then
        echo "  PASS  Android device connected and authorized."
        echo "[run] device connected" >> "$LOG_FILE"
    else
        echo ""
        echo "  WARN  No Android device detected."
        echo "        Connect your phone via USB and enable USB Debugging."
        echo "        The web UI will still open. Connect the device before"
        echo "        clicking \"Start Test\" in the browser."
        echo ""
        echo "[run] WARN: no device" >> "$LOG_FILE"
    fi
fi

# ── [6] Start Appium (skip if already on port 4723) ──────────
echo ""
echo "  Checking Appium (port 4723)..."
if lsof -i tcp:4723 >/dev/null 2>&1; then
    echo "  Appium already running on port 4723."
    echo "[run] Appium already on 4723" >> "$LOG_FILE"
else
    if ! command -v appium >/dev/null 2>&1; then
        echo "  WARN  Appium not found. Run install.command first."
        echo "[run] WARN: appium not found" >> "$LOG_FILE"
    else
        echo "  Starting Appium server..."
        echo "[run] Starting Appium" >> "$LOG_FILE"
        nohup appium --relaxed-security >> "$LOG_FILE" 2>&1 &
        APPIUM_PID=$!
        echo "  Appium starting in background (PID $APPIUM_PID)."
    fi
fi

# ── [7] Start web server + health-check browser opener ───────
echo ""
echo "  Starting web server on port 5001..."
echo "[run] Starting web server" >> "$LOG_FILE"

if [ ! -f "web/app.py" ]; then
    echo "  ERROR: web/app.py not found."
    echo "[run] FAIL: web/app.py missing at launch" >> "$LOG_FILE"
    read -r -p "  Press Enter to close... " _
    exit 1
fi

# Background health check:
#   Polls http://127.0.0.1:5001 up to 30 times (1 second apart).
#   Opens browser ONLY after the server responds successfully.
#   NEVER opens the browser before the server is alive.
(
    for i in $(seq 1 30); do
        if curl -sf --max-time 2 "http://127.0.0.1:5001" >/dev/null 2>&1; then
            open "http://127.0.0.1:5001"
            exit 0
        fi
        sleep 1
    done
    echo ""
    echo "  WARN  Server did not respond within 30 seconds."
    echo "  Check the log file: $LOG_FILE"
) &
HEALTH_PID=$!

# Web server runs in foreground -- keeps this window alive while running.
# Press Ctrl+C or run STOP.command to shut everything down.
echo "  Browser will open automatically when the server is ready."
echo "  Leave this window OPEN during the test."
echo ""

python web/app.py

# ── Server exited ─────────────────────────────────────────────
kill "$HEALTH_PID" 2>/dev/null || true
echo ""
echo "[run] Web server exited" >> "$LOG_FILE"
echo "  Web server has stopped."
echo "  Run STOP.command to terminate any remaining services."
echo ""
read -r -p "  Press Enter to close... " _
exit 0
