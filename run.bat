@echo off
setlocal
echo DEBUG: run.bat started
pause
chcp 65001 >nul
echo DEBUG: current dir = %CD%
pause
cd /d "%~dp0"
REM SpatchEx -- Launch Test Environment
REM run.bat  (project root)
REM Double-click to start Appium + Web UI.
REM Browser opens automatically when the server is ready.
REM Leave this window OPEN during the test.
REM To stop: run STOP.bat or close this window.

REM -- Timestamp + log -----------------------------------------
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_run_%_TS%.log"
echo SpatchEx run started %DATE% %TIME% > "%LOG%"

REM -- Banner --------------------------------------------------
echo.
echo   +==============================================+
echo   ^|   SpatchEx -- Launch Test Environment       ^|
echo   +==============================================+
echo.
echo   Log: %LOG%
echo.

REM -- [1] Verify project root ---------------------------------
IF NOT EXIST "web\app.py" (
    echo.
    echo   ERROR: web\app.py not found.
    echo   Run run.bat from inside the SpatchEx-Automation folder.
    echo.
    echo [run] FAIL: web\app.py not found >> "%LOG%"
    pause
    EXIT /B 1
)

REM -- [2] Check .venv -- guide to install.bat if missing ------
IF NOT EXIST ".venv\Scripts\activate.bat" (
    echo.
    echo   ERROR: Python environment not set up.
    echo.
    echo   Please run install.bat first, then re-run run.bat.
    echo.
    echo [run] FAIL: .venv not found >> "%LOG%"
    pause
    EXIT /B 1
)

REM -- [3] Activate virtual environment ------------------------
echo   Activating Python environment...
call .venv\Scripts\activate.bat
echo [run] .venv activated >> "%LOG%"

REM -- [4] Android SDK detection -------------------------------
REM Case A: platform-tools downloaded directly into runtime\ by install.bat
IF EXIST "runtime\platform-tools\adb.exe" (
    SET "ANDROID_HOME=%CD%\runtime"
    SET "ANDROID_SDK_ROOT=%CD%\runtime"
    SET "PATH=%CD%\runtime\platform-tools;%PATH%"
    GOTO :sdk_ready
)

REM Case A2: legacy bundled SDK layout runtime\android-sdk\
IF EXIST "runtime\android-sdk\platform-tools\adb.exe" (
    SET "ANDROID_HOME=%CD%\runtime\android-sdk"
    SET "ANDROID_SDK_ROOT=%CD%\runtime\android-sdk"
    SET "PATH=%CD%\runtime\android-sdk\platform-tools;%PATH%"
    GOTO :sdk_ready
)

REM Case B-1: ANDROID_HOME already set and valid
IF NOT "%ANDROID_HOME%"=="" (
    IF EXIST "%ANDROID_HOME%\platform-tools\adb.exe" (
        SET "ANDROID_SDK_ROOT=%ANDROID_HOME%"
        GOTO :sdk_ready
    )
)

REM Case B-2: ANDROID_SDK_ROOT already set and valid
IF NOT "%ANDROID_SDK_ROOT%"=="" (
    IF EXIST "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
        SET "ANDROID_HOME=%ANDROID_SDK_ROOT%"
        GOTO :sdk_ready
    )
)

REM Case B-3: locate adb via PATH, derive SDK root from its location
SET "_ADB_PATH="
FOR /F "usebackq tokens=*" %%A IN (`where adb 2^>nul`) DO (
    IF NOT DEFINED _ADB_PATH SET "_ADB_PATH=%%A"
)
IF NOT "%_ADB_PATH%"=="" (
    REM %%~dpA = drive+path of adb.exe  e.g. C:\...\platform-tools\
    FOR %%A IN ("%_ADB_PATH%") DO SET "_PTDIR=%%~dpA"
    REM Strip trailing backslash so the next FOR sees it as a file token
    SET "_PTDIR=%_PTDIR:~0,-1%"
    FOR %%A IN ("%_PTDIR%") DO SET "_SDK_ROOT=%%~dpA"
    REM Strip trailing backslash from SDK root
    SET "_SDK_ROOT=%_SDK_ROOT:~0,-1%"
    SET "ANDROID_HOME=%_SDK_ROOT%"
    SET "ANDROID_SDK_ROOT=%_SDK_ROOT%"
    GOTO :sdk_ready
)

REM No SDK found -- cannot proceed
echo.
echo   ERROR  Android SDK not found.
echo.
echo   ANDROID_HOME and ANDROID_SDK_ROOT are not set,
echo   and adb was not found in PATH.
echo.
echo   Please install Android Studio or the Android command-line tools,
echo   then re-run run.bat.
echo   Download: https://developer.android.com/studio
echo.
echo [run] FAIL: Android SDK not found >> "%LOG%"
pause
EXIT /B 1

