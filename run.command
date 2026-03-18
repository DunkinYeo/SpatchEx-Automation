#!/usr/bin/env bash
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

# Bootstrap PATH so Homebrew tools (python3, node, npm, adb, appium)
# are reachable when launched from Finder (non-login shell).
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

LOG_FILE="/tmp/spatch_run_$(date +%Y%m%d_%H%M%S).log"
echo "SpatchEx run started $(date)" >> "$LOG_FILE"

echo ""
echo "  =============================================="
echo "  |   SpatchEx -- Launch Test Environment      |"
echo "  =============================================="
echo ""
echo "  If issues occur, please send this log file:"
echo "  $LOG_FILE"
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

# ── [3] Python detection ─────────────────────────────────────
PYTHON=""
if [ -f ".venv/bin/python" ]; then
    PYTHON=".venv/bin/python"
elif command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON="python"
else
    echo "  ERROR: python not found."
    echo "  Install Python 3.10+ from https://www.python.org/downloads/"
    echo ""
    echo "[run] FAIL: python not found" >> "$LOG_FILE"
    read -r -p "  Press Enter to close... " _
    exit 1
fi

# ── [4] Activate virtual environment ─────────────────────────
echo "  Activating Python environment..."
# shellcheck disable=SC1091
source .venv/bin/activate
echo "[run] .venv activated" >> "$LOG_FILE"

# ── [5] ADB / Android SDK detection ──────────────────────────
echo "  Detecting Android SDK..."

# Case A: bundled runtime (flat layout -- platform-tools directly in runtime/)
if [ -f "runtime/platform-tools/adb" ]; then
    export ANDROID_HOME="$PWD/runtime"
    export ANDROID_SDK_ROOT="$PWD/runtime"
    export PATH="$PWD/runtime/platform-tools:$PATH"

# Case A2: bundled runtime (legacy android-sdk layout)
elif [ -f "runtime/android-sdk/platform-tools/adb" ]; then
    export ANDROID_HOME="$PWD/runtime/android-sdk"
    export ANDROID_SDK_ROOT="$PWD/runtime/android-sdk"
    export PATH="$ANDROID_HOME/platform-tools:$PATH"

# Case B-1: ANDROID_HOME already set and valid
elif [ -n "$ANDROID_HOME" ] && [ -f "$ANDROID_HOME/platform-tools/adb" ]; then
    export ANDROID_SDK_ROOT="$ANDROID_HOME"
    export PATH="$ANDROID_HOME/platform-tools:$PATH"

# Case B-2: ANDROID_SDK_ROOT already set and valid
elif [ -n "$ANDROID_SDK_ROOT" ] && [ -f "$ANDROID_SDK_ROOT/platform-tools/adb" ]; then
    export ANDROID_HOME="$ANDROID_SDK_ROOT"
    export PATH="$ANDROID_HOME/platform-tools:$PATH"

# Case C: common macOS SDK paths (Android Studio default)
else
    SDK_FOUND=0
    for SDK_PATH in \
        "$HOME/Library/Android/sdk" \
        "$HOME/Android/Sdk" \
        "/usr/local/share/android-sdk" \
        "/opt/android-sdk" \
        "/opt/homebrew/share/android-sdk"; do
        if [ -f "$SDK_PATH/platform-tools/adb" ]; then
            export ANDROID_HOME="$SDK_PATH"
            export ANDROID_SDK_ROOT="$SDK_PATH"
            export PATH="$ANDROID_HOME/platform-tools:$PATH"
            SDK_FOUND=1
            break
        fi
    done

    # Case D: derive SDK root from adb in PATH
    # Validates the derived path actually contains platform-tools/adb.
    # Guards against Homebrew adb (/opt/homebrew/bin/adb) which would
    # incorrectly derive /opt/homebrew as the SDK root.
    if [ "$SDK_FOUND" -eq 0 ]; then
        ADB_PATH=$(which adb 2>/dev/null)
        if [ -n "$ADB_PATH" ]; then
            PLATFORM_TOOLS=$(dirname "$ADB_PATH")
            SDK_ROOT=$(dirname "$PLATFORM_TOOLS")
            if [ -f "$SDK_ROOT/platform-tools/adb" ]; then
                export ANDROID_HOME="$SDK_ROOT"
                export ANDROID_SDK_ROOT="$SDK_ROOT"
                export PATH="$ANDROID_HOME/platform-tools:$PATH"
                SDK_FOUND=1
            fi
        fi
    fi

    # Case E: adb reachable via PATH directly (e.g. brew install android-platform-tools).
    # ANDROID_HOME is not set, but Appium and adb work fine with adb on PATH.
    if [ "$SDK_FOUND" -eq 0 ] && command -v adb >/dev/null 2>&1; then
        SDK_FOUND=1
        echo "  INFO  ADB found via PATH (Homebrew / standalone install)."
        echo "        ANDROID_HOME is not set; Appium will use adb from PATH."
        echo "[run] ADB via PATH (no SDK root)" >> "$LOG_FILE"
    fi

    if [ "$SDK_FOUND" -eq 0 ]; then
        echo ""
        echo "  ERROR  Android SDK / ADB not found."
        echo ""
        echo "  Neither ANDROID_HOME nor adb in PATH could be resolved."
        echo ""
        echo "  Install options:"
        echo "    A) Homebrew (recommended): brew install android-platform-tools"
        echo "    B) Android Studio:         https://developer.android.com/studio"
        echo ""
        echo "  After installing, open a new Terminal and re-run run.command."
        echo ""
        echo "[run] FAIL: ADB not found" >> "$LOG_FILE"
        read -r -p "  Press Enter to close... " _
        exit 1
    fi
