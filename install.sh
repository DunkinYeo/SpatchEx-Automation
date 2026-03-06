#!/bin/bash
# ============================================================
# SpatchEx -- First-Time Setup (macOS / Linux)
# install.sh  (project root)
#
#  Run from Terminal: ./install.sh
#  All setup logic lives in scripts/setup_env.sh.
# ============================================================

cd "$(dirname "$0")" || { echo "ERROR: Cannot change to script directory."; exit 1; }

bash scripts/setup_env.sh
STATUS=$?

read -r -p "  Press Enter to close... " _
exit $STATUS
