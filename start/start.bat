@echo off
REM ============================================================
REM SpatchEx Long-Run Test -- Server Start
REM start\start.bat
REM
REM Design rules:
REM   - APPIUM_MODE=global|npx  (no multi-token command variables)
REM   - All .cmd/.bat use CALL
REM   - start "" http://URL  (no quotes around URL)
REM   - Flat label flow; no nested IF blocks for error checks
REM ============================================================
cd /d "%~dp0.."

REM ── Verify project root (web\app.py must exist) ──────────────
IF EXIST "web\app.py" GOTO :root_ok
echo.
echo   ERROR: web\app.py not found.
echo   Current directory: %CD%
echo   Directory listing:
dir /b
echo.
echo   Expected project layout:
echo     Ex-Automation\
echo       run.bat
echo       start\start.bat   ^<-- this file
echo       web\app.py        ^<-- missing!
echo       install\
echo       src\
echo.
echo   If you extracted the ZIP, make sure you are running
echo   start.bat from inside the Ex-Automation folder,
echo   not from a nested sub-folder.
echo.
pause
EXIT /B 1
:root_ok

REM ── Runtime detection (prefer bundled runtimes, fall back to system) ─
REM    runtime\python\             Python embeddable
REM    runtime\android-sdk\        Android Platform Tools (ANDROID_HOME)
REM    runtime\node\               Node.js portable
REM    runtime\appium\             Appium (npm installed)
SET "PYTHON_EXE=python"
SET "RUNTIME_PYTHON=0"
IF EXIST "runtime\python\python.exe" (
    SET "PYTHON_EXE=%CD%\runtime\python\python.exe"
    SET "RUNTIME_PYTHON=1"
    echo   [runtime] Using bundled Python
)
IF EXIST "runtime\android-sdk\platform-tools\adb.exe" (
    SET "ANDROID_HOME=%CD%\runtime\android-sdk"
    SET "ANDROID_SDK_ROOT=%CD%\runtime\android-sdk"
    SET "PATH=%CD%\runtime\android-sdk\platform-tools;%PATH%"
    echo   [runtime] Using bundled ADB (ANDROID_HOME set)
)
IF EXIST "runtime\node\node.exe" (
    SET "PATH=%CD%\runtime\node;%CD%\runtime\node\node_modules\.bin;%PATH%"
    echo   [runtime] Using bundled Node.js
)
IF EXIST "runtime\appium\node_modules\.bin\appium.cmd" (
    SET "APPIUM_CMD=%CD%\runtime\appium\node_modules\.bin\appium.cmd"
    echo   [runtime] Using bundled Appium
)

REM ── PATH hardening (system fallback -- only if not using bundled) ────
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
IF "%APPIUM_CMD%"=="" SET "APPIUM_CMD=%APPDATA%\npm\appium.cmd"

REM ── Preflight: validate bundled runtime integrity ─────────────────────
REM    Case a) No runtime\ folder         → system mode, no checks needed
REM    Case b) runtime\ exists, no .ready → incomplete bootstrap, warn+pause
REM    Case c) runtime\ + .ready          → validate all 4 components
IF NOT EXIST "runtime" GOTO :preflight_done
IF NOT EXIST "runtime\.ready" GOTO :runtime_partial

REM Case c: .ready exists -- validate all 4 components
SET _PRE_OK=1
IF NOT EXIST "runtime\python\python.exe" (
    echo   ERROR: runtime\python\python.exe is missing.
    SET _PRE_OK=0
)
IF NOT EXIST "runtime\node\node.exe" (
    echo   ERROR: runtime\node\node.exe is missing.
    SET _PRE_OK=0
)
IF NOT EXIST "runtime\appium\node_modules\.bin\appium.cmd" (
    echo   ERROR: runtime\appium\node_modules\.bin\appium.cmd is missing.
    SET _PRE_OK=0
)
IF NOT EXIST "runtime\android-sdk\platform-tools\adb.exe" (
    echo   ERROR: runtime\android-sdk\platform-tools\adb.exe is missing.
    SET _PRE_OK=0
)
IF "%_PRE_OK%"=="0" (
    echo.
    echo   The bundled runtime is incomplete or was not set up correctly.
    echo   Please contact your IT admin and ask them to re-run:
    echo     install\bootstrap.bat
    echo.
    pause
    EXIT /B 1
)
echo   OK  Bundled runtime verified.
GOTO :preflight_done

