#!/usr/bin/env bash
# SpatchEx -- Mac launcher (double-click to run)
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo ""
  echo "  First run detected. Installing required tools..."
  echo ""
  bash install.sh
fi

bash start.sh
