#!/usr/bin/env bash
# ┌─────────────────────────────────────────────────────────┐
# │  SpatchEx 자동화 툴 — Mac 실행                          │
# │  이 파일을 더블클릭하면 테스트 UI가 브라우저에 열립니다 │
# └─────────────────────────────────────────────────────────┘
set -e
cd "$(dirname "$0")"

RED='\033[0;31m'; NC='\033[0m'
err() { echo -e "${RED}  ✗ 오류: $1${NC}"; read -p "  Enter를 눌러 창을 닫으세요..."; exit 1; }

# 가상환경 확인
if [ ! -f ".venv/bin/activate" ]; then
  err "설치가 완료되지 않았습니다. install.command를 먼저 실행하세요."
fi

source .venv/bin/activate

# Flask 확인
python -c "import flask" 2>/dev/null || pip install flask -q

echo ""
echo "  S-Patch EX 장기 실행 테스트 UI 시작 중..."
echo "  브라우저가 자동으로 열립니다 → http://127.0.0.1:5001"
echo ""
echo "  테스트를 중지하려면 이 창을 닫으세요."
echo ""

python web/app.py
