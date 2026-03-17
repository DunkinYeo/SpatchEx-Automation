@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"

REM SpatchEx -- WiFi Device Setup
REM run_wifi.bat  (project root)
REM Connect an Android device over WiFi (ADB TCP/IP), then launch the
REM standard automation environment (identical to run.bat).

REM -- Timestamp + log -----------------------------------------
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_wifi_%_TS%.log"
echo SpatchEx WiFi run started %DATE% %TIME% > "%LOG%"

REM -- Banner --------------------------------------------------
echo.
echo   +==============================================+
echo   ^|   SpatchEx -- WiFi Device Setup             ^|
echo   +==============================================+
echo.
echo   Log: %LOG%
echo.
echo   Before running this script, make sure:
echo     1. Your phone and this PC are on the SAME Wi-Fi network.
echo     2. USB Debugging is enabled on the phone.
echo     3. Run via USB at least once, then:
echo          adb tcpip 5555
echo        (or enable Wireless Debugging in Developer Options)
echo.

REM -- [0] Auto-connect via SPATCH_DEVICE_IP (optional) --------
IF NOT "%SPATCH_DEVICE_IP%"=="" (
    echo   Attempting WiFi ADB connection...
    echo [wifi] Auto-connect to %SPATCH_DEVICE_IP%:5555 >> "%LOG%"
    adb connect %SPATCH_DEVICE_IP%:5555 >nul 2>&1
    ping 127.0.0.1 -n 3 >nul 2>&1
    SET "_AUTO_OK=0"
    FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
        IF "%%S"=="device" SET "_AUTO_OK=1"
    )
    IF "%_AUTO_OK%"=="1" (
        echo   WiFi device connected.
        echo [wifi] Auto-connect OK >> "%LOG%"
    ) ELSE (
        echo   WiFi connection failed.
        echo [wifi] Auto-connect failed (non-blocking) >> "%LOG%"
    )
    echo.
)

REM -- [1] Prompt for IP:Port ----------------------------------
:prompt_ip
echo   Enter Android device IP:Port
echo   Example: 192.168.0.50:5555
echo.
set "WIFI_TARGET="
set /p WIFI_TARGET="  IP:Port > "
if "%WIFI_TARGET%"=="" (
    echo   ERROR: IP:Port cannot be empty. Please try again.
    echo.
    goto :prompt_ip
)

REM -- [2] Connect via ADB -------------------------------------
echo.
echo   Connecting to %WIFI_TARGET%...
echo [wifi] Connecting to %WIFI_TARGET% >> "%LOG%"
adb connect %WIFI_TARGET%
echo.

REM -- [3] Verify device is authorized -------------------------
SET "_DEV_OK=0"
FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
    IF "%%S"=="device" SET "_DEV_OK=1"
)

IF "%_DEV_OK%"=="1" (
    echo   PASS  Device connected and authorized.
    echo [wifi] Device connected OK >> "%LOG%"
) ELSE (
    echo.
    echo   ERROR  Device not connected or not authorized.
    echo.
    echo   Troubleshooting:
    echo     - Check the IP address is correct
    echo     - Tap "Allow" on the phone if prompted
    echo     - Make sure adb tcpip 5555 was run while USB was connected
    echo     - Try again or use run.bat for USB connection
    echo.
    echo [wifi] FAIL: device not authorized >> "%LOG%"
    pause
    EXIT /B 1
)

REM -- [4] Launch standard automation environment --------------
echo.
echo   Launching automation environment...
echo   (Handing off to run.bat)
echo.
echo [wifi] Calling run.bat >> "%LOG%"
call run.bat

EXIT /B 0
