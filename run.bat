@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul
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
echo   If issues occur, please send this log file:
echo   %LOG%
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

REM -- Bundled Node / Appium --
IF EXIST "runtime\node\node.exe" (
    SET "PATH=%CD%\runtime\node;%CD%\runtime\node\node_modules\.bin;%PATH%"
)
SET "APPIUM_CMD="
IF EXIST "runtime\appium\node_modules\.bin\appium.cmd" (
    SET "APPIUM_CMD=%CD%\runtime\appium\node_modules\.bin\appium.cmd"
    echo   Appium: packaged runtime found.
    echo [run] Appium command: %CD%\runtime\appium\node_modules\.bin\appium.cmd (packaged) >> "%LOG%"
) ELSE (
    SET "APPIUM_CMD=appium"
    echo   Appium: packaged runtime NOT found -- using global appium.
    echo [run] Appium command: appium (global fallback) >> "%LOG%"
)

REM -- [4a] Optional WiFi ADB auto-connect (SPATCH_DEVICE_IP) ----
IF NOT "%SPATCH_DEVICE_IP%"=="" (
    echo   Attempting WiFi connection to %SPATCH_DEVICE_IP%:5555 ...
    echo [run] Auto-connect to %SPATCH_DEVICE_IP%:5555 >> "%LOG%"
    adb connect %SPATCH_DEVICE_IP%:5555 >nul 2>&1
    ping 127.0.0.1 -n 3 >nul 2>&1
    SET "_WIFI_OK=0"
    FOR /F "skip=1 tokens=1,2" %%A IN ('adb devices 2^>nul') DO (
        IF "%%A"=="%SPATCH_DEVICE_IP%:5555" IF "%%B"=="device" SET "_WIFI_OK=1"
    )
    IF "!_WIFI_OK!"=="1" (
        echo   WiFi device connected: %SPATCH_DEVICE_IP%:5555
        echo [run] WiFi connected OK >> "%LOG%"
    ) ELSE (
        echo   WiFi connection failed: %SPATCH_DEVICE_IP%:5555
        echo [run] WiFi connect failed (non-blocking) >> "%LOG%"
        echo.
        echo   Hints:
        echo     - Make sure phone and PC are on the same WiFi network
        echo     - Verify USB Debugging is enabled on the device
        echo     - Confirm device IP: Settings ^> About phone ^> Status
    )
    echo.
)

REM -- [5] ADB device check (warn only -- does NOT block startup)
echo   Checking connected devices...
adb version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   WARN  ADB not found. Device check skipped.
    echo [run] WARN: adb not found >> "%LOG%"
    GOTO :start_appium
)
SET "_DEV_OK=0"
FOR /F "skip=1 tokens=1,2" %%A IN ('adb devices 2^>nul') DO (
    IF "%%B"=="device" SET "_DEV_OK=1"
)
IF "%_DEV_OK%"=="0" GOTO :no_usb_device

