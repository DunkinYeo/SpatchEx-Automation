@echo off
REM ============================================================
REM SpatchEx -- Runtime Self-Test
REM selftest.bat  (project root)
REM
REM  Run this to verify the bundled runtime is working correctly
REM  before distributing to CS/UAT staff, or to diagnose
REM  problems on a tester's machine.
REM
REM  Checks:
REM    [1] Python version
REM    [2] pip / packages
REM    [3] Node.js version
REM    [4] Appium version
REM    [5] UiAutomator2 driver installed
REM    [6] ADB version
REM    [7] ADB connected devices
REM    [8] Web server can start (3-second smoke test)
REM
REM  Prints a PASS/FAIL summary at the end.
REM ============================================================
REM Keep window open on double-click
IF "%SELFTEST_RUNNING%"=="1" GOTO :run
SET SELFTEST_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0"

REM ── Verify project root ──────────────────────────────────────
IF EXIST "web\app.py" GOTO :root_ok
echo.
echo   ERROR: web\app.py not found.
echo   Run selftest.bat from inside the SpatchEx-Automation folder.
echo.
pause
EXIT /B 1
:root_ok

REM ── Runtime detection (mirrors start\start.bat) ──────────────
SET "PYTHON_EXE=python"
SET "RUNTIME_PYTHON=0"
SET "APPIUM_CMD="
SET "ANDROID_HOME="

IF EXIST "runtime\python\python.exe" (
    SET "PYTHON_EXE=%CD%\runtime\python\python.exe"
    SET "RUNTIME_PYTHON=1"
)
IF EXIST "runtime\android-sdk\platform-tools\adb.exe" (
    SET "ANDROID_HOME=%CD%\runtime\android-sdk"
    SET "ANDROID_SDK_ROOT=%CD%\runtime\android-sdk"
    SET "PATH=%CD%\runtime\android-sdk\platform-tools;%PATH%"
)
IF EXIST "runtime\node\node.exe" (
    SET "PATH=%CD%\runtime\node;%CD%\runtime\node\node_modules\.bin;%PATH%"
)
IF EXIST "runtime\appium\node_modules\.bin\appium.cmd" (
    SET "APPIUM_CMD=%CD%\runtime\appium\node_modules\.bin\appium.cmd"
)
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
IF "%APPIUM_CMD%"=="" SET "APPIUM_CMD=%APPDATA%\npm\appium.cmd"

REM ── Timestamp + log ─────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_selftest_%_TS%.log"
echo SpatchEx selftest started %DATE% %TIME% > "%LOG%"

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +==============================================+
echo   ^|   SpatchEx -- Runtime Self-Test             ^|
echo   +==============================================+
echo.

REM Source summary
SET _PY_SRC=system
IF "%RUNTIME_PYTHON%"=="1" SET _PY_SRC=bundled
SET _ADB_SRC=system
IF NOT "%ANDROID_HOME%"=="" SET _ADB_SRC=bundled
SET _APP_SRC=system
IF EXIST "runtime\appium\node_modules\.bin\appium.cmd" SET _APP_SRC=bundled
SET _NODE_SRC=system
IF EXIST "runtime\node\node.exe" SET _NODE_SRC=bundled

echo   Runtime:  Python=%_PY_SRC%  Node=%_NODE_SRC%  Appium=%_APP_SRC%  ADB=%_ADB_SRC%
IF NOT "%ANDROID_HOME%"=="" echo   ANDROID_HOME=%ANDROID_HOME%
echo   Log: %LOG%
echo.

REM ── Result tracking ─────────────────────────────────────────
SET _PASS=0
SET _FAIL=0
SET _WARN=0

REM ============================================================
REM [1] Python
REM ============================================================
echo [1] Python...
%PYTHON_EXE% --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Python not found: %PYTHON_EXE%
    echo [1] FAIL: python not found >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test2
)
FOR /F "tokens=*" %%v IN ('%PYTHON_EXE% --version 2^>^&1') DO (
    echo   PASS  %%v [%_PY_SRC%]
    echo [1] PASS: %%v >> "%LOG%"
)
SET /A _PASS+=1

:test2
REM ============================================================
REM [2] pip / Python packages
REM ============================================================
echo.
echo [2] Python packages...
%PYTHON_EXE% -c "import flask, yaml, appium, apscheduler, requests, jinja2" >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  One or more required packages are missing.
    echo   Run: %PYTHON_EXE% -m pip install -r requirements.txt
    echo [2] FAIL: missing packages >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test3
)
echo   PASS  flask, yaml, appium, apscheduler, requests, jinja2 all importable
echo [2] PASS: packages OK >> "%LOG%"
SET /A _PASS+=1

:test3
REM ============================================================
REM [3] Node.js
REM ============================================================
echo.
echo [3] Node.js...
node --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Node.js not found in PATH.
    echo [3] FAIL: node not found >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test4
)
FOR /F "tokens=*" %%v IN ('node --version 2^>^&1') DO (
    echo   PASS  Node.js %%v [%_NODE_SRC%]
    echo [3] PASS: Node.js %%v >> "%LOG%"
)
SET /A _PASS+=1

