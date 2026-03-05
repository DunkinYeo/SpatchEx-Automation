@echo off
REM ============================================================
REM SpatchEx Long-Run Test -- Windows Setup
REM ============================================================
REM Keep window open: re-launch inside cmd /k on direct double-click
IF "%SPATCHEX_RUNNING%"=="1" GOTO :run
SET SPATCHEX_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0.."

REM ── Timestamped log in TEMP (keeps install dir clean) ───────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_install_%_TS%.log"
echo SpatchEx install started %DATE% %TIME% > "%LOG%"

REM ── Strong PATH: always include Node.js + npm global bin ────
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
SET "NPM_CMD=%ProgramFiles%\nodejs\npm.cmd"
SET "APPIUM_CMD=%APPDATA%\npm\appium.cmd"

SET SETUP_FAILED=0
SET APPIUM_RUN=

REM ── Banner ──────────────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   SpatchEx Long-Run Test -- Windows Setup         ^|
echo   +====================================================+
echo.
echo   Log: %LOG%
echo.

REM ============================================================
echo [1/6] Python...
echo [1/6] Python >> "%LOG%"
python --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :python_ok

echo   Not found. Installing Python 3.12 via winget...
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF NOT ERRORLEVEL 1 GOTO :python_rerun
echo.
echo   ERROR: Could not auto-install Python.
echo   Install manually: https://www.python.org/downloads/
echo   IMPORTANT: Check "Add Python to PATH" during install.
start https://www.python.org/downloads/
SET SETUP_FAILED=1
GOTO :done

:python_rerun
echo   Installed. CLOSE this window and RE-RUN install.bat.
GOTO :done

:python_ok
FOR /F "tokens=*" %%v IN ('python --version 2^>^&1') DO echo   OK  %%v
echo [1/6] OK >> "%LOG%"

REM ============================================================
echo.
echo [2/6] Node.js / npm...
echo [2/6] Node.js >> "%LOG%"
node --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :node_ok

echo   Not found. Installing Node.js LTS via winget...
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF NOT ERRORLEVEL 1 GOTO :node_rerun
echo.
echo   ERROR: Could not auto-install Node.js.
echo   Install manually: https://nodejs.org/
start https://nodejs.org/
SET SETUP_FAILED=1
GOTO :done

:node_rerun
echo   Installed. CLOSE this window and RE-RUN install.bat.
GOTO :done

:node_ok
FOR /F "tokens=*" %%v IN ('node --version 2^>^&1') DO echo   OK  Node.js %%v

REM Verify npm is reachable (explicit path or PATH-based)
IF EXIST "%NPM_CMD%" GOTO :npm_ok
npm --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :npm_ok
echo   ERROR: npm not found after Node.js install. Close and re-run.
SET SETUP_FAILED=1
GOTO :done

:npm_ok
echo [2/6] OK >> "%LOG%"

REM ============================================================
echo.
echo [3/6] ADB (Android Debug Bridge)...
echo [3/6] ADB >> "%LOG%"
adb --version >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :adb_ok

echo   Not found. Installing Android Platform Tools via winget...
winget install -e --id Google.PlatformTools --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF NOT ERRORLEVEL 1 GOTO :adb_rerun
echo.
echo   ERROR: Could not auto-install ADB.
echo   Install manually: https://developer.android.com/tools/releases/platform-tools
start https://developer.android.com/tools/releases/platform-tools
SET SETUP_FAILED=1
GOTO :done

:adb_rerun
echo   Installed. CLOSE this window and RE-RUN install.bat.
GOTO :done

:adb_ok
echo   OK  ADB ready
echo [3/6] OK >> "%LOG%"

REM ============================================================
echo.
echo [4/6] Appium...
echo [4/6] Appium diagnostics >> "%LOG%"
where appium >> "%LOG%" 2>&1
IF EXIST "%APPIUM_CMD%" (echo   APPIUM_CMD exists >> "%LOG%") ELSE (echo   APPIUM_CMD missing >> "%LOG%")

REM 4a. Explicit global path: %APPDATA%\npm\appium.cmd
IF EXIST "%APPIUM_CMD%" (
  "%APPIUM_CMD%" -v >nul 2>&1
  IF NOT ERRORLEVEL 1 (
    SET "APPIUM_RUN=%APPIUM_CMD%"
    GOTO :appium_found
  )
)

REM 4b. PATH-based appium
appium -v >nul 2>&1
IF NOT ERRORLEVEL 1 (
  SET APPIUM_RUN=appium
  GOTO :appium_found
)

