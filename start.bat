@echo off
chcp 65001 >nul
REM SpatchEx 장기 실행 테스트 — Windows 실행 스크립트
REM 사용법: 이 파일을 더블클릭하세요

cd /d "%~dp0"

REM 가상환경 활성화
if exist ".venv\Scripts\activate.bat" (
  call .venv\Scripts\activate.bat
) else (
  echo [오류] 가상환경(.venv)을 찾을 수 없습니다.
  echo        프로젝트 루트에서 다음 명령을 먼저 실행하세요:
  echo        python -m venv .venv
  echo        .venv\Scripts\activate.bat
  echo        pip install -r requirements.txt
  pause
  exit /b 1
)

REM Flask 설치 확인
python -c "import flask" 2>nul || pip install flask -q

echo.
echo   S-Patch EX 장기 실행 테스트 UI 시작 중...
echo   브라우저가 자동으로 열립니다 -^> http://127.0.0.1:5001
echo.
echo   종료하려면 이 창을 닫으세요.
echo.

python web\app.py
pause
