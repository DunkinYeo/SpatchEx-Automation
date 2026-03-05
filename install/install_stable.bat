@echo off
setlocal

REM ============================================================
REM SpatchEx Long-Run Test -- Windows Stable Installer
REM install/install_stable.bat
REM
REM Design rules:
REM   - No cmd /k self-relaunch. Relies on pause at end.
REM   - No multi-token variables (APPIUM_RUN removed).
REM     APPIUM_MODE = global | npx
REM   - All .cmd/.bat invocations use CALL.
REM   - Flat label control flow. No nested IF blocks.
REM   - Always ends with summary + pause.
REM ============================================================

cd /d "%~dp0.."

REM ── Timestamp + log file ─────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_install_stable_%_TS%.log"
echo SpatchEx stable install started %DATE% %TIME% > "%LOG%"

REM ── PATH: prepend Node.js + npm global bin ───────────────────
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
SET "NPM_CMD=%ProgramFiles%\nodejs\npm.cmd"
SET "APPIUM_CMD=%APPDATA%\npm\appium.cmd"

SET SETUP_FAILED=0
SET APPIUM_MODE=

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   SpatchEx Long-Run Test -- Stable Installer      ^|
echo   +====================================================+
echo.
echo   Log: %LOG%
echo.

REM ============================================================
REM [1/6] Python
REM ============================================================
echo [1/6] Python...
echo [1/6] Python >> "%LOG%"

python --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :py_missing
FOR /F "tokens=*" %%v IN ('python --version 2^>^&1') DO echo   OK  %%v
echo [1/6] OK >> "%LOG%"
GOTO :step2

:py_missing
echo   Not found. Installing Python 3.12 via winget...
echo   winget Python.Python.3.12 >> "%LOG%"
winget install -e --id Python.Python.3.12 --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :py_fail
echo   Installed. CLOSE this window and RE-RUN install_stable.bat.
echo [1/6] INSTALLED - reopen required >> "%LOG%"
GOTO :done

:py_fail
echo.
echo   ERROR: Python not found and auto-install failed.
echo   Download: https://www.python.org/downloads/
echo   IMPORTANT: Check "Add Python to PATH" during install.
echo [1/6] FAIL >> "%LOG%"
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

:npm_check
IF EXIST "%NPM_CMD%" GOTO :step2_ok
call npm --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :npm_fail
GOTO :step2_ok

:node_missing
echo   Not found. Installing Node.js LTS via winget...
winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :node_fail
echo   Installed. CLOSE this window and RE-RUN install_stable.bat.
echo [2/6] INSTALLED - reopen required >> "%LOG%"
GOTO :done

:node_fail
echo.
echo   ERROR: Node.js not found and auto-install failed.
echo   Download: https://nodejs.org/
echo [2/6] FAIL >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done

:npm_fail
echo.
echo   ERROR: npm not found. Close this window and re-run install_stable.bat.
echo [2/6] FAIL npm >> "%LOG%"
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
echo   Installed. CLOSE this window and RE-RUN install_stable.bat.
echo [3/6] INSTALLED - reopen required >> "%LOG%"
GOTO :done

:adb_fail
echo.
echo   ERROR: ADB not found and auto-install failed.
echo   Download: https://developer.android.com/tools/releases/platform-tools
echo [3/6] FAIL >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done

REM ============================================================
REM [4/6] Appium
REM
REM   APPIUM_MODE = global  ->  call appium <args>
REM   APPIUM_MODE = npx     ->  call npx -y appium@3 <args>
REM
REM   Priority:
REM   4a  %APPDATA%\npm\appium.cmd  (most reliable on Windows)
REM   4b  PATH-based appium
REM   4c  npm install -g appium
REM   4d  re-check after install (explicit path, then PATH)
REM   4e  npx -y appium@3 fallback
REM ============================================================
:step4
echo.
echo [4/6] Appium...
echo [4/6] Appium >> "%LOG%"
SET APPIUM_MODE=

REM 4a. %APPDATA%\npm\appium.cmd
IF NOT EXIST "%APPIUM_CMD%" GOTO :chk4b
echo   Found: %APPIUM_CMD% >> "%LOG%"
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :chk4b
SET APPIUM_MODE=global
GOTO :appium_ready

REM 4b. PATH-based appium
:chk4b
call appium -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :appium_install
SET APPIUM_MODE=global
GOTO :appium_ready

REM 4c. npm install -g appium (live output on console)
:appium_install
echo   Not found. Installing via npm (this can take a few minutes)...
echo   npm i --location=global appium >> "%LOG%"
IF EXIST "%NPM_CMD%" (
    call "%NPM_CMD%" i --location=global appium
) ELSE (
    call npm i --location=global appium
)
echo   npm install exit=%ERRORLEVEL% >> "%LOG%"

REM 4d. Re-check explicit path after install
IF NOT EXIST "%APPIUM_CMD%" GOTO :chk4d_path
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :chk4d_path
SET APPIUM_MODE=global
GOTO :appium_ready