REM Case b: runtime\ folder present but .ready is missing
:runtime_partial
echo.
echo   WARNING: Incomplete bundled runtime detected.
echo   The runtime\ folder exists but install\bootstrap.bat did not finish.
echo.
echo   To fix: ask your IT admin to run install\bootstrap.bat and let it
echo   complete fully before using this tool.
echo.
echo   Press any key to continue with whatever tools are available,
echo   or close this window to stop and fix the issue first.
echo.
pause >nul

:preflight_done

REM ── Timestamp + logs ─────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_start_%_TS%.log"
SET "APPIUM_LOG=%TEMP%\spatch_appium_%_TS%.log"
echo SpatchEx start.bat started %DATE% %TIME% > "%LOG%"

SET START_FAILED=0
SET APPIUM_MODE=

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +==============================================+
echo   ^|   SpatchEx Long-Run Test -- Start           ^|
echo   +==============================================+
echo.
echo   Start log : %LOG%
echo   Appium log: %APPIUM_LOG%
echo.

REM ── Runtime health summary ──────────────────────────────────────────
SET _PY_SRC=system
IF "%RUNTIME_PYTHON%"=="1" SET _PY_SRC=bundled
SET _NODE_SRC=system
IF EXIST "runtime\node\node.exe" SET _NODE_SRC=bundled
SET _APP_SRC=system
IF EXIST "runtime\appium\node_modules\.bin\appium.cmd" SET _APP_SRC=bundled
SET _ADB_SRC=system
IF NOT "%ANDROID_HOME%"=="" SET _ADB_SRC=bundled
echo   Runtime:  Python=%_PY_SRC%  Node=%_NODE_SRC%  Appium=%_APP_SRC%  ADB=%_ADB_SRC%
IF NOT "%ANDROID_HOME%"=="" echo   ANDROID_HOME=%ANDROID_HOME%
echo.

REM ============================================================
REM [1] Python
REM ============================================================
echo [1] Python...
echo [1] Python >> "%LOG%"
%PYTHON_EXE% --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :py_fail
FOR /F "tokens=*" %%v IN ('%PYTHON_EXE% --version 2^>^&1') DO echo   OK  %%v
echo [1] OK >> "%LOG%"
GOTO :step2

:py_fail
echo.
echo   ERROR: Python not found.
echo   Run install\install.bat first.
echo [1] FAIL >> "%LOG%"
SET START_FAILED=1
GOTO :show_fail

REM ============================================================
REM [2] Virtual environment
REM ============================================================
:step2
IF "%RUNTIME_PYTHON%"=="1" (
    echo.
    echo [2] Virtual environment... SKIP (using bundled Python)
    echo [2] OK (bundled python -- venv skipped) >> "%LOG%"
    GOTO :step3
)
echo.
echo [2] Virtual environment...
echo [2] venv >> "%LOG%"
IF NOT EXIST ".venv\Scripts\activate.bat" GOTO :venv_fail
call ".venv\Scripts\activate.bat"
echo   OK  .venv activated
echo [2] OK >> "%LOG%"
GOTO :step3

:venv_fail
echo.
echo   ERROR: .venv not found.
echo   Run install\install.bat first.
echo [2] FAIL >> "%LOG%"
SET START_FAILED=1
GOTO :show_fail

REM ============================================================
REM [3] Appium  (APPIUM_MODE = global | npx)
REM   3a  %APPDATA%\npm\appium.cmd  (most reliable on Windows)
REM   3b  PATH-based appium
REM   3c  npm install -g appium
REM   3d  re-check after install
REM   3e  npx -y appium@3 fallback
REM ============================================================
:step3
echo.
echo [3] Appium...
echo [3] Appium >> "%LOG%"
SET APPIUM_MODE=

REM 3a
IF NOT EXIST "%APPIUM_CMD%" GOTO :chk3b
echo   Found: %APPIUM_CMD% >> "%LOG%"
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :chk3b
SET APPIUM_MODE=global
GOTO :appium_found

REM 3b
:chk3b
call appium -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :do_npm_install
SET APPIUM_MODE=global
GOTO :appium_found

