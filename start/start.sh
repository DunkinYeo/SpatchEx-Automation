#!/usr/bin/env bash
# SpatchEx Long-Run Test -- Mac Start
# Usage: bash start/start.sh  (or via run.command)
set -e
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  OK  $1${NC}"; }
warn() { echo -e "${YELLOW}  !!  $1${NC}"; }
err()  { echo -e "${RED}  !!  $1${NC}"; exit 1; }

# ── appium_run helper ─────────────────────────────────────────────────────────
USE_NPX=0
appium_run() {
  if [ "$USE_NPX" = "1" ]; then
    npx -y appium@3 "$@"
  else
    appium "$@"
  fi
}

# ── Timestamp + log paths ─────────────────────────────────────────────────────
mkdir -p artifacts/logs
TS=$(date +%Y%m%d_%H%M%S)
APPIUM_LOG="artifacts/logs/appium_${TS}.log"
APPIUM_PID=""

echo ""
echo "  +============================================+"
echo "  |  SpatchEx Long-Run Test -- Mac Start      |"
echo "  +============================================+"
echo ""

# ── [1] Virtual environment ───────────────────────────────────────────────────
if [ ! -f ".venv/bin/activate" ]; then
  err "Virtual environment not found. Run: bash install/install.sh"
fi
source .venv/bin/activate
ok ".venv activated"

# Ensure Flask is present (fast no-op if already installed)
python -c "import flask" 2>/dev/null || pip install flask -q

# ── [2] Appium ────────────────────────────────────────────────────────────────
if command -v appium &>/dev/null && appium -v &>/dev/null 2>&1; then
  USE_NPX=0
  ok "Appium $(appium -v 2>/dev/null)"
elif npx -y appium@3 -v &>/dev/null 2>&1; then
  USE_NPX=1
  ok "Appium ready (via npx)"
else
  err "Appium not found. Run: bash install/install.sh"
fi

# ── [3] UiAutomator2 driver ───────────────────────────────────────────────────
if ! appium_run driver list --installed 2>&1 | grep -q "uiautomator2"; then
  err "UiAutomator2 driver not installed. Run: appium driver install uiautomator2"
fi
ok "UiAutomator2 driver installed"

# ── [4] ADB device check (warning only) ──────────────────────────────────────
echo ""
echo "  Connected Android devices:"
if command -v adb &>/dev/null; then
  adb devices 2>/dev/null
  if ! adb devices 2>/dev/null | grep -q "device$"; then
    warn "No authorized device detected. Connect via USB and enable USB Debugging."
  fi
else
  warn "adb not found — install Android Platform Tools or connect later."
fi
echo ""

# ── [5] Appium server — start in background if not already running ────────────
if lsof -i :4723 &>/dev/null 2>&1; then
  ok "Appium already running on port 4723"
else
  echo "  Starting Appium server..."
  echo "  Log: $APPIUM_LOG"
  appium_run --relaxed-security > "$APPIUM_LOG" 2>&1 &
  APPIUM_PID=$!
  sleep 3
  if ! kill -0 "$APPIUM_PID" 2>/dev/null; then
    warn "Appium may have failed to start. Check log: $APPIUM_LOG"
  else
    ok "Appium running (PID $APPIUM_PID)"
  fi
fi

# ── Cleanup: kill Appium when this script exits ───────────────────────────────
_cleanup() {
  if [ -n "$APPIUM_PID" ]; then
    echo ""
    echo "  Stopping Appium (PID $APPIUM_PID)..."
    kill "$APPIUM_PID" 2>/dev/null || true
  fi
}
trap _cleanup INT TERM EXIT

# ── [6] Open browser + start Web UI ──────────────────────────────────────────
open "http://127.0.0.1:5001" 2>/dev/null || true

echo "  +============================================+"
echo "  |  Web UI:  http://127.0.0.1:5001          |"
echo "  |  Logs:    artifacts/logs/                 |"
echo "  |  Stop:    Ctrl+C (stops Appium too)       |"
echo "  +============================================+"
echo ""

python web/app.py
