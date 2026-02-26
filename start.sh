#!/usr/bin/env bash
# SpatchEx 장기 실행 테스트 — Mac 실행 스크립트
# 사용법: 이 파일을 더블클릭하거나 터미널에서 ./start.sh 실행

set -e
cd "$(dirname "$0")"

# 가상환경 활성화
if [ -f ".venv/bin/activate" ]; then
  source .venv/bin/activate
else
  echo "[오류] 가상환경(.venv)을 찾을 수 없습니다."
  echo "       프로젝트 루트에서 다음 명령을 먼저 실행하세요:"
  echo "       python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt"
  read -p "계속하려면 Enter를 누르세요..."
  exit 1
fi

# Flask 설치 확인
python -c "import flask" 2>/dev/null || pip install flask -q

echo ""
echo "  S-Patch EX 장기 실행 테스트 UI 시작 중..."
echo "  브라우저가 자동으로 열립니다 → http://127.0.0.1:5001"
echo ""
echo "  종료하려면 이 창에서 Ctrl+C 를 누르세요."
echo ""

python web/app.py
