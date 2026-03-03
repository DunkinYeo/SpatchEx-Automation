#!/usr/bin/env bash
# SpatchEx — Mac 실행 파일
# 더블클릭하면 터미널이 열리며 자동으로 설치 후 시작됩니다.
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  echo ""
  echo "  처음 실행입니다. 필요한 도구를 설치합니다 (5~15분 소요)..."
  echo ""
  bash install.sh
fi

bash start.sh