echo   PASS  Android device connected and authorized.
echo [run] device connected >> "%LOG%"
REM ── Prepare ADB over WiFi and save device IP (non-blocking) ──
echo   Preparing ADB over WiFi...
SET "_USB_SERIAL="
FOR /F "skip=1 tokens=1,2" %%A IN ('adb devices 2^>nul') DO (
    IF "%%B"=="device" (
        echo %%A| findstr ":" >nul 2>&1
        IF ERRORLEVEL 1 IF NOT DEFINED _USB_SERIAL SET "_USB_SERIAL=%%A"
    )
)
IF NOT DEFINED _USB_SERIAL GOTO :start_appium
SET "_WIFI_IP="
FOR /F "tokens=1-10" %%a IN ('adb -s "%_USB_SERIAL%" shell ip route 2^>nul') DO (
    IF "%%a"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%b"
    IF "%%b"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%c"
    IF "%%c"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%d"
    IF "%%d"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%e"
    IF "%%e"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%f"
    IF "%%f"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%g"
    IF "%%g"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%h"
    IF "%%h"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%i"
    IF "%%i"=="src" IF NOT DEFINED _WIFI_IP SET "_WIFI_IP=%%j"
)
echo   DEBUG USB SERIAL: %_USB_SERIAL%
echo   DEBUG WIFI IP: %_WIFI_IP%
echo   DEBUG SAVE PATH: %CD%\automation\runtime\adb_wifi_device.json
IF NOT DEFINED _WIFI_IP GOTO :start_appium
adb -s "%_USB_SERIAL%" tcpip 5555 >nul 2>&1
ping 127.0.0.1 -n 3 >nul 2>&1
adb connect %_WIFI_IP%:5555 >nul 2>&1
SET "_WIFI_CONN=0"
FOR /F "skip=1 tokens=1,2" %%A IN ('adb devices 2^>nul') DO (
    IF "%%A"=="%_WIFI_IP%:5555" IF "%%B"=="device" SET "_WIFI_CONN=1"
)
IF "!_WIFI_CONN!"=="1" (
    echo   WiFi device connected: %_WIFI_IP%:5555
    echo [run] WiFi connected OK >> "%LOG%"
) ELSE (
    echo   WiFi connection failed: %_WIFI_IP%:5555
    echo [run] WiFi connect failed (non-blocking) >> "%LOG%"
)
echo   Saved WiFi device IP: %_WIFI_IP%
echo [run] WiFi IP saved: %_WIFI_IP% >> "%LOG%"
IF NOT EXIST "automation\runtime" mkdir automation\runtime >nul 2>&1
powershell -NoProfile -Command ^
  "$ts=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ');" ^
  "$obj=[ordered]@{device_id='%_USB_SERIAL%';wifi_ip='%_WIFI_IP%';tcp_port=5555;updated_at=$ts};" ^
  "$obj | ConvertTo-Json -Compress | Set-Content -LiteralPath 'automation\runtime\adb_wifi_device.json'"
GOTO :start_appium

:no_usb_device
REM ── Try cached WiFi before showing warning ───────────────────
SET "_CACHED_ADDR="
IF EXIST "automation\runtime\adb_wifi_device.json" (
    FOR /F "usebackq tokens=*" %%C IN (`powershell -NoProfile -Command "try{$d=Get-Content 'automation\runtime\adb_wifi_device.json'^|ConvertFrom-Json;Write-Output($d.wifi_ip+':'+$d.tcp_port)}catch{}"`) DO SET "_CACHED_ADDR=%%C"
)
IF NOT DEFINED _CACHED_ADDR GOTO :show_no_device_warn
echo   Attempting saved WiFi ADB connection...
echo [run] Attempting cached WiFi: %_CACHED_ADDR% >> "%LOG%"
adb connect %_CACHED_ADDR% >nul 2>&1
ping 127.0.0.1 -n 3 >nul 2>&1
FOR /F "skip=1 tokens=1,2" %%A IN ('adb devices 2^>nul') DO (
    IF "%%A"=="%_CACHED_ADDR%" IF "%%B"=="device" SET "_DEV_OK=1"
)
IF "%_DEV_OK%"=="1" (
    echo   Saved WiFi device connected.
    echo [run] Cached WiFi connected OK >> "%LOG%"
    GOTO :start_appium
)
echo   Saved WiFi connection failed.
echo [run] Cached WiFi connect failed >> "%LOG%"

:show_no_device_warn
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
echo try { Add-Type -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);' -Name W32 -Namespace NW } catch {} >> "%_SLEEP_PS1%"
echo try { Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);' -Name U32 -Namespace NU } catch {} >> "%_SLEEP_PS1%"
echo while ($true) { $ok=$false; try { [NW.W32]::SetThreadExecutionState(0x80000003) ^| Out-Null; $ok=$true } catch {}; if (-not $ok) { try { [NU.U32]::mouse_event(1,0,0,0,0) } catch {} }; Start-Sleep 30 } >> "%_SLEEP_PS1%"
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
REM Stop Appium if started by this script
taskkill /FI "WINDOWTITLE eq SpatchEx - Appium*" /F >nul 2>&1
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
