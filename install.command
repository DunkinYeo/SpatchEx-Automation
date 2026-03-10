#!/usr/bin/env bash
# ============================================================
# SpatchEx -- First-Time Setup (macOS, Finder double-click)
# install.command  (project root)
#
#  Double-click in Finder, or run from Terminal.
# ============================================================

# Ensure executable after ZIP extraction
chmod +x "$0" 2>/dev/null || true

# Change to project root
cd "$(dirname "$0")" || { echo "  ERROR: Cannot change to script directory."; read -r _; exit 1; }

LOG_FILE="/tmp/spatch_install_$(date +%Y%m%d_%H%M%S).log"
FAIL=0
PYTHON=""

echo "SpatchEx install started $(date)" >> "$LOG_FILE"

echo ""
echo "  =============================================="
echo "  |   SpatchEx -- Environment Setup           |"
echo "  =============================================="
echo ""
echo "  Log: $LOG_FILE"
echo ""

# Verify project root
if [ ! -f "web/app.py" ]; then
    echo "  ERROR  web/app.py not found."
    echo "  Run install.command from inside the SpatchEx-Automation folder."
    echo ""
    read -r -p "  Press Enter to close... " _
    exit 1
fi

# ============================================================
# [1] Python 3.10+
# ============================================================
echo "[1] Python..."
PYTHON=""
if command -v python3 >/dev/null 2>&1; then
    PYTHON="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON="python"
else
    echo ""
    echo "  ERROR  Python not found."
    echo ""
    echo "  Install options:"
    echo "    A) Download: https://www.python.org/downloads/"
    echo "    B) Homebrew:  brew install python@3.12"
    echo ""
    echo "[1] FAIL: python not found" >> "$LOG_FILE"
    FAIL=1
fi

if [ -n "$PYTHON" ]; then
    PY_VERSION=$("$PYTHON" --version 2>&1)
    echo "  PASS  $PY_VERSION ($PYTHON)"
    echo "[1] PASS: $PY_VERSION" >> "$LOG_FILE"
fi

# ============================================================
# [2] Node.js / npm
# ============================================================
echo ""
echo "[2] Node.js / npm..."
if ! command -v node >/dev/null 2>&1; then
    echo ""
    echo "  ERROR  Node.js not found."
    echo ""
    echo "  Install options:"
    echo "    A) Download: https://nodejs.org/ (choose LTS version)"
    echo "    B) Homebrew:  brew install node"
    echo ""
    echo "[2] FAIL: node not found" >> "$LOG_FILE"
    FAIL=1
elif ! command -v npm >/dev/null 2>&1; then
    echo ""
    echo "  ERROR  Node.js found but npm not detected."
    echo "  Reinstall Node.js from https://nodejs.org/"
    echo ""
    echo "[2] FAIL: npm not found" >> "$LOG_FILE"
    FAIL=1
else
    NODE_VER=$(node --version 2>&1)
    NPM_VER=$(npm --version 2>&1)
    echo "  PASS  Node.js $NODE_VER"
    echo "  PASS  npm v$NPM_VER"
    echo "[2] PASS: node $NODE_VER" >> "$LOG_FILE"
fi

# ============================================================
# [3] ADB / Android SDK
# ============================================================
echo ""
echo "[3] ADB / Android SDK..."
ADB_FOUND=0

if command -v adb >/dev/null 2>&1; then
    ADB_VER=$(adb version 2>&1 | head -1)
    echo "  PASS  $ADB_VER"
    echo "[3] PASS: $ADB_VER" >> "$LOG_FILE"
    ADB_FOUND=1
else
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
            ADB_VER=$(adb version 2>&1 | head -1)
            echo "  INFO  Found Android SDK at $SDK_PATH"
            echo "  PASS  $ADB_VER"
            echo "[3] PASS: $ADB_VER (at $SDK_PATH)" >> "$LOG_FILE"
            ADB_FOUND=1
            break
        fi
    done
fi

if [ "$ADB_FOUND" -eq 0 ]; then
    echo ""
    echo "  ERROR  Android SDK not found."
    echo ""
    echo "  Install options:"
    echo "    A) Install Android Studio: https://developer.android.com/studio"
    echo "    B) Homebrew: brew install android-platform-tools"
    echo ""
    echo "  After installing, re-run install.command."
    echo ""
    echo "[3] FAIL: adb not found" >> "$LOG_FILE"
    FAIL=1
fi

# ============================================================
# [4] Appium
# ============================================================
echo ""
echo "[4] Appium..."
if [ "$FAIL" -eq 1 ]; then
    echo "  SKIP  Appium check skipped due to earlier errors."
    echo "[4] SKIP: earlier failures" >> "$LOG_FILE"
elif command -v appium >/dev/null 2>&1; then
    APPIUM_VER=$(appium -v 2>&1 | head -1)
    echo "  PASS  Appium $APPIUM_VER"
    echo "[4] PASS: Appium $APPIUM_VER" >> "$LOG_FILE"
