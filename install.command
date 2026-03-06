#!/bin/bash
# ============================================================
# SpatchEx -- First-Time Setup (macOS, Finder double-click)
# install.command  (project root)
#
#  Double-click in Finder, or run from Terminal.
#  All setup logic lives in scripts/setup_env.sh.
# ============================================================

# Ensure executable (after ZIP extraction)
chmod +x "$0" 2>/dev/null || true

# Change to script directory
cd "$(dirname "$0")" || { echo "ERROR: Cannot change to script directory."; read -r _; exit 1; }

bash scripts/setup_env.sh
STATUS=$?

read -r -p "  Press Enter to close... " _
exit $STATUS