REM 3c
:do_npm_install
echo   Not found. Installing via npm (this can take a few minutes)...
echo [3c] npm install appium >> "%LOG%"
IF EXIST "%ProgramFiles%\nodejs\npm.cmd" (
    call "%ProgramFiles%\nodejs\npm.cmd" i --location=global appium
) ELSE (
    call npm i --location=global appium
)
echo [3c] npm exit=%ERRORLEVEL% >> "%LOG%"

REM 3d re-check explicit path
IF NOT EXIST "%APPIUM_CMD%" GOTO :rechk3d_path
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :rechk3d_path
SET APPIUM_MODE=global
GOTO :appium_found

:rechk3d_path
call appium -v >nul 2>&1
IF ERRORLEVEL 1 GOTO :npx_fallback
SET APPIUM_MODE=global
GOTO :appium_found

REM 3e npx fallback
:npx_fallback
echo   Global install unavailable. Trying npx fallback...
echo   (First run downloads Appium -- please wait)
call npx -y appium@3 -v
IF ERRORLEVEL 1 GOTO :appium_fail
SET APPIUM_MODE=npx
echo   OK  Appium (via npx)
GOTO :step3_done

:appium_fail
echo.
echo   ERROR: Appium is not available.
echo   Run install\install.bat and try again.
echo [3] FAIL >> "%LOG%"
SET START_FAILED=1
GOTO :show_fail

:appium_found
call appium -v
:step3_done
echo [3] OK  APPIUM_MODE=%APPIUM_MODE% >> "%LOG%"

REM ============================================================
REM [4] UiAutomator2 driver
REM ============================================================
echo.
echo [4] UiAutomator2 driver...
echo [4] UiAutomator2 >> "%LOG%"

SET "DRIVER_TMP=%TEMP%\appium_drivers_%_TS%.txt"
echo   Checking installed drivers...

IF "%APPIUM_MODE%"=="npx" GOTO :list_npx
call appium driver list --installed > "%DRIVER_TMP%" 2>&1
GOTO :list_done

:list_npx
call npx -y appium@3 driver list --installed > "%DRIVER_TMP%" 2>&1

:list_done
type "%DRIVER_TMP%"
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF ERRORLEVEL 1 GOTO :install_uia2
GOTO :uia2_ok

:install_uia2
echo   Installing uiautomator2 driver (this can take a few minutes)...
IF "%APPIUM_MODE%"=="npx" GOTO :install_uia2_npx
call appium driver install uiautomator2
GOTO :uia2_done

:install_uia2_npx
call npx -y appium@3 driver install uiautomator2

:uia2_done
SET _UIA2_ERR=%ERRORLEVEL%
echo [4] driver install exit=%_UIA2_ERR% >> "%LOG%"
IF "%_UIA2_ERR%"=="0" GOTO :uia2_ok
GOTO :uia2_fail

:uia2_fail
echo.
echo   ERROR: UiAutomator2 install failed (exit %_UIA2_ERR%).
echo   Try running as Administrator.
echo   See log: %LOG%
echo [4] FAIL >> "%LOG%"
SET START_FAILED=1
GOTO :show_fail

:uia2_ok
echo   OK  UiAutomator2 ready
echo [4] OK >> "%LOG%"

REM ============================================================
REM [5] Android device check  (warning only -- does not stop)
REM ============================================================
echo.
echo [5] Android device check...
echo [5] ADB >> "%LOG%"
adb devices 2>nul
SET _DEV=0
FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
    IF "%%S"=="device" SET _DEV=1
)
IF "%_DEV%"=="0" (
    echo.
    echo   WARNING: No Android device detected.
    echo   Connect your phone via USB and enable USB Debugging.
    echo   You can start the Web UI and connect the device later.
    echo [5] WARNING no device >> "%LOG%"
) ELSE (
    echo   OK  device connected
    echo [5] OK >> "%LOG%"
)
echo.

REM ============================================================
REM [6] Appium server -- start in new window if not on port 4723
REM ============================================================
echo [6] Appium server...
echo [6] Appium server >> "%LOG%"
netstat -an 2>nul | findstr ":4723" >nul 2>&1
IF NOT ERRORLEVEL 1 (
    echo   Already running on port 4723.
    echo [6] already running >> "%LOG%"
    GOTO :step7
)