fi

# ── [6] Diagnostics ──────────────────────────────────────────
echo ""
echo "  --- Environment ---"
echo "  ANDROID_HOME=$ANDROID_HOME"
echo "  ANDROID_SDK_ROOT=$ANDROID_SDK_ROOT"
echo "  Python: $($PYTHON --version 2>&1)"
node --version >/dev/null 2>&1 && echo "  Node:   $(node --version 2>&1)"
appium -v >/dev/null 2>&1  && echo "  Appium: $(appium -v 2>&1 | head -1)"
adb version >/dev/null 2>&1  && echo "  ADB:    $(adb version 2>&1 | head -1)"
echo "  -------------------"
echo ""
echo "[run] ANDROID_HOME=$ANDROID_HOME" >> "$LOG_FILE"

# ── [6a] Optional WiFi ADB auto-connect (SPATCH_DEVICE_IP) ───
if [ -n "$SPATCH_DEVICE_IP" ] && command -v adb >/dev/null 2>&1; then
    echo "  Attempting WiFi connection to ${SPATCH_DEVICE_IP}:5555 ..."
    adb connect "${SPATCH_DEVICE_IP}:5555" >/dev/null 2>&1
    sleep 2
    if adb devices 2>/dev/null | grep -qF "${SPATCH_DEVICE_IP}:5555"$'\t'"device"; then
        echo "  WiFi device connected: ${SPATCH_DEVICE_IP}:5555"
    else
        echo "  WiFi connection failed: ${SPATCH_DEVICE_IP}:5555"
        echo ""
        echo "  Hints:"
        echo "    - Make sure phone and PC are on the same WiFi network"
        echo "    - Verify USB Debugging is enabled on the device"
        echo "    - Confirm device IP: Settings > About phone > Status"
    fi
    echo ""
fi

# ── [7] ADB device check (warn only -- does NOT block startup) ─
echo "  Checking connected devices..."
if ! command -v adb >/dev/null 2>&1; then
    echo "  WARN  ADB not found. Device check skipped."
    echo "[run] WARN: adb not found" >> "$LOG_FILE"
