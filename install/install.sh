#!/usr/bin/env bash
# SpatchEx Automation Tool — Mac first-time install script
# Usage: bash install/install.sh  (or double-click run.command)
set -e
cd "$(dirname "$0")/.."

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  OK  $1${NC}"; }
step() { echo -e "\n${YELLOW}[$1] $2${NC}"; }
err()  { echo -e "${RED}  !! $1${NC}"; exit 1; }

echo ""
echo "  +============================================+"
echo "  |  SpatchEx Long-Run Test -- Mac Setup      |"
echo "  +============================================+"
echo ""

# ── appium_run helper: uses global appium or npx fallback ────────────────────
USE_NPX=0
appium_run() {
  if [ "$USE_NPX" = "1" ]; then
    npx -y appium@3 "$@"
  else
    appium "$@"
  fi
}

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "1/6" "Homebrew"
if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew (may require sudo password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
fi
ok "Homebrew $(brew --version | head -1)"

# ── 2. Python 3 ───────────────────────────────────────────────────────────────
step "2/6" "Python 3"
if ! command -v python3 &>/dev/null; then
  brew install python
fi
ok "$(python3 --version)"

# ── 3. Node.js / npm ──────────────────────────────────────────────────────────
step "3/6" "Node.js / npm"
if ! command -v node &>/dev/null; then
  brew install node
fi
ok "Node.js $(node --version) | npm $(npm --version)"

# ── 4. ADB (Android Debug Bridge) ─────────────────────────────────────────────
step "4/6" "ADB (Android Debug Bridge)"
if ! command -v adb &>/dev/null; then
  brew install --cask android-platform-tools
fi
ok "ADB $(adb --version | head -1)"

# ── 5. Appium + UiAutomator2 driver ──────────────────────────────────────────
step "5/6" "Appium"

if command -v appium &>/dev/null && appium -v &>/dev/null 2>&1; then
  ok "Appium $(appium -v 2>/dev/null) (global)"
else
  echo "  Not found. Installing globally via npm (this can take a few minutes)..."
  npm i -g appium

  if command -v appium &>/dev/null && appium -v &>/dev/null 2>&1; then
    ok "Appium $(appium -v 2>/dev/null) (global)"
  else
    echo "  npm global install failed or appium not runnable. Trying npx fallback..."
    if npx -y appium@3 -v &>/dev/null 2>&1; then
      USE_NPX=1
      ok "Appium ready (via npx)"
    else
      err "Appium could not be started. Check your Node.js installation and internet connection."
    fi
  fi
fi

echo "  Checking UiAutomator2 driver..."
if ! appium_run driver list --installed 2>&1 | grep -q "uiautomator2"; then
  echo "  Not installed. Installing (this can take a few minutes)..."
  appium_run driver install uiautomator2
fi
ok "UiAutomator2 driver installed"
echo "  Installed drivers:"
appium_run driver list --installed 2>/dev/null | grep -E "uiautomator|xcuitest" || true

# ── 6. Python virtual environment ─────────────────────────────────────────────
step "6/6" "Python packages"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
source .venv/bin/activate
pip install -r requirements.txt
ok "Python packages installed"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "  +============================================+"
echo "  |  Setup complete!                          |"
echo "  +============================================+"
echo ""
echo "  Next steps:"
echo "  1. Connect your Android phone via USB or pair via WiFi"
echo "  2. Double-click run.command -> browser opens automatically"
echo ""
echo "  Verification commands:"
echo "    appium -v"
echo "    appium driver list --installed"
echo "    python3 -c 'import sys; print(sys.version)'"
echo ""
