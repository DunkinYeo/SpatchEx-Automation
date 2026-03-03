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

:err
  echo.
  echo   ============================================================
  echo   ERROR: %~1
  echo   ============================================================
  echo.
  pause
  exit /b 1

:main

REM ── 1. Python ────────────────────────────────────────────────────────────────
echo [1/5] Checking Python...
python --version >nul 2>&1
if not errorlevel 1 (
  for /f "tokens=*" %%i in ('python --version') do echo   OK  %%i
  GOTO :check_node
)

echo   Python not found. Installing via winget (this may take a few minutes)...
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
  echo   Python installed but PATH not yet updated.
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

echo   Node.js not found. Installing via winget...
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
if errorlevel 1 (
  echo.
  echo   Auto-install failed. Please install Node.js manually:
  echo   https://nodejs.org/
  start https://nodejs.org/
  echo   After installing Node.js, close this window and re-run install.bat
  pause
  exit /b 1
)
call :refresh_path
node --version >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Node.js installed but PATH not yet updated.
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
  echo.
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
  GOTO :check_uiautomator
)

echo   Installing Appium via npm (this may take a few minutes)...
npm install -g appium
if errorlevel 1 (
  echo.
  echo   ERROR: npm install -g appium failed.
  echo   Make sure Node.js is properly installed and try again.
  pause
  exit /b 1
)
call :refresh_path
appium --version >nul 2>&1
if errorlevel 1 (
  echo.
  echo   Appium installed but PATH not yet updated.
  echo   Please CLOSE this window and RE-RUN install.bat
  pause
  exit /b 0
)
echo   OK  Appium installed

:check_uiautomator
appium driver list --installed 2>nul | findstr /i "uiautomator2" >nul
if not errorlevel 1 (
  echo   OK  UiAutomator2 already installed
  GOTO :python_packages
)

echo   Installing UiAutomator2 driver...
appium driver install uiautomator2
if errorlevel 1 (
  echo.
  echo   ERROR: Failed to install UiAutomator2 driver.
  echo   Try running: appium driver install uiautomator2
  pause
  exit /b 1
)
echo   OK  UiAutomator2 installed

:python_packages
REM ── 5. Python virtual environment ────────────────────────────────────────────
echo.
echo [5/5] Setting up Python packages...
if not exist ".venv" (
  python -m venv .venv
  if errorlevel 1 (
    echo   ERROR: Failed to create virtual environment.
    pause
    exit /b 1
  )
)
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q
if errorlevel 1 (
  echo   ERROR: Failed to install Python packages.
  pause
  exit /b 1
)
echo   OK  Packages installed

REM ── Done ────────────────────────────────────────────────────────────────────
echo.
echo   +--------------------------------------------------+
echo   ^|  Setup complete!                                ^|
echo   +--------------------------------------------------+
echo.
echo   Next steps:
echo   1. Connect your Android phone via USB
echo   2. Double-click start.bat -^> browser opens automatically
echo.
pause