else
    echo "  Appium not found. Installing globally via npm..."
    echo "  (This may take 1-3 minutes)"
    echo "[4] Installing appium..." >> "$LOG_FILE"
    npm install -g appium
    if [ $? -ne 0 ]; then
        echo ""
        echo "  ERROR  Failed to install Appium."
        echo ""
        echo "  Try: sudo npm install -g appium"
        echo ""
        echo "[4] FAIL: npm install -g appium" >> "$LOG_FILE"
        FAIL=1
    else
        APPIUM_VER=$(appium -v 2>&1 | head -1)
        echo "  PASS  Appium $APPIUM_VER installed."
        echo "[4] PASS: Appium $APPIUM_VER" >> "$LOG_FILE"
    fi
fi

# ============================================================
# [5] UiAutomator2 driver
# ============================================================
echo ""
echo "[5] UiAutomator2 driver..."
if ! command -v appium >/dev/null 2>&1; then
    echo "  SKIP  Appium unavailable -- skipping driver check."
    echo "[5] SKIP" >> "$LOG_FILE"
else
    DRIVER_TMP="/tmp/spatch_drivers_$$.txt"
    appium driver list --installed > "$DRIVER_TMP" 2>&1
    if grep -qi "uiautomator2" "$DRIVER_TMP"; then
        echo "  PASS  UiAutomator2 driver already installed."
        echo "[5] PASS" >> "$LOG_FILE"
        rm -f "$DRIVER_TMP"
    else
        rm -f "$DRIVER_TMP"
        echo "  UiAutomator2 not found. Installing..."
        echo "  (This may take 1-3 minutes)"
        echo "[5] Installing uiautomator2..." >> "$LOG_FILE"
        appium driver install uiautomator2
        if [ $? -ne 0 ]; then
            echo ""
            echo "  ERROR  Failed to install UiAutomator2 driver."
            echo "  Try manually: appium driver install uiautomator2"
            echo ""
            echo "[5] FAIL: driver install" >> "$LOG_FILE"
            FAIL=1
        else
            echo "  PASS  UiAutomator2 driver installed."
            echo "[5] PASS" >> "$LOG_FILE"
        fi
    fi
fi

# ============================================================
# [6] Python virtual environment + packages
# ============================================================
echo ""
echo "[6] Python virtual environment..."
if [ "$FAIL" -eq 1 ] || [ -z "$PYTHON" ]; then
    echo "  SKIP  Skipping Python setup due to earlier errors."
    echo "[6] SKIP: earlier failures" >> "$LOG_FILE"
elif [ ! -f "requirements.txt" ]; then
    echo "  ERROR  requirements.txt not found."
    echo "[6] FAIL: requirements.txt missing" >> "$LOG_FILE"
    FAIL=1
else
    if [ ! -f ".venv/bin/activate" ]; then
        echo "  Creating .venv..."
        "$PYTHON" -m venv .venv
        if [ $? -ne 0 ]; then
            echo ""
            echo "  ERROR  Failed to create .venv."
            echo "  Ensure Python 3.10+ is correctly installed."
            echo ""
            echo "[6] FAIL: venv create" >> "$LOG_FILE"
            FAIL=1
        else
            echo "  .venv created."
        fi
    else
        echo "  INFO  .venv already exists. Skipping creation."
    fi

    if [ "$FAIL" -eq 0 ]; then
        echo "  Installing Python packages..."
        # shellcheck disable=SC1091
        source .venv/bin/activate
        pip install --upgrade pip
        pip install -r requirements.txt
        if [ $? -ne 0 ]; then
            echo ""
            echo "  ERROR  pip install failed."
            echo "  Check your network connection and requirements.txt."
            echo ""
            echo "[6] FAIL: pip install" >> "$LOG_FILE"
            FAIL=1
        else
            echo "  PASS  Python packages installed."
            echo "[6] PASS" >> "$LOG_FILE"
        fi
    fi
fi

# ============================================================
# [7] Runtime folders
# ============================================================
echo ""
echo "[7] Runtime folders..."
mkdir -p logs runtime
echo "  PASS  logs/ and runtime/ are ready."
echo "[7] PASS" >> "$LOG_FILE"

# ============================================================
# Summary
# ============================================================
echo ""
echo "SpatchEx install ended $(date)" >> "$LOG_FILE"

if [ "$FAIL" -eq 1 ]; then
    echo "  =============================================="
    echo "  |   Setup encountered errors.              |"
    echo "  =============================================="
    echo ""
    echo "  One or more steps failed. Fix the errors above and re-run install.command."
    echo "  Full log: $LOG_FILE"
    echo ""
    read -r -p "  Press Enter to close... " _
    exit 1
fi

echo ""
echo "  --------------------------------------"
echo "  SpatchEx Automation Installed"
echo "  Next step: double-click run.command"
echo "  --------------------------------------"
echo ""
echo "  Full log: $LOG_FILE"
echo ""
echo "[DONE]" >> "$LOG_FILE"
read -r -p "  Press Enter to close... " _
exit 0
