#!/bin/bash
# ============================================================
# SpatchEx -- First-Time Setup (macOS)
# ============================================================

chmod +x "$0" 2>/dev/null || true

cd "$(dirname "$0")" || {
  echo "ERROR: Cannot change to script directory."
  read -r _
  exit 1
}

# Bootstrap PATH so Homebrew tools (python3, node, npm, adb, appium)
# are reachable when launched from Finder (non-login shell).
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:$PATH"

# Ensure setup script executable
chmod +x scripts/setup_env.sh 2>/dev/null

echo ""
echo "Running setup script..."
echo ""

bash scripts/setup_env.sh
STATUS=$?

echo ""
read -r -p "Press Enter to close... " _
exit $STATUS
