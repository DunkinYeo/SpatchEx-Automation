#!/usr/bin/env bash
# SpatchEx Long-Run Test -- Mac start script
# Usage: double-click or run ./start.sh in terminal

set -e
cd "$(dirname "$0")"

if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
else
  echo "[ERROR] Virtual environment (.venv) not found."
  echo "        Run install.sh first:"
  echo "        bash install.sh"
  read -p "Press Enter to exit..."
  exit 1
fi

python -c "import flask" 2>/dev/null || pip install flask -q

echo ""
echo "  Starting SpatchEx Test UI..."
echo "  Browser will open -> http://127.0.0.1:5001"
echo ""
echo "  Press Ctrl+C in this window to stop."
echo ""

open "http://127.0.0.1:5001"

python web/app.py