:test4
REM ============================================================
REM [4] Appium
REM ============================================================
echo.
echo [4] Appium...
IF NOT EXIST "%APPIUM_CMD%" (
    echo   FAIL  Appium not found: %APPIUM_CMD%
    echo [4] FAIL: appium.cmd not found >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test5
)
call "%APPIUM_CMD%" -v >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Appium found but failed to run: %APPIUM_CMD%
    echo [4] FAIL: appium -v returned error >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test5
)
FOR /F "tokens=*" %%v IN ('call "%APPIUM_CMD%" -v 2^>^&1') DO (
    echo   PASS  Appium %%v [%_APP_SRC%]
    echo [4] PASS: Appium %%v >> "%LOG%"
)
SET /A _PASS+=1

:test5
REM ============================================================
REM [5] UiAutomator2 driver
REM ============================================================
echo.
echo [5] UiAutomator2 driver...
IF NOT EXIST "%APPIUM_CMD%" (
    echo   SKIP  Appium not available -- cannot check drivers.
    echo [5] SKIP >> "%LOG%"
    SET /A _WARN+=1
    GOTO :test6
)
SET "DRIVER_TMP=%TEMP%\selftest_drivers_%_TS%.txt"
call "%APPIUM_CMD%" driver list --installed > "%DRIVER_TMP%" 2>&1
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  UiAutomator2 driver is NOT installed.
    echo   Run: install\bootstrap.bat to fix this.
    echo [5] FAIL: uiautomator2 not installed >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test6
)
echo   PASS  UiAutomator2 driver is installed.
echo [5] PASS >> "%LOG%"
SET /A _PASS+=1
del "%DRIVER_TMP%" >nul 2>&1

:test6
REM ============================================================
REM [6] ADB version
REM ============================================================
echo.
echo [6] ADB...
adb --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  ADB not found in PATH. [%_ADB_SRC%]
    echo [6] FAIL: adb not found >> "%LOG%"
    SET /A _FAIL+=1
    GOTO :test7
)
FOR /F "tokens=1,2,3" %%a IN ('adb --version 2^>^&1 ^| findstr /i "android debug"') DO (
    echo   PASS  %%a %%b %%c [%_ADB_SRC%]
    echo [6] PASS: %%a %%b %%c >> "%LOG%"
)
SET /A _PASS+=1

:test7
REM ============================================================
REM [7] ADB devices -- classify each device by its ADB status
REM    device       = connected and fully authorized
REM    unauthorized = connected but USB debugging popup not accepted
REM    offline      = connected but ADB cannot communicate
REM    (none)       = no USB device detected at all
REM ============================================================
echo.
echo [7] Connected devices...
echo   Raw output from adb devices:
adb devices 2>nul
SET _DEV_OK=0
SET _DEV_UNAUTH=0
SET _DEV_OFFLINE=0
FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
    IF "%%S"=="device"       SET _DEV_OK=1
    IF "%%S"=="unauthorized" SET _DEV_UNAUTH=1
    IF "%%S"=="offline"      SET _DEV_OFFLINE=1
)

IF "%_DEV_OK%"=="1" (
    echo   PASS  Device is connected and fully authorized.
    echo [7] PASS: device authorized >> "%LOG%"
    SET /A _PASS+=1
    GOTO :test8
)
IF "%_DEV_UNAUTH%"=="1" (
    echo   WARN  Device found -- but USB Debugging is not authorized.
    echo         On your phone, look for a popup:
    echo         "Allow USB debugging from this computer?"  ^> tap ALLOW
    echo         Then unplug and replug the USB cable.
    echo [7] WARN: unauthorized >> "%LOG%"
    SET /A _WARN+=1
    GOTO :test8
)
IF "%_DEV_OFFLINE%"=="1" (
    echo   WARN  Device found -- but ADB reports it as offline.
    echo         Unplug the USB cable, wait 3 seconds, plug back in.
    echo         If this repeats, try a different USB cable or port.
    echo [7] WARN: offline >> "%LOG%"
    SET /A _WARN+=1
    GOTO :test8
)
echo   WARN  No Android device detected.
echo         1. Connect your phone via USB cable.
echo         2. On the phone: Settings ^> Developer Options ^> USB Debugging ON
echo         3. Accept the "Allow USB debugging" popup on the phone.
echo [7] WARN: no device >> "%LOG%"
SET /A _WARN+=1

:test8
REM ============================================================
REM [8] Web server smoke test
REM    Starts web/app.py via PowerShell (captures PID), waits 4s,
REM    then checks both: port 5001 is open AND process is still alive.
REM    Prints last 10 lines of startup output on failure.
REM    Kills the test server before exiting.
REM ============================================================
echo.
echo [8] Web server (smoke test)...

