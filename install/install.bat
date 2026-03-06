@echo off
REM ============================================================
REM SpatchEx Long-Run Test -- Developer / Admin Setup
REM install\install.bat
REM
REM  !! THIS FILE IS FOR DEVELOPERS AND IT ADMINS ONLY !!
REM  CS/UAT staff: do NOT run this file.
REM  CS/UAT staff: double-click start.bat (or run.bat) instead.
REM
REM  Purpose: Install or refresh the global Python/Node/Appium
REM  tools that the test runner depends on.
REM  Run this once per machine, or when dependencies need updating.
REM ============================================================
REM Keep window open: re-launch inside cmd /k on direct double-click
IF "%SPATCHEX_RUNNING%"=="1" GOTO :run
SET SPATCHEX_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0.."

REM ── Timestamped log in TEMP ──────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_install_%_TS%.log"
echo SpatchEx install started %DATE% %TIME% > "%LOG%"

REM ── PATH: always include Node.js + npm global bin ────────────
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
SET "NPM_CMD=%ProgramFiles%\nodejs\npm.cmd"
SET "APPIUM_CMD=%APPDATA%\npm\appium.cmd"

SET SETUP_FAILED=0
SET APPIUM_RUN=

REM ── Banner ────────────────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   SpatchEx -- Developer / Admin Setup             ^|
echo   +====================================================+
echo.
echo   NOTE: This file is for IT admins and developers only.
echo   CS/UAT staff: close this window and double-click start.bat instead.
echo.
echo   Log: %LOG%
echo.

REM ============================================================
REM [1/6] Python
REM ============================================================
echo [1/6] Python...
echo [1/6] Python >> "%LOG%"

python --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :python_missing
FOR /F "tokens=*" %%v IN ('python --version 2^>^&1') DO echo   OK  %%v
echo [1/6] OK >> "%LOG%"
GOTO :step2

:python_missing
echo   Not found. Installing Python 3.12 via winget...
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :python_fail
echo   Installed. CLOSE this window and RE-RUN install.bat.
GOTO :done

:python_fail
echo.
echo   ERROR: Python not found and auto-install failed.
echo   Download: https://www.python.org/downloads/
echo   IMPORTANT: Check "Add Python to PATH" during install.
start https://www.python.org/downloads/
SET SETUP_FAILED=1
GOTO :done

REM ============================================================
REM [2/6] Node.js / npm
REM ============================================================
:step2
echo.
echo [2/6] Node.js / npm...
echo [2/6] Node.js >> "%LOG%"

node --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :node_missing
FOR /F "tokens=*" %%v IN ('node --version 2^>^&1') DO echo   OK  Node.js %%v
GOTO :npm_check

:node_missing
echo   Not found. Installing Node.js LTS via winget...
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :node_fail
echo   Installed. CLOSE this window and RE-RUN install.bat.
GOTO :done

:node_fail
echo.
echo   ERROR: Node.js not found and auto-install failed.
echo   Download: https://nodejs.org/
start https://nodejs.org/
SET SETUP_FAILED=1
GOTO :done

:npm_check
IF EXIST "%NPM_CMD%" GOTO :step2_ok
npm --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :npm_fail
GOTO :step2_ok

:npm_fail
echo   ERROR: npm not found. Close this window and re-run install.bat.
SET SETUP_FAILED=1
GOTO :done

:step2_ok
echo [2/6] OK >> "%LOG%"

REM ============================================================
REM [3/6] ADB (Android Debug Bridge)
REM ============================================================
echo.
echo [3/6] ADB (Android Debug Bridge)...
echo [3/6] ADB >> "%LOG%"

adb --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :adb_missing
echo   OK  ADB ready
echo [3/6] OK >> "%LOG%"
GOTO :step4

:adb_missing
echo   Not found. Installing Android Platform Tools via winget...
winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :adb_fail
echo   Installed. CLOSE this window and RE-RUN install.bat.
GOTO :done

:adb_fail
echo.
echo   ERROR: ADB not found and auto-install failed.
echo   Download: https://developer.android.com/tools/releases/platform-tools
start https://developer.android.com/tools/releases/platform-tools
SET SETUP_FAILED=1
GOTO :done

REM ============================================================
REM [4/6] Appium
REM   Priority: global appium.cmd -> PATH appium -> npm install -> npx
REM   APPIUM_RUN is always "appium" (global) or "npx -y appium@3" (fallback)
REM   Never stored as full path — avoids space/quoting issues downstream
REM ============================================================
:step4
echo.
echo [4/6] Appium...
echo [4/6] Appium >> "%LOG%"
SET APPIUM_RUN=

REM 4a. Check %APPDATA%\npm\appium.cmd (most reliable on Windows)
IF NOT EXIST "%APPIUM_CMD%" GOTO :chk_path_appium
echo   Found: %APPIUM_CMD% >> "%LOG%"
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :chk_path_appium
SET APPIUM_RUN=appium
GOTO :appium_found

REM 4b. Check PATH-based appium
:chk_path_appium
call appium -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :appium_install
SET APPIUM_RUN=appium
GOTO :appium_found

REM 4c. Install globally via npm (output on console — not redirected to log)
:appium_install
echo   Not found. Installing via npm (this can take a few minutes)...
echo npm i --location=global appium >> "%LOG%"
IF EXIST "%NPM_CMD%" (
  call "%NPM_CMD%" i --location=global appium
) ELSE (
  call npm i --location=global appium
)
echo npm exit=%ERRORLEVEL% >> "%LOG%"