REM 4d. Re-check PATH after install
:chk4d_path
call appium -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :npx_fallback
SET APPIUM_MODE=global
GOTO :appium_ready

REM 4e. npx fallback (live output — first run downloads appium, ~1 min)
:npx_fallback
echo   Global install unavailable. Trying npx fallback...
echo   (First run may download appium — please wait, do not close this window)
call npx -y appium@3 -v
IF ERRORLEVEL 1 GOTO :appium_fail
SET APPIUM_MODE=npx
echo   OK  Appium ready (via npx)
GOTO :step4_done

:appium_fail
echo.
echo   ERROR: Appium could not be installed or started.
echo   See log: %LOG%
echo [4/6] FAIL >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done_tail

:appium_ready
call appium -v
:step4_done
echo [4/6] OK  APPIUM_MODE=%APPIUM_MODE% >> "%LOG%"

REM ============================================================
REM [5/6] UiAutomator2 driver
REM   Commands dispatched via APPIUM_MODE (no multi-token var).
REM ============================================================
echo.
echo [5/6] UiAutomator2 driver...
echo [5/6] UiAutomator2 >> "%LOG%"

IF "%APPIUM_MODE%"=="" GOTO :uia2_no_appium

SET "DRIVER_TMP=%TEMP%\appium_drivers_%_TS%.txt"
echo   Checking installed drivers...

IF "%APPIUM_MODE%"=="npx" GOTO :list_drivers_npx
call appium driver list --installed > "%DRIVER_TMP%" 2>&1
GOTO :list_drivers_done

:list_drivers_npx
call npx -y appium@3 driver list --installed > "%DRIVER_TMP%" 2>&1

:list_drivers_done
type "%DRIVER_TMP%"
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF ERRORLEVEL 1 GOTO :uia2_install
GOTO :uia2_ok

:uia2_install
echo   Not installed. Installing uiautomator2 (this can take a few minutes)...
IF "%APPIUM_MODE%"=="npx" GOTO :install_driver_npx
call appium driver install uiautomator2
GOTO :install_driver_done

:install_driver_npx
call npx -y appium@3 driver install uiautomator2

:install_driver_done
SET _UIA2_ERR=%ERRORLEVEL%
echo   driver install exit=%_UIA2_ERR% >> "%LOG%"
IF "%_UIA2_ERR%"=="0" GOTO :uia2_ok
GOTO :uia2_fail

:uia2_no_appium
echo.
echo   ERROR: Appium not available — cannot check UiAutomator2 driver.
echo [5/6] FAIL no appium >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done_tail

:uia2_fail
echo.
echo   ERROR: UiAutomator2 install failed (exit %_UIA2_ERR%).
echo   If you see permission errors, try running as Administrator.
echo   See log: %LOG%
echo [5/6] FAIL >> "%LOG%"
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
echo.
echo   ERROR: Failed to create .venv
echo   See log: %LOG%
echo [6/6] FAIL venv >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done_tail

:venv_ready
call .venv\Scripts\activate.bat
echo   Installing requirements...
pip install -r requirements.txt
SET _PIP_ERR=%ERRORLEVEL%
echo   pip install exit=%_PIP_ERR% >> "%LOG%"
IF "%_PIP_ERR%"=="0" GOTO :pip_ok
GOTO :pip_fail

:pip_fail
echo.
echo   ERROR: pip install failed (exit %_PIP_ERR%)
echo   See log: %LOG%
echo [6/6] FAIL pip >> "%LOG%"
SET SETUP_FAILED=1
GOTO :done_tail

:pip_ok
echo   OK  Python packages installed
echo [6/6] OK >> "%LOG%"

REM ── Success banner ───────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   Setup complete!                                 ^|
echo   +====================================================+
echo.
echo   Next steps:
echo   1. Connect your Android phone via USB
echo   2. Double-click run.bat (browser opens automatically)
echo.
echo   Verification commands:
echo     appium -v
echo     appium driver list --installed
echo     python --version
echo.
echo SpatchEx stable install completed OK %DATE% %TIME% >> "%LOG%"
echo   Log: %LOG%
GOTO :done

REM ── Failure tail: show last 20 log lines ─────────────────────
:done_tail
echo.
echo   ---- Last 20 lines from log ----
powershell -NoProfile -Command "if (Test-Path '%LOG%') { Get-Content '%LOG%' -Tail 20 } else { Write-Host 'Log not found.' }"
echo   ---- End of log ----
echo.

:done
echo SpatchEx stable install ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%SETUP_FAILED%"=="1" (
    echo   +====================================================+
    echo   ^|   Setup did NOT complete. See errors above.       ^|
    echo   +====================================================+
    echo.
    echo   Full log: %LOG%
    echo.
)
echo   Press any key to close...
pause >nul
IF "%SETUP_FAILED%"=="1" EXIT /B 1
EXIT /B 0