REM Check if port 5001 is already in use
netstat -an 2>nul | findstr ":5001" >nul 2>&1
IF NOT ERRORLEVEL 1 (
    echo   WARN  Port 5001 is already in use -- skipping smoke test.
    echo         Run STOP.bat first, then re-run selftest.bat for a clean test.
    echo [8] WARN: port 5001 already in use >> "%LOG%"
    SET /A _WARN+=1
    GOTO :summary
)

REM Start web server using PowerShell Start-Process to capture PID
SET "SMOKE_PID="
SET "SMOKE_LOG=%TEMP%\selftest_web_%_TS%.log"
FOR /F %%P IN ('powershell -NoProfile -Command "$p = Start-Process -FilePath ''%PYTHON_EXE%'' -ArgumentList ''web\app.py'' -NoNewWindow -PassThru; $p.Id"') DO SET "SMOKE_PID=%%P"
echo [8] Started PID=%SMOKE_PID% >> "%LOG%"
echo   Waiting 4 seconds for server to initialize...
timeout /t 4 /nobreak >nul

REM Check 1: port 5001 listening
SET _PORT_OK=0
netstat -an 2>nul | findstr ":5001" >nul 2>&1
IF NOT ERRORLEVEL 1 SET _PORT_OK=1

REM Check 2: process still alive (not crashed)
SET _PROC_OK=0
IF NOT "%SMOKE_PID%"=="" (
    tasklist /FI "PID eq %SMOKE_PID%" 2>nul | findstr "%SMOKE_PID%" >nul 2>&1
    IF NOT ERRORLEVEL 1 SET _PROC_OK=1
)

REM Evaluate: both checks must pass
IF "%_PORT_OK%"=="1" IF "%_PROC_OK%"=="1" GOTO :smoke_pass

REM Determine and print specific failure reason
IF "%_PROC_OK%"=="0" IF "%_PORT_OK%"=="0" (
    echo   FAIL  Web server process crashed before binding to port 5001.
    echo         The process started (PID %SMOKE_PID%) but has already exited.
    GOTO :smoke_fail_detail
)
IF "%_PORT_OK%"=="0" (
    echo   FAIL  Process (PID %SMOKE_PID%) is running but port 5001 is not open.
    echo         The server may have a startup error. Check the log below.
    GOTO :smoke_fail_detail
)
REM _PORT_OK=1 but _PROC_OK=0
echo   FAIL  Port 5001 is open but the Python process (PID %SMOKE_PID%) has exited.
echo         Another process may be occupying port 5001.

:smoke_fail_detail
echo.
IF EXIST "%SMOKE_LOG%" (
    echo   Last 10 lines of startup output:
    powershell -NoProfile -Command "Get-Content '%SMOKE_LOG%' -Tail 10 -ErrorAction SilentlyContinue"
    echo   Full log: %SMOKE_LOG%
) ELSE (
    echo   No startup log captured.
)
echo [8] FAIL (PORT=%_PORT_OK% PROC=%_PROC_OK% PID=%SMOKE_PID%) >> "%LOG%"
SET /A _FAIL+=1
GOTO :smoke_cleanup

:smoke_pass
echo   PASS  Web server running (PID %SMOKE_PID%), port 5001 is open.
echo [8] PASS (PID=%SMOKE_PID%) >> "%LOG%"
SET /A _PASS+=1

:smoke_cleanup
REM Kill the smoke test server by PID first, then port fallback
IF NOT "%SMOKE_PID%"=="" taskkill /PID %SMOKE_PID% /F >nul 2>&1
FOR /F "tokens=5" %%P IN ('netstat -ano 2^>nul ^| findstr /R ":5001 "') DO (
    IF NOT "%%P"=="0" taskkill /PID %%P /F >nul 2>&1
)
timeout /t 1 /nobreak >nul

REM ============================================================
REM Summary
REM ============================================================
:summary
echo.
echo   +==============================================+
echo   ^|   Self-Test Results                         ^|
echo   +==============================================+
echo.
echo   PASS  : %_PASS%
echo   WARN  : %_WARN%
echo   FAIL  : %_FAIL%
echo.
echo [selftest] PASS=%_PASS% WARN=%_WARN% FAIL=%_FAIL% >> "%LOG%"

IF "%_FAIL%"=="0" (
    IF "%_WARN%"=="0" (
        echo   All checks passed. Runtime is ready.
    ) ELSE (
        echo   Passed with warnings.
        echo   Warnings are non-critical but check them before distributing.
    )
) ELSE (
    echo   One or more checks FAILED.
    echo   Fix the failures above before distributing to CS/UAT staff.
    echo   Run install\bootstrap.bat to rebuild the bundled runtime.
)
echo.
echo   Full log: %LOG%
echo.
echo SpatchEx selftest ended %DATE% %TIME% >> "%LOG%"
echo   Press any key to close...
pause >nul
IF "%_FAIL%"=="0" EXIT /B 0
EXIT /B 1