REM 4d. Re-check after npm install (explicit path first, then PATH)
IF NOT EXIST "%APPIUM_CMD%" GOTO :rechk_path
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :rechk_path
SET APPIUM_RUN=appium
GOTO :appium_found

:rechk_path
call appium -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :appium_npx
SET APPIUM_RUN=appium
GOTO :appium_found

REM 4e. npx fallback (console output shown — first run downloads appium, ~1 min)
:appium_npx
echo   Global install unavailable. Trying npx fallback...
echo   (First run downloads appium — please wait, do not close this window)
SET "APPIUM_RUN=npx -y appium@3"
call npx -y appium@3 -v
IF ERRORLEVEL 1 GOTO :appium_fail
echo   OK  Appium ready (via npx)
GOTO :step4_done

:appium_fail
echo.
echo   ERROR: Appium could not be installed or started.
echo   See log: %LOG%
echo FAIL: Appium not available >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done_tail

:appium_found
call appium -v
:step4_done
echo [4/6] APPIUM_RUN=%APPIUM_RUN% >> "%LOG%"

REM ============================================================
REM [5/6] UiAutomator2 driver
REM   Uses %APPIUM_RUN% which is always "appium" or "npx -y appium@3"
REM   Correct commands: "appium driver list --installed"
REM                     "appium driver install uiautomator2"
REM ============================================================
echo.
echo [5/6] UiAutomator2 driver...
echo [5/6] UiAutomator2 >> "%LOG%"

REM Guard: APPIUM_RUN must be set before we reach here
IF "%APPIUM_RUN%"=="" GOTO :uia2_no_appium

SET "DRIVER_TMP=%TEMP%\appium_drivers_%_TS%.txt"

echo   Checking installed drivers...
call %APPIUM_RUN% driver list --installed > "%DRIVER_TMP%" 2>&1
type "%DRIVER_TMP%"
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF ERRORLEVEL 1 GOTO :uia2_install
GOTO :uia2_ok

:uia2_install
echo   Not installed. Installing uiautomator2 (this can take a few minutes)...
call %APPIUM_RUN% driver install uiautomator2
SET UIA2_ERR=%ERRORLEVEL%
echo driver install uiautomator2 exit=%UIA2_ERR% >> "%LOG%"
IF ERRORLEVEL 1 GOTO :uia2_fail
GOTO :uia2_ok

:uia2_no_appium
echo.
echo   ERROR: Appium not available — cannot install UiAutomator2 driver.
echo   See log: %LOG%
SET SETUP_FAILED=1
GOTO :done_tail

:uia2_fail
echo.
echo   ERROR: UiAutomator2 install failed (exit %UIA2_ERR%).
echo   If you see permission errors, try running as Administrator.
echo   See log: %LOG%
SET SETUP_FAILED=1
GOTO :done_tail

:uia2_ok
echo   OK  UiAutomator2 driver installed
echo [5/6] OK >> "%LOG%"

REM ============================================================
REM [6/6] Python virtual environment + packages
REM ============================================================
echo.
echo [6/6] Python packages...
echo [6/6] Python packages >> "%LOG%"

IF EXIST ".venv" GOTO :venv_ready
echo   Creating virtual environment...
python -m venv .venv >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :venv_fail
GOTO :venv_ready

:venv_fail
echo   ERROR: Failed to create .venv. See log: %LOG%
SET SETUP_FAILED=1
GOTO :done_tail

:venv_ready
call .venv\Scripts\activate.bat
echo   Installing requirements...
pip install -r requirements.txt
SET PIP_ERR=%ERRORLEVEL%
echo pip install exit=%PIP_ERR% >> "%LOG%"
IF ERRORLEVEL 1 GOTO :pip_fail
GOTO :pip_ok

:pip_fail
echo   ERROR: pip install failed (exit %PIP_ERR%). See log: %LOG%
SET SETUP_FAILED=1
GOTO :done_tail

:pip_ok
echo   OK  Python packages installed
echo [6/6] OK >> "%LOG%"

REM ============================================================
REM Success banner
REM ============================================================
echo.
echo   +====================================================+
echo   ^|   Setup complete!                                 ^|
echo   +====================================================+
echo.
echo   Next steps:
echo   1. Connect your Android phone via USB
echo   2. Double-click run.bat -- browser opens automatically
echo.
echo   Verification commands:
echo     appium -v
echo     appium driver list --installed
echo     python --version
echo.
echo SpatchEx install completed OK %DATE% %TIME% >> "%LOG%"
echo   Log: %LOG%
GOTO :done

REM ============================================================
REM Failure tail — show last 30 log lines then fall into :done
REM ============================================================
:done_tail
echo.
echo   ---- Last 30 lines from log ----
powershell -NoProfile -Command "if (Test-Path '%LOG%') { Get-Content '%LOG%' -Tail 30 } else { Write-Host 'Log not found.' }"
echo   ---- End of log ----
echo.

:done
echo SpatchEx install ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%SETUP_FAILED%"=="1" (
  echo   Setup did NOT complete. See errors above.
  echo   Full log: %LOG%
)
echo   Press any key to close...
pause >nul
IF "%SETUP_FAILED%"=="1" EXIT /B 1
EXIT /B 0
