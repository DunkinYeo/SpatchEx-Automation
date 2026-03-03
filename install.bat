@echo off
REM Keep window open always — re-launch with cmd /k if not already inside it
IF "%SPATCHEX_RUNNING%"=="1" GOTO :run
SET SPATCHEX_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0"

echo.
echo   +--------------------------------------------------+
echo   ^|  SpatchEx Long-Run Test -- Setup                ^|
echo   ^|  This may take 10-20 minutes on first run       ^|
echo   +--------------------------------------------------+
echo.

REM ── 1. Python ────────────────────────────────────────────────────────────────
echo [1/5] Checking Python...
python --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo   Python not found. Installing via winget...
  winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
  IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ERROR: Could not auto-install Python.
    echo   Please install manually: https://www.python.org/downloads/
    echo   IMPORTANT: check "Add Python to PATH" during install
    start https://www.python.org/downloads/
    echo.
    echo   After installing, close this window and re-run install.bat
    GOTO :done
  )
  echo   Python installed. Please CLOSE and RE-RUN install.bat
  GOTO :done
)
FOR /F "tokens=*" %%i IN ('python --version') DO echo   OK  %%i

REM ── 2. Node.js ───────────────────────────────────────────────────────────────
echo.
echo [2/5] Checking Node.js...
node --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo   Node.js not found. Installing via winget...
  winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
  IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ERROR: Could not auto-install Node.js.
    echo   Please install manually: https://nodejs.org/
    start https://nodejs.org/
    echo.
    echo   After installing, close this window and re-run install.bat
    GOTO :done
  )
  echo   Node.js installed. Please CLOSE and RE-RUN install.bat
  GOTO :done
)
FOR /F "tokens=*" %%i IN ('node --version') DO echo   OK  Node.js %%i

REM ── 3. ADB ───────────────────────────────────────────────────────────────────
echo.
echo [3/5] Checking ADB...
adb --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo   ADB not found. Installing Android Platform Tools (winget)...
  winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements
  IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ERROR: Could not auto-install ADB.
    echo   https://developer.android.com/tools/releases/platform-tools
    start https://developer.android.com/tools/releases/platform-tools
    GOTO :done
  )
  echo   ADB installed. Please CLOSE and RE-RUN install.bat
  GOTO :done
)
echo   OK  ADB already installed

REM ── 4. Appium ────────────────────────────────────────────────────────────────
echo.
echo [4/5] Installing Appium...
appium --version >nul 2>&1
IF %ERRORLEVEL% NEQ 0 (
  echo   Installing Appium via npm. Please wait...
  npm install -g appium
  IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ERROR: npm install -g appium failed.
    echo   Make sure Node.js is properly installed and try again.
    GOTO :done
  )
  echo   OK  Appium installed
)

echo   Checking UiAutomator2 driver...
appium driver list --installed 2>nul | findstr /i "uiautomator2" >nul
IF %ERRORLEVEL% NEQ 0 (
  echo   Installing UiAutomator2 driver...
  appium driver install uiautomator2
  IF %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ERROR: Failed to install UiAutomator2 driver.
    echo   Try running manually: appium driver install uiautomator2
    GOTO :done
  )
  echo   OK  UiAutomator2 installed
) ELSE (
  echo   OK  UiAutomator2 already installed
)

REM ── 5. Python virtual environment ────────────────────────────────────────────
echo.
echo [5/5] Setting up Python packages...
IF NOT EXIST ".venv" (
  python -m venv .venv
  IF %ERRORLEVEL% NEQ 0 (
    echo   ERROR: Failed to create virtual environment.
    GOTO :done
  )
)
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q
IF %ERRORLEVEL% NEQ 0 (
  echo   ERROR: Failed to install Python packages.
  GOTO :done
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

:done
echo.
echo   Press any key to close this window...
pause >nul