else
    ADB_OUT=$(adb devices 2>/dev/null | tail -n +2 | grep -v '^$')
    DEV_OK=0
    USB_LIST=""
    WIFI_LIST=""
    FIRST_USB_SERIAL=""
    while IFS= read -r line; do
        case "$line" in
            *$'\t'device)
                DEV_OK=1
                serial="${line%%$'\t'*}"
                case "$serial" in
                    *:5555) WIFI_LIST="$WIFI_LIST    [WiFi] $serial\n" ;;
                    *)      USB_LIST="$USB_LIST    [USB ] $serial\n"
                            [ -z "$FIRST_USB_SERIAL" ] && FIRST_USB_SERIAL="$serial"
                            ;;
                esac
                ;;
        esac
    done <<< "$ADB_OUT"

    if [ "$DEV_OK" -eq 1 ]; then
        echo "  PASS  Android device(s) connected and authorized:"
        [ -n "$USB_LIST"  ] && printf "$USB_LIST"
        [ -n "$WIFI_LIST" ] && printf "$WIFI_LIST"
        echo "[run] device connected" >> "$LOG_FILE"
        # ── Prepare ADB over WiFi and save device IP (non-blocking) ─
        if [ -n "$FIRST_USB_SERIAL" ] && command -v adb >/dev/null 2>&1; then
            echo "  Preparing ADB over WiFi..."
            adb -s "$FIRST_USB_SERIAL" tcpip 5555 >/dev/null 2>&1
            sleep 1
            _WIFI_IP=$(adb -s "$FIRST_USB_SERIAL" shell ip route 2>/dev/null \
                | grep -oE 'src [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+' \
                | awk '{print $2}' | head -1)
            if [ -n "$_WIFI_IP" ]; then
                echo "  Saved WiFi device IP: $_WIFI_IP"
                echo "[run] WiFi IP saved: $_WIFI_IP" >> "$LOG_FILE"
                mkdir -p automation/runtime
                printf '{"device_id":"%s","wifi_ip":"%s","tcp_port":5555,"updated_at":"%s"}\n' \
                    "$FIRST_USB_SERIAL" "$_WIFI_IP" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                    > "automation/runtime/adb_wifi_device.json"
            fi
        fi
    else
        # ── Try cached WiFi before showing warning ──────────────────
        _WIFI_CACHE="automation/runtime/adb_wifi_device.json"
        if [ -f "$_WIFI_CACHE" ]; then
            _CACHED_IP=$(python3 -c "import json; d=json.load(open('$_WIFI_CACHE')); print(d.get('wifi_ip',''))" 2>/dev/null)
            _CACHED_PORT=$(python3 -c "import json; d=json.load(open('$_WIFI_CACHE')); print(d.get('tcp_port',5555))" 2>/dev/null)
            if [ -n "$_CACHED_IP" ] && [ -n "$_CACHED_PORT" ]; then
                echo "  Attempting saved WiFi ADB connection..."
                echo "[run] Attempting cached WiFi: ${_CACHED_IP}:${_CACHED_PORT}" >> "$LOG_FILE"
                adb connect "${_CACHED_IP}:${_CACHED_PORT}" >/dev/null 2>&1
                sleep 2
                if adb devices 2>/dev/null | grep -qF "${_CACHED_IP}:${_CACHED_PORT}"$'\t'"device"; then
                    echo "  Saved WiFi device connected."
                    echo "[run] Cached WiFi connected OK" >> "$LOG_FILE"
                    DEV_OK=1
                else
                    echo "  Saved WiFi connection failed."
                    echo "[run] Cached WiFi connect failed" >> "$LOG_FILE"
                fi
            fi
        fi
        if [ "$DEV_OK" -ne 1 ]; then
            echo ""
            echo "  WARN  No Android device detected."
            echo "        Connect your phone via USB and enable USB Debugging."
            echo "        The web UI will still open. Connect the device before"
            echo "        clicking \"Start Test\" in the browser."
            echo ""
            echo "[run] WARN: no device" >> "$LOG_FILE"
        fi
    fi
fi

# ── [8] Start Appium (skip if already on port 4723) ──────────
echo ""
echo "  Checking Appium (port 4723)..."
if curl -sf --max-time 2 "http://127.0.0.1:4723/status" >/dev/null 2>&1; then
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

# ── [9] Start web server + health-check browser opener ───────
echo ""
echo "  Starting web server on port 5001..."
echo "[run] Starting web server" >> "$LOG_FILE"

# Background health check:
#   Polls http://127.0.0.1:5001 up to 30 times (1 second apart).
#   Opens browser ONLY after the server responds successfully.
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
echo "  Browser will open automatically when the server is ready."
echo "  Leave this window OPEN during the test."
echo ""

# ── Sleep prevention ──────────────────────────────────────────
CAFF_PID=""
if command -v caffeinate >/dev/null 2>&1; then
    caffeinate -i &
    CAFF_PID=$!
    echo "  Sleep prevention enabled during test run."
fi

$PYTHON web/app.py

# ── Server exited ─────────────────────────────────────────────
kill "$HEALTH_PID" 2>/dev/null || true
if [ -n "$APPIUM_PID" ]; then
    kill "$APPIUM_PID" 2>/dev/null || true
    echo "  Appium server stopped."
fi
if [ -n "$CAFF_PID" ]; then
    kill "$CAFF_PID" 2>/dev/null || true
    echo "  Sleep prevention released."
fi
echo ""
echo "[run] Web server exited" >> "$LOG_FILE"
echo "  Web server has stopped."
echo "  Run STOP.command to terminate any remaining services."
echo ""
read -r -p "  Press Enter to close... " _
exit 0
