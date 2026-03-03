#!/usr/bin/env bash
# SpatchEx -- Mac launcher (double-click to run)
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo ""
  echo "  First run detected. Installing required tools (5-15 min)..."
  echo ""
  bash install.sh
fi

bash start.sh
