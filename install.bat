@echo off
REM Keep window open always — re-launch inside cmd /k if not already
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
IF NOT ERRORLEVEL 1 GOTO :python_ok

echo   Python not found. Installing via winget...
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements
IF NOT ERRORLEVEL 1 GOTO :python_rerun
echo.
echo   ERROR: Could not auto-install Python.
echo   Please install manually: https://www.python.org/downloads/
echo   IMPORTANT: check "Add Python to PATH" during install
start https://www.python.org/downloads/
GOTO :done

:python_rerun
echo   Python installed. Please CLOSE and RE-RUN install.bat
GOTO :done

:python_ok
FOR /F "tokens=*" %%i IN ('python --version') DO echo   OK  %%i

REM ── 2. Node.js ───────────────────────────────────────────────────────────────
echo.
echo [2/5] Checking Node.js...
node --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :node_ok

echo   Node.js not found. Installing via winget...
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements
IF NOT ERRORLEVEL 1 GOTO :node_rerun
echo.
echo   ERROR: Could not auto-install Node.js.
echo   Please install manually: https://nodejs.org/
start https://nodejs.org/
GOTO :done

:node_rerun
echo   Node.js installed. Please CLOSE and RE-RUN install.bat
GOTO :done

:node_ok
FOR /F "tokens=*" %%i IN ('node --version') DO echo   OK  Node.js %%i

REM ── 3. ADB ───────────────────────────────────────────────────────────────────
echo.
echo [3/5] Checking ADB...
adb --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :adb_ok

echo   ADB not found. Installing Android Platform Tools (winget)...
winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements
IF NOT ERRORLEVEL 1 GOTO :adb_rerun
echo.
echo   ERROR: Could not auto-install ADB.
echo   Please install manually:
echo   https://developer.android.com/tools/releases/platform-tools
start https://developer.android.com/tools/releases/platform-tools
GOTO :done

:adb_rerun
echo   ADB installed. Please CLOSE and RE-RUN install.bat
GOTO :done

:adb_ok
echo   OK  ADB ready

REM ── 4. Appium ────────────────────────────────────────────────────────────────
echo.
echo [4/5] Installing Appium...
appium --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :appium_ok

echo   Installing Appium via npm. Please wait...
npm install -g appium
IF NOT ERRORLEVEL 1 GOTO :appium_ok
echo.
echo   ERROR: npm install -g appium failed.
echo   Make sure Node.js is properly installed and try again.
GOTO :done

:appium_ok
echo   OK  Appium ready

echo   Checking UiAutomator2 driver...
appium driver list --installed 2>nul | findstr /i "uiautomator2" >nul
IF NOT ERRORLEVEL 1 GOTO :uia2_ok

echo   Installing UiAutomator2 driver...
appium driver install uiautomator2
IF NOT ERRORLEVEL 1 GOTO :uia2_ok
echo.
echo   ERROR: Failed to install UiAutomator2 driver.
echo   Try running: appium driver install uiautomator2
GOTO :done

:uia2_ok
echo   OK  UiAutomator2 ready

REM ── 5. Python virtual environment ────────────────────────────────────────────
echo.
echo [5/5] Setting up Python packages...
IF EXIST ".venv" GOTO :venv_ok
python -m venv .venv
IF NOT ERRORLEVEL 1 GOTO :venv_ok
echo   ERROR: Failed to create virtual environment.
GOTO :done

:venv_ok
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q
IF NOT ERRORLEVEL 1 GOTO :pip_ok
echo   ERROR: Failed to install Python packages.
GOTO :done

:pip_ok
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
