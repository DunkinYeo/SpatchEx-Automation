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
echo [4/5] Checking Appium...

REM Ensure Node.js and npm global bin are always in PATH
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

REM Verify npm is available before trying to install
npm --version >nul 2>&1
IF ERRORLEVEL 1 (
  echo   ERROR: npm not found. Please close and re-run install.bat
  GOTO :done
)

REM Use appium -v (not --version) — Appium 3.x only supports -v
appium -v >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :appium_ok

echo   Appium not found. Installing via npm (3-5 min)...
npm i --location=global appium
SET APPIUM_ERR=%ERRORLEVEL%
IF %APPIUM_ERR%==0 GOTO :appium_ok
echo.
echo   ERROR: npm i --location=global appium failed. (exit code %APPIUM_ERR%)
echo   Please run install.bat as Administrator and retry.
SET SETUP_FAILED=1
GOTO :done

:appium_ok
FOR /F "tokens=*" %%i IN ('appium -v 2^>nul') DO echo   OK  Appium %%i

REM ── 5. UiAutomator2 driver ───────────────────────────────────────────────────
echo.
echo [5/5] Checking UiAutomator2 driver...
SET "DRIVER_TMP=%TEMP%\appium_drivers.txt"
appium driver list --installed > "%DRIVER_TMP%" 2>&1
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :uia2_ok

echo   UiAutomator2 not installed. Installing now...
appium driver install uiautomator2
SET UIA2_ERR=%ERRORLEVEL%
IF %UIA2_ERR%==0 GOTO :uia2_ok
echo.
echo   ERROR: Failed to install UiAutomator2 driver. (exit code %UIA2_ERR%)
echo   Please run install.bat as Administrator and retry.
SET SETUP_FAILED=1
GOTO :done

:uia2_ok
echo   OK  UiAutomator2 installed
echo   Installed drivers:
appium driver list

REM ── Python virtual environment (post-setup) ──────────────────────────────────
echo.
echo   Setting up Python packages...
IF EXIST ".venv" GOTO :venv_ok
python -m venv .venv
IF NOT ERRORLEVEL 1 GOTO :venv_ok
echo   ERROR: Failed to create virtual environment.
SET SETUP_FAILED=1
GOTO :done

:venv_ok
call .venv\Scripts\activate.bat
pip install -r requirements.txt -q
IF NOT ERRORLEVEL 1 GOTO :pip_ok
echo   ERROR: Failed to install Python packages.
SET SETUP_FAILED=1
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
IF "%SETUP_FAILED%"=="1" (
  echo   Setup did not complete successfully. See errors above.
)
echo   Press any key to close this window...
pause >nul
IF "%SETUP_FAILED%"=="1" EXIT /B 1