SET "ALAUNCHER=%TEMP%\spatch_appium_%_TS%.bat"
(echo @echo off) > "%ALAUNCHER%"
(echo cd /d "%CD%") >> "%ALAUNCHER%"
IF "%APPIUM_MODE%"=="npx" (
    (echo call npx -y appium@3 --relaxed-security --log "%APPIUM_LOG%") >> "%ALAUNCHER%"
) ELSE (
    (echo call appium --relaxed-security --log "%APPIUM_LOG%") >> "%ALAUNCHER%"
)
start "Appium Server" cmd /k "%ALAUNCHER%"
echo   Appium server starting in new window...
echo   Appium log: %APPIUM_LOG%
echo [6] Appium started >> "%LOG%"
timeout /t 4 /nobreak >nul

REM ============================================================
REM [7] Background browser waiter
REM     Polls port 5001 (max 30 s), then opens browser.
REM     Runs concurrently with the web server started below.
REM ============================================================
:step7
SET "BWAITER=%TEMP%\spatch_browser_%_TS%.bat"
(echo @echo off)                                                         > "%BWAITER%"
(echo SET _W=0)                                                         >> "%BWAITER%"
(echo :wloop)                                                           >> "%BWAITER%"
(echo netstat -an 2^>nul ^| find ":5001" ^>nul 2^>^&1)                >> "%BWAITER%"
(echo IF NOT ERRORLEVEL 1 GOTO :open_browser)                          >> "%BWAITER%"
(echo timeout /t 1 /nobreak ^>nul)                                     >> "%BWAITER%"
(echo SET /A _W+=1)                                                     >> "%BWAITER%"
(echo IF %%_W%% LSS 30 GOTO :wloop)                                    >> "%BWAITER%"
(echo :open_browser)                                                    >> "%BWAITER%"
(echo start "" http://127.0.0.1:5001)                                  >> "%BWAITER%"
start /B cmd /c "%BWAITER%"
echo [7] browser waiter started >> "%LOG%"

REM ============================================================
REM [8] Web backend -- foreground, Ctrl+C to stop
REM     stderr appended to log so crash details are captured.
REM ============================================================
echo.
echo   +==============================================+
echo   ^|   Web UI : http://127.0.0.1:5001           ^|
echo   ^|   Appium : http://127.0.0.1:4723           ^|
echo   ^|   Stop   : Ctrl+C  (also close Appium win) ^|
echo   +==============================================+
echo.
echo [8] %PYTHON_EXE% web\app.py >> "%LOG%"
%PYTHON_EXE% web\app.py 2>> "%LOG%"
SET _WEB_ERR=%ERRORLEVEL%
echo [8] web server exited=%_WEB_ERR% >> "%LOG%"

REM Exit 0 or 1 = normal stop / Ctrl+C
IF "%_WEB_ERR%"=="0" GOTO :done_ok
IF "%_WEB_ERR%"=="1" GOTO :done_ok

REM Any other code = likely crash -- show last 50 log lines
echo.
echo   ------------------------------------
echo   Web server crashed (exit %_WEB_ERR%).
echo   Showing last 50 log lines:
echo   ------------------------------------
powershell -NoProfile -Command "if (Test-Path '%LOG%') { Get-Content '%LOG%' -Tail 50 } else { Write-Host 'Log not found.' }"
echo   ------------------------------------
echo.
SET START_FAILED=1
GOTO :show_fail

REM ============================================================
REM Failure handler -- show log tail then fall into :done_ok
REM ============================================================
:show_fail
echo.
echo   ---- Last 20 lines from log ----
powershell -NoProfile -Command "if (Test-Path '%LOG%') { Get-Content '%LOG%' -Tail 20 } else { Write-Host 'Log not found.' }"
echo   ---- End of log ----
echo.

:done_ok
echo SpatchEx start.bat ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%START_FAILED%"=="1" (
    echo   +==============================================+
    echo   ^|   Start did NOT complete.                  ^|
    echo   +==============================================+
    echo.
    echo   Full log: %LOG%
    echo.
    echo   Press any key to close...
    pause >nul
    EXIT /B 1
)
EXIT /B 0
