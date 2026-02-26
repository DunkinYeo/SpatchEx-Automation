@echo off
chcp 65001 >nul
REM SpatchEx 자동화 툴 — Windows 최초 설치 스크립트
REM 실행: install.bat 더블클릭 (관리자 권한 권장)

cd /d "%~dp0"

echo.
echo   ╔══════════════════════════════════════╗
echo   ║  SpatchEx 장기 실행 테스트 — 설치   ║
echo   ╚══════════════════════════════════════╝
echo.

REM ── 1. Python ────────────────────────────────────────────────────────────────
echo [1/5] Python 확인 중...
python --version >nul 2>&1
if errorlevel 1 (
  echo   Python이 설치되지 않았습니다.
  echo   아래 링크에서 Python 3.10 이상을 설치하세요:
  echo   https://www.python.org/downloads/
  echo   설치 시 "Add Python to PATH" 반드시 체크!
  start https://www.python.org/downloads/
  pause
  exit /b 1
) else (
  for /f "tokens=*" %%i in ('python --version') do echo   ✓ %%i
)

REM ── 2. Node.js ───────────────────────────────────────────────────────────────
echo.
echo [2/5] Node.js 확인 중...
node --version >nul 2>&1
if errorlevel 1 (
  echo   Node.js가 설치되지 않았습니다.
  echo   아래 링크에서 Node.js LTS를 설치하세요:
  echo   https://nodejs.org/
  start https://nodejs.org/
  echo   설치 후 이 스크립트를 다시 실행하세요.
  pause
  exit /b 1
) else (
  for /f "tokens=*" %%i in ('node --version') do echo   ✓ Node.js %%i
)

REM ── 3. ADB ───────────────────────────────────────────────────────────────────
echo.
echo [3/5] ADB 확인 중...
adb --version >nul 2>&1
if errorlevel 1 (
  echo   ADB(Android 연결 도구)를 설치합니다...
  REM winget으로 설치 시도
  winget install Google.PlatformTools >nul 2>&1
  if errorlevel 1 (
    echo   자동 설치 실패. 아래 링크에서 수동으로 설치하세요:
    echo   https://developer.android.com/tools/releases/platform-tools
    start https://developer.android.com/tools/releases/platform-tools
    pause
    exit /b 1
  )
  echo   ✓ ADB 설치 완료 (터미널 재시작 필요할 수 있음)
) else (
  echo   ✓ ADB 이미 설치됨
)

REM ── 4. Appium ────────────────────────────────────────────────────────────────
echo.
echo [4/5] Appium 설치 중...
appium --version >nul 2>&1
if errorlevel 1 (
  npm install -g appium
  echo   ✓ Appium 설치 완료
) else (
  for /f "tokens=*" %%i in ('appium --version') do echo   ✓ Appium %%i
)

appium driver list --installed 2>nul | findstr "uiautomator2" >nul
if errorlevel 1 (
  echo   UiAutomator2 드라이버 설치 중...
  appium driver install uiautomator2
  echo   ✓ UiAutomator2 설치 완료
) else (
  echo   ✓ UiAutomator2 이미 설치됨
)

REM ── 5. Python 가상환경 ───────────────────────────────────────────────────────
echo.
echo [5/5] Python 패키지 설정 중...
if not exist ".venv" (
  python -m venv .venv
)
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q
echo   ✓ 패키지 설치 완료

REM ── 완료 ────────────────────────────────────────────────────────────────────
echo.
echo   ╔══════════════════════════════════════╗
echo   ║        설치가 완료되었습니다! ^^      ║
echo   ╚══════════════════════════════════════╝
echo.
echo   다음 단계:
echo   1. 안드로이드 폰을 USB로 연결하거나 WiFi로 페어링
echo   2. start.bat 실행 -^> 브라우저에서 테스트 시작
echo.
pause