:sdk_ready
SET "PATH=%ANDROID_HOME%\platform-tools;%PATH%"
echo   ANDROID_HOME=%ANDROID_HOME%
echo   ANDROID_SDK_ROOT=%ANDROID_SDK_ROOT%
echo [run] ANDROID_HOME=%ANDROID_HOME% >> "%LOG%"

REM -- Ensure npm global bin is in PATH (Appium installed via npm)
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

REM -- Bundled Node / Appium (optional, falls back to global) --
IF EXIST "runtime\node\node.exe" (
    SET "PATH=%CD%\runtime\node;%CD%\runtime\node\node_modules\.bin;%PATH%"
)
SET "APPIUM_CMD="
IF EXIST "runtime\appium\node_modules\.bin\appium.cmd" (
    SET "APPIUM_CMD=%CD%\runtime\appium\node_modules\.bin\appium.cmd"
)
IF "%APPIUM_CMD%"=="" SET "APPIUM_CMD=appium"

REM -- [5] ADB device check (warn only -- does NOT block startup)
echo   Checking connected devices...
adb version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   WARN  ADB not found. Device check skipped.
    echo [run] WARN: adb not found >> "%LOG%"
    GOTO :start_appium
)
SET "_DEV_OK=0"
FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
    IF "%%S"=="device" SET "_DEV_OK=1"
)
IF "%_DEV_OK%"=="1" (
    echo   PASS  Android device connected and authorized.
    echo [run] device connected >> "%LOG%"
    GOTO :start_appium
)
echo.
echo   WARN  No Android device detected.
echo         Connect your phone via USB and enable USB Debugging.
echo         The web UI will still open. Connect the device before
echo         clicking "Start Test" in the browser.
echo.
echo [run] WARN: no device >> "%LOG%"

:start_appium
REM -- [6] Start Appium (skip if already on port 4723) ---------
echo.
echo   Checking Appium (port 4723)...
netstat -ano 2>nul | findstr ":4723" >nul
IF ERRORLEVEL 1 GOTO :launch_appium
echo   Appium already running on port 4723.
echo [run] Appium already on 4723 >> "%LOG%"
GOTO :start_web

:launch_appium
echo   Starting Appium server...
echo [run] Starting Appium >> "%LOG%"
start "SpatchEx - Appium" cmd /c "%APPIUM_CMD% --relaxed-security"
echo   Appium starting in background window.

:start_web
REM -- [7] Start web server + health-check browser opener ------
echo.
echo   Starting web server on port 5001...
echo [run] Starting web server >> "%LOG%"

REM Background health check: polls port 5001, opens browser only after server responds.
start "" /B powershell -NoProfile -ExecutionPolicy Bypass -Command "for($i=0;$i-lt30;$i++){try{(New-Object Net.WebClient).DownloadString('http://127.0.0.1:5001')|Out-Null;Start-Process 'http://127.0.0.1:5001';break}catch{Start-Sleep 1}}"

REM Web server runs in foreground -- keeps this window alive during the test.
echo   Browser will open automatically when the server is ready.
echo   Leave this window OPEN during the test.
echo.
REM -- Sleep prevention ----------------------------------------
SET "_SLEEP_PS1=%TEMP%\spatch_sleep_%_TS%.ps1"
SET "_SLEEP_PID_F=%TEMP%\spatch_sleep_%_TS%.pid"
echo $PID ^| Set-Content '%_SLEEP_PID_F%' > "%_SLEEP_PS1%"
echo Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);' -Name W32 -Namespace NW -ErrorAction SilentlyContinue >> "%_SLEEP_PS1%"
echo while ($true) { [NW.W32]::SetThreadExecutionState(0x80000001) ^| Out-Null; Start-Sleep 60 } >> "%_SLEEP_PS1%"
start "" /B powershell -NoProfile -ExecutionPolicy Bypass -File "%_SLEEP_PS1%"
ping 127.0.0.1 -n 2 >nul 2>&1
echo   Sleep prevention enabled during test run.
IF EXIST ".venv\Scripts\python.exe" (
    .venv\Scripts\python.exe web\app.py
) ELSE (
    python web\app.py
)

REM -- Server exited --------------------------------------------
echo.
echo [run] Web server exited >> "%LOG%"
REM Release sleep prevention
IF EXIST "%_SLEEP_PID_F%" (
    FOR /F "usebackq" %%P IN ("%_SLEEP_PID_F%") DO taskkill /PID %%P /F >nul 2>&1
    del "%_SLEEP_PS1%" 2>nul
    del "%_SLEEP_PID_F%" 2>nul
    echo   Sleep prevention released.
)
echo   Web server has stopped.
echo   Run STOP.bat to terminate any remaining services.
echo.
pause
EXIT /B 0
