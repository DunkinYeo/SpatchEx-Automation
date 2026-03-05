@echo off
REM ============================================================
REM SpatchEx Long-Run Test -- Windows Start
REM ============================================================
cd /d "%~dp0.."

REM ── PATH hardening ───────────────────────────────────────────
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"
SET "APPIUM_CMD=%APPDATA%\npm\appium.cmd"

REM ── Timestamp ────────────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T

REM ── Log folder ───────────────────────────────────────────────
IF NOT EXIST "artifacts\logs" mkdir "artifacts\logs"
SET "APPIUM_LOG=%TEMP%\spatch_appium_%_TS%.log"

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +==============================================+
echo   ^|   SpatchEx Long-Run Test -- Start           ^|
echo   +==============================================+
echo.

REM ============================================================
REM [1] Python
python --version >nul 2>&1
IF ERRORLEVEL 1 (
  echo   ERROR: Python not found. Run install\install.bat first.
  pause
  exit /b 1
)
FOR /F "tokens=*" %%v IN ('python --version 2^>^&1') DO echo   OK  %%v

REM ============================================================
REM [2] Virtual environment
IF NOT EXIST ".venv\Scripts\activate.bat" (
  echo   ERROR: Virtual environment not found.
  echo   Run install\install.bat first.
  pause
  exit /b 1
)
call .venv\Scripts\activate.bat
echo   OK  .venv activated

REM ============================================================
REM [3] Appium — explicit path, then PATH, then npx
SET APPIUM_RUN=
IF EXIST "%APPIUM_CMD%" (
  "%APPIUM_CMD%" -v >nul 2>&1
  IF NOT ERRORLEVEL 1 SET APPIUM_RUN=appium
)
IF "%APPIUM_RUN%"=="" (
  appium -v >nul 2>&1
  IF NOT ERRORLEVEL 1 SET APPIUM_RUN=appium
)
IF "%APPIUM_RUN%"=="" (
  SET "APPIUM_RUN=npx -y appium@3"
  npx -y appium@3 -v >nul 2>&1
  IF ERRORLEVEL 1 (
    echo   ERROR: Appium not found. Run install\install.bat first.
    pause
    exit /b 1
  )
)
FOR /F "tokens=*" %%v IN ('%APPIUM_RUN% -v 2^>nul') DO echo   OK  Appium %%v

REM ============================================================
REM [4] UiAutomator2 driver
SET "DRIVER_TMP=%TEMP%\appium_drivers_%_TS%.txt"
%APPIUM_RUN% driver list --installed > "%DRIVER_TMP%" 2>&1
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF ERRORLEVEL 1 (
  echo   ERROR: UiAutomator2 driver not installed.
  echo   Run: appium driver install uiautomator2
  pause
  exit /b 1
)
echo   OK  UiAutomator2 driver installed

REM ============================================================
REM [5] ADB device check (warning only — device may connect later)
echo.
echo   Connected Android devices:
adb devices 2>nul
SET DEVICE_FOUND=0
FOR /F "skip=1 tokens=2" %%S IN ('adb devices 2^>nul') DO (
  IF "%%S"=="device" SET DEVICE_FOUND=1
)
IF "%DEVICE_FOUND%"=="0" (
  echo.
  echo   WARNING: No authorized device detected.
  echo   Connect via USB and enable USB Debugging ^(allow on device^).
)
echo.

REM ============================================================
REM [6] Appium server — start in new window if not already running
netstat -an 2>nul | findstr ":4723" >nul 2>&1
IF NOT ERRORLEVEL 1 (
  echo   Appium already running on port 4723.
  GOTO :appium_running
)

REM Write a temp launcher so quoting is never an issue
SET "ALAUNCHER=%TEMP%\spatch_appium_%_TS%.bat"
(echo @echo off) > "%ALAUNCHER%"
(echo cd /d "%CD%") >> "%ALAUNCHER%"
(echo %APPIUM_RUN% --relaxed-security --log "%APPIUM_LOG%") >> "%ALAUNCHER%"
start "Appium Server" cmd /k "%ALAUNCHER%"

echo   Appium server starting...
echo   Log: %APPIUM_LOG%
timeout /t 3 /nobreak >nul

:appium_running

REM ============================================================
REM [7] Open browser + start Web UI in current window
start "" "http://127.0.0.1:5001"

echo   +==============================================+
echo   ^|   Web UI: http://127.0.0.1:5001            ^|
echo   ^|   Logs:   artifacts\logs\                  ^|
echo   ^|   Stop:   Ctrl+C  (close Appium window too)^|
echo   +==============================================+
echo.

python web\app.py
pause
