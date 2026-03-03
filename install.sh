#!/usr/bin/env bash
# SpatchEx Automation Tool — Mac first-time install script
# Usage: bash install.sh  (or ./install.sh)
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  OK  $1${NC}"; }
step() { echo -e "\n${YELLOW}>> $1${NC}"; }
err()  { echo -e "${RED}  !! $1${NC}"; exit 1; }

echo ""
echo "  +--------------------------------------+"
echo "  |  SpatchEx Long-Run Test -- Setup     |"
echo "  +--------------------------------------+"
echo ""

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "Checking Homebrew"
if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew (may require admin password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Apple Silicon PATH fix
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
  ok "Homebrew installed"
else
  ok "Homebrew already installed"
fi

# ── 2. Python 3 ───────────────────────────────────────────────────────────────
step "Checking Python 3"
if ! command -v python3 &>/dev/null; then
  brew install python
  ok "Python installed"
else
  PY_VER=$(python3 --version)
  ok "Python already installed ($PY_VER)"
fi

# ── 3. Node.js (required by Appium) ──────────────────────────────────────────
step "Checking Node.js"
if ! command -v node &>/dev/null; then
  brew install node
  ok "Node.js installed"
else
  ok "Node.js already installed ($(node --version))"
fi

# ── 4. Android Platform Tools (adb) ──────────────────────────────────────────
step "Checking ADB"
if ! command -v adb &>/dev/null; then
  brew install --cask android-platform-tools
  ok "ADB installed"
else
  ok "ADB already installed ($(adb --version | head -1))"
fi

# ── 5. Appium (via npx — no global install needed) ────────────────────────────
step "Checking Appium (first run downloads ~50 MB, subsequent runs use cache)"
if npx -y appium@3 -v &>/dev/null; then
  ok "Appium ready ($(npx -y appium@3 -v 2>/dev/null))"
else
  err "Appium could not run via npx. Check your internet connection and Node.js installation."
fi

step "Checking Appium UiAutomator2 driver"
if ! npx -y appium@3 driver list --installed 2>&1 | grep -q "uiautomator2"; then
  npx -y appium@3 driver install uiautomator2
  ok "UiAutomator2 driver installed"
else
  ok "UiAutomator2 driver already installed"
fi

# ── 6. Python virtual environment ────────────────────────────────────────────
step "Setting up Python virtual environment"
if [ ! -d ".venv" ]; then
  python3 -m venv .venv
  ok "Virtual environment created"
else
  ok "Virtual environment already exists"
fi

source .venv/bin/activate
pip install -r requirements.txt -q
ok "Python packages installed"

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "  +--------------------------------------+"
echo "  |        Setup complete!               |"
echo "  +--------------------------------------+"
echo ""
echo "  Next steps:"
echo "  1. Connect your Android phone via USB or pair via WiFi"
echo "  2. Run ./start.sh -> browser opens automatically"
echo ""
