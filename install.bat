@echo off
cd /d "%~dp0"
setlocal enabledelayedexpansion

echo.
echo   +--------------------------------------------------+
echo   ^|  SpatchEx Long-Run Test -- Setup                ^|
echo   ^|  This may take 10-20 minutes on first run       ^|
echo   +--------------------------------------------------+
echo.

REM ── Helper: refresh PATH from Windows registry ────────────────────────────
GOTO :main

:refresh_path
  for /f "usebackq tokens=*" %%i in (`powershell -NoProfile -Command "[System.Environment]::GetEnvironmentVariable('Path','Machine')+';'+[System.Environment]::GetEnvironmentVariable('Path','User')"`) do (
    set "PATH=%%i"
  )
GOTO :EOF

:main

REM ── 1. Python ────────────────────────────────────────────────────────────────
echo [1/5] Checking Python...
python --version >nul 2>&1
if not errorlevel 1 (
  for /f "tokens=*" %%i in ('python --version') do echo   OK  %%i
  GOTO :check_node
)

echo   Python not found. Installing automatically (winget)...
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
  echo.
  echo   Auto-install failed. Please install Python manually:
  echo   https://www.python.org/downloads/
  echo   IMPORTANT: check "Add Python to PATH" during install!
  start https://www.python.org/downloads/
  echo.
  echo   After installing Python, close this window and re-run install.bat
  pause
  exit /b 1
)
call :refresh_path
python --version >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Python installed. PATH not yet updated.
  echo   Please CLOSE this window and RE-RUN install.bat
  pause
  exit /b 0
)
for /f "tokens=*" %%i in ('python --version') do echo   OK  %%i

:check_node
REM ── 2. Node.js ───────────────────────────────────────────────────────────────
echo.
echo [2/5] Checking Node.js...
node --version >nul 2>&1
if not errorlevel 1 (
  for /f "tokens=*" %%i in ('node --version') do echo   OK  Node.js %%i
  GOTO :check_adb
)

echo   Node.js not found. Installing automatically (winget)...
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
  echo.
  echo   Auto-install failed. Please install Node.js manually:
  echo   https://nodejs.org/
  start https://nodejs.org/
  echo.
  echo   After installing Node.js, close this window and re-run install.bat
  pause
  exit /b 1
)
call :refresh_path
node --version >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Node.js installed. PATH not yet updated.
  echo   Please CLOSE this window and RE-RUN install.bat
  pause
  exit /b 0
)
for /f "tokens=*" %%i in ('node --version') do echo   OK  Node.js %%i

:check_adb
REM ── 3. ADB ───────────────────────────────────────────────────────────────────
echo.
echo [3/5] Checking ADB...
adb --version >nul 2>&1
if not errorlevel 1 (
  echo   OK  ADB already installed
  GOTO :check_appium
)

echo   ADB not found. Installing Android Platform Tools (winget)...
winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
  echo   Auto-install failed. Please install manually:
  echo   https://developer.android.com/tools/releases/platform-tools
  start https://developer.android.com/tools/releases/platform-tools
  pause
  exit /b 1
)
call :refresh_path
echo   OK  ADB installed

:check_appium
REM ── 4. Appium ────────────────────────────────────────────────────────────────
echo.
echo [4/5] Installing Appium...
appium --version >nul 2>&1
if not errorlevel 1 (
  for /f "tokens=*" %%i in ('appium --version') do echo   OK  Appium %%i
) else (
  npm install -g appium
  echo   OK  Appium installed
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
echo   +--------------------------------------------------+
echo   ^|  Setup complete!                                ^|
echo   +--------------------------------------------------+
echo.
echo   Next steps:
echo   1. Connect your Android phone via USB or pair via WiFi
echo   2. Run start.bat -^> browser opens automatically
echo.
pause