REM 4c. Not installed — install globally (live console output so it doesn't look frozen)
echo   Not found. Installing globally via npm (this can take a few minutes)...
echo npm i --location=global appium started >> "%LOG%"
IF EXIST "%NPM_CMD%" (
  "%NPM_CMD%" i --location=global appium
) ELSE (
  npm i --location=global appium
)
SET NPM_ERR=%ERRORLEVEL%
echo npm i -g appium exit=%NPM_ERR% >> "%LOG%"
IF %NPM_ERR% NEQ 0 GOTO :appium_npm_failed

REM 4d. Re-verify after global install
IF EXIST "%APPIUM_CMD%" (
  "%APPIUM_CMD%" -v >nul 2>&1
  IF NOT ERRORLEVEL 1 (
    SET "APPIUM_RUN=%APPIUM_CMD%"
    GOTO :appium_found
  )
)
appium -v >nul 2>&1
IF NOT ERRORLEVEL 1 (
  SET APPIUM_RUN=appium
  GOTO :appium_found
)

REM 4e. npx fallback — output shown on console (NOT redirected to log) so it doesn't appear frozen
:appium_npm_failed
echo   Global install unavailable. Trying npx fallback...
echo   (First run downloads appium ~1 min — do not close this window)
echo npx fallback >> "%LOG%"
SET "APPIUM_RUN=npx -y appium@3"
npx -y appium@3 -v
IF NOT ERRORLEVEL 1 GOTO :appium_npx_ok

echo.
echo   ERROR: Appium could not be started via npm or npx.
echo   See log: %LOG%
echo FAIL: all Appium strategies failed >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done_tail

:appium_found
FOR /F "tokens=*" %%v IN ('%APPIUM_RUN% -v 2^>nul') DO echo   OK  Appium %%v
GOTO :appium_ok

:appium_npx_ok
echo   OK  Appium ready (via npx)

:appium_ok
echo [4/6] Appium: %APPIUM_RUN% >> "%LOG%"

REM ============================================================
echo.
echo [5/6] UiAutomator2 driver...
echo [5/6] UiAutomator2 >> "%LOG%"
SET "DRIVER_TMP=%TEMP%\appium_drivers_%_TS%.txt"

REM Check installed drivers — capture then print so console shows progress
echo   Checking installed drivers...
%APPIUM_RUN% driver list --installed > "%DRIVER_TMP%" 2>&1
type "%DRIVER_TMP%"
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF NOT ERRORLEVEL 1 GOTO :uia2_ok

REM Install — output always shown on console
echo   Not installed. Installing uiautomator2 (this can take a few minutes)...
%APPIUM_RUN% driver install uiautomator2
SET UIA2_ERR=%ERRORLEVEL%
echo driver install uiautomator2 exit=%UIA2_ERR% >> "%LOG%"
IF %UIA2_ERR% EQU 0 GOTO :uia2_ok

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
echo.
echo [6/6] Python packages...
echo [6/6] Python packages >> "%LOG%"
IF EXIST ".venv" GOTO :venv_ready
echo   Creating virtual environment...
python -m venv .venv >> "%LOG%" 2>&1
IF NOT ERRORLEVEL 1 GOTO :venv_ready
echo   ERROR: Failed to create .venv. See log: %LOG%
SET SETUP_FAILED=1
GOTO :done_tail

:venv_ready
call .venv\Scripts\activate.bat
echo   Installing requirements...
pip install -r requirements.txt
SET PIP_ERR=%ERRORLEVEL%
echo pip install exit=%PIP_ERR% >> "%LOG%"
IF %PIP_ERR% EQU 0 GOTO :pip_ok
echo   ERROR: pip install failed (exit %PIP_ERR%). See log: %LOG%
SET SETUP_FAILED=1
GOTO :done_tail

:pip_ok
echo   OK  Python packages installed
echo [6/6] OK >> "%LOG%"

REM ============================================================
echo.
echo   +====================================================+
echo   ^|   Setup complete!                                 ^|
echo   +====================================================+
echo.
echo   Next steps:
echo   1. Connect your Android phone via USB
echo   2. Double-click run.bat -^> browser opens automatically
echo.
echo   Verification commands:
echo     appium -v
echo     appium driver list --installed
echo     python -c "import sys; print(sys.version)"
echo.
echo SpatchEx install completed OK %DATE% %TIME% >> "%LOG%"
echo Log: %LOG%
GOTO :done

:done_tail
echo.
echo   ---- Last 30 lines from log (%LOG%) ----
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
