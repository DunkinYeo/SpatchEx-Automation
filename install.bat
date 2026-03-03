@echo off
cd /d "%~dp0"

echo.
echo   +--------------------------------------+
echo   |  SpatchEx Long-Run Test -- Setup     |
echo   +--------------------------------------+
echo.

REM ── 1. Python ────────────────────────────────────────────────────────────────
echo [1/5] Checking Python...
python --version >nul 2>&1
if errorlevel 1 (
  echo   Python is not installed.
  echo   Please install Python 3.10 or later from:
  echo   https://www.python.org/downloads/
  echo   IMPORTANT: check "Add Python to PATH" during install!
  start https://www.python.org/downloads/
  pause
  exit /b 1
) else (
  for /f "tokens=*" %%i in ('python --version') do echo   OK  %%i
)

REM ── 2. Node.js ───────────────────────────────────────────────────────────────
echo.
echo [2/5] Checking Node.js...
node --version >nul 2>&1
if errorlevel 1 (
  echo   Node.js is not installed.
  echo   Please install Node.js LTS from:
  echo   https://nodejs.org/
  start https://nodejs.org/
  echo   Re-run this script after installing.
  pause
  exit /b 1
) else (
  for /f "tokens=*" %%i in ('node --version') do echo   OK  Node.js %%i
)

REM ── 3. ADB ───────────────────────────────────────────────────────────────────
echo.
echo [3/5] Checking ADB...
adb --version >nul 2>&1
if errorlevel 1 (
  echo   Installing Android Platform Tools...
  winget install Google.PlatformTools >nul 2>&1
  if errorlevel 1 (
    echo   Auto-install failed. Please install manually from:
    echo   https://developer.android.com/tools/releases/platform-tools
    start https://developer.android.com/tools/releases/platform-tools
    pause
    exit /b 1
  )
  echo   OK  ADB installed (restart terminal if adb is not found)
) else (
  echo   OK  ADB already installed
)

REM ── 4. Appium ────────────────────────────────────────────────────────────────
echo.
echo [4/5] Installing Appium...
appium --version >nul 2>&1
if errorlevel 1 (
  npm install -g appium
  echo   OK  Appium installed
) else (
  for /f "tokens=*" %%i in ('appium --version') do echo   OK  Appium %%i
)

appium driver list --installed 2>nul | findstr "uiautomator2" >nul
if errorlevel 1 (
  echo   Installing UiAutomator2 driver...
  appium driver install uiautomator2
  echo   OK  UiAutomator2 installed
) else (
  echo   OK  UiAutomator2 already installed
)

REM ── 5. Python virtual environment ────────────────────────────────────────────
echo.
echo [5/5] Setting up Python packages...
if not exist ".venv" (
  python -m venv .venv
)
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q
echo   OK  Packages installed

REM ── Done ────────────────────────────────────────────────────────────────────
echo.
echo   +--------------------------------------+
echo   |        Setup complete!               |
echo   +--------------------------------------+
echo.
echo   Next steps:
echo   1. Connect your Android phone via USB or pair via WiFi
echo   2. Run start.bat -^> browser opens automatically
echo.
pause
