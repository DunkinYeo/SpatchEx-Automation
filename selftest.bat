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
REM [7] ADB devices (connected device check)
REM ============================================================
echo.
echo [7] Connected devices...
adb devices 2>nul
SET _DEV=0
FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
    IF "%%S"=="device" SET _DEV=1
)
IF "%_DEV%"=="0" (
    echo   WARN  No Android device detected.
    echo   Connect your phone and enable USB Debugging before running the test.
    echo [7] WARN: no device connected >> "%LOG%"
    SET /A _WARN+=1
) ELSE (
    echo   PASS  At least one Android device is connected.
    echo [7] PASS: device detected >> "%LOG%"
    SET /A _PASS+=1
)

:test8
REM ============================================================
REM [8] Web server smoke test (3-second launch check)
REM    Starts web/app.py in background, waits 3s, checks port 5001.
REM    Kills the process after the check.
REM ============================================================
echo.
echo [8] Web server (smoke test)...

REM Check if port 5001 is already in use
netstat -an 2>nul | findstr ":5001" >nul 2>&1
IF NOT ERRORLEVEL 1 (
    echo   WARN  Port 5001 is already in use -- skipping smoke test.
    echo   (Is the server already running?)
    echo [8] WARN: port 5001 already in use >> "%LOG%"
    SET /A _WARN+=1
    GOTO :summary
)

REM Start web server in background (brief launch only)
SET "SMOKE_LOG=%TEMP%\selftest_web_%_TS%.log"
start /B "" %PYTHON_EXE% web\app.py > "%SMOKE_LOG%" 2>&1
timeout /t 4 /nobreak >nul

REM Check if port 5001 is now listening
netstat -an 2>nul | findstr ":5001" >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Web server did not start on port 5001 within 4 seconds.
    echo   Check: %SMOKE_LOG%
    echo [8] FAIL: port 5001 not listening >> "%LOG%"
    SET /A _FAIL+=1
) ELSE (
    echo   PASS  Web server started and listening on port 5001.
    echo [8] PASS >> "%LOG%"
    SET /A _PASS+=1
)

REM Kill the smoke test web server
FOR /F "tokens=5" %%P IN ('netstat -ano 2^>nul ^| findstr /R ":5001 "') DO (
    IF NOT "%%P"=="0" taskkill /PID %%P /F >nul 2>&1
)

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
