#!/usr/bin/env bash
# SpatchEx Automation Tool -- Mac one-click bootstrap
# Usage: curl -fsSL https://raw.githubusercontent.com/DunkinYeo/SpatchEx-Automation/main/bootstrap.sh | bash
#
# What this script does:
#   1. Install Homebrew (if missing)
#   2. Install Git (if missing)
#   3. Download code to ~/SpatchEx-Automation
#   4. Install Python / Node.js / ADB / Appium / Python packages
#   5. Launch web UI -> opens browser automatically
set -e

REPO_URL="https://github.com/DunkinYeo/SpatchEx-Automation.git"
INSTALL_DIR="$HOME/SpatchEx-Automation"

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}  OK  $1${NC}"; }
step() { echo -e "\n${YELLOW}${BOLD}>> $1${NC}"; }

echo ""
echo "  +--------------------------------------------+"
echo "  |   SpatchEx Long-Run Test -- Setup Start    |"
echo "  +--------------------------------------------+"
echo ""

# ── 1. Homebrew ───────────────────────────────────────────────────────────────
step "Checking Homebrew"
if ! command -v brew &>/dev/null; then
  echo "  Installing Homebrew (may require admin password)..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Apple Silicon / Intel PATH
eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null || true)"
ok "Homebrew $(brew --version | head -1)"

# ── 2. Git ────────────────────────────────────────────────────────────────────
step "Checking Git"
if ! command -v git &>/dev/null; then
  brew install git
fi
ok "Git $(git --version)"

# ── 3. Download code ──────────────────────────────────────────────────────────
step "Downloading code"
if [ -d "$INSTALL_DIR/.git" ]; then
  echo "  Already installed -- updating to latest..."
  git -C "$INSTALL_DIR" pull --ff-only
  ok "Updated ($INSTALL_DIR)"
else
  git clone "$REPO_URL" "$INSTALL_DIR"
  ok "Downloaded ($INSTALL_DIR)"
fi

# ── 4. Install dependencies (delegated to install.sh) ─────────────────────────
step "Installing dependencies (Python / Node.js / ADB / Appium)"
bash "$INSTALL_DIR/install.sh"

# ── 5. Launch web UI ─────────────────────────────────────────────────────────
echo ""
echo "  +--------------------------------------------+"
echo "  |   Setup complete! Launching Test UI...     |"
echo "  +--------------------------------------------+"
echo ""
bash "$INSTALL_DIR/start.sh"
