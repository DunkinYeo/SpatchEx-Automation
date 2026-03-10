@echo off
setlocal
cd /d "%~dp0"

SET "LOG=%TEMP%\spatch_install.log"
SET FAILED=0
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

echo SpatchEx install started > "%LOG%"

echo.
echo   SpatchEx -- Windows Setup
echo.
echo   Log: %LOG%
echo.

REM ============================================================
REM [1/6] Python
REM ============================================================
echo [1/6] Python...
python --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Python not found in PATH.
    echo   Download Python 3.10+ from https://www.python.org/downloads/
    echo   Enable "Add Python to PATH" during install.
    echo [1/6] FAIL >> "%LOG%"
    SET FAILED=1
    GOTO :step2
)
FOR /F "tokens=*" %%v IN ('python --version 2^>^&1') DO echo   PASS  %%v
echo [1/6] PASS >> "%LOG%"

REM ============================================================
REM [2/6] Node.js / npm
REM ============================================================
:step2
echo.
echo [2/6] Node.js / npm...
node --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Node.js not found in PATH.
    echo   Download Node.js LTS from https://nodejs.org/
    echo [2/6] FAIL node >> "%LOG%"
    SET FAILED=1
    GOTO :step3
)
FOR /F "tokens=*" %%v IN ('node --version 2^>^&1') DO echo   PASS  Node.js %%v
npm --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  npm not found. Reinstall Node.js from https://nodejs.org/
    echo [2/6] FAIL npm >> "%LOG%"
    SET FAILED=1
    GOTO :step3
)
FOR /F "tokens=*" %%v IN ('npm --version 2^>^&1') DO echo   PASS  npm v%%v
echo [2/6] PASS >> "%LOG%"

REM ============================================================
REM [3/6] ADB (Android Debug Bridge)
REM ============================================================
:step3
echo.
echo [3/6] ADB...
adb version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  ADB not found in PATH.
    echo   Install Android Studio or download platform-tools:
    echo   https://developer.android.com/tools/releases/platform-tools
    echo [3/6] FAIL >> "%LOG%"
    SET FAILED=1
    GOTO :step4
)
FOR /F "tokens=1,2,3" %%a IN ('adb version 2^>^&1 ^| findstr /i "android debug"') DO (
    echo   PASS  %%a %%b %%c
)
echo [3/6] PASS >> "%LOG%"

REM ============================================================
REM [4/6] Appium
REM ============================================================
:step4
echo.
echo [4/6] Appium...
echo [4/6] Appium >> "%LOG%"

SET "_APV_TMP=%TEMP%\spatch_apv.txt"
call appium -v > "%_APV_TMP%" 2>&1
IF ERRORLEVEL 1 GOTO :install_appium

SET "_AV="
FOR /F "usebackq tokens=*" %%v IN ("%_APV_TMP%") DO (
    IF NOT DEFINED _AV SET "_AV=%%v"
)
del "%_APV_TMP%" >nul 2>&1
echo   PASS  Appium %_AV%
echo [4/6] PASS: Appium %_AV% >> "%LOG%"
GOTO :step5

:install_appium
del "%_APV_TMP%" >nul 2>&1
echo   Appium not found. Installing via npm...
echo   This may take 2-5 minutes. Please wait.
echo [4/6] Installing appium... >> "%LOG%"
call npm i --location=global appium
IF ERRORLEVEL 1 (
    echo   FAIL  npm install appium failed.
    echo   Try running install.bat as Administrator.
    echo [4/6] FAIL install >> "%LOG%"
    SET FAILED=1
    GOTO :step5
)
call appium -v > "%_APV_TMP%" 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  appium -v failed after install.
    echo   Close this window and re-run install.bat.
    echo [4/6] FAIL verify >> "%LOG%"
    del "%_APV_TMP%" >nul 2>&1
    SET FAILED=1
    GOTO :step5
)
SET "_AV="
FOR /F "usebackq tokens=*" %%v IN ("%_APV_TMP%") DO (
    IF NOT DEFINED _AV SET "_AV=%%v"
)
del "%_APV_TMP%" >nul 2>&1
echo   PASS  Appium %_AV% installed.
echo [4/6] PASS: installed >> "%LOG%"

REM ============================================================
REM [5/6] UiAutomator2 driver
REM ============================================================
:step5
echo.
echo [5/6] UiAutomator2 driver...
echo [5/6] UiAutomator2 >> "%LOG%"

SET "_DRV_TMP=%TEMP%\spatch_drv.txt"
call appium driver list --installed > "%_DRV_TMP%" 2>&1
findstr /i "uiautomator2" "%_DRV_TMP%" >nul 2>&1
IF ERRORLEVEL 1 GOTO :install_uia2

echo   PASS  UiAutomator2 driver already installed.
echo [5/6] PASS >> "%LOG%"
del "%_DRV_TMP%" >nul 2>&1
GOTO :step6

:install_uia2
del "%_DRV_TMP%" >nul 2>&1
echo   UiAutomator2 not found. Installing...
echo   This may take 1-3 minutes. Please wait.
echo [5/6] Installing uiautomator2... >> "%LOG%"
call appium driver install uiautomator2
IF ERRORLEVEL 1 (
    echo   FAIL  UiAutomator2 install failed.
    echo   Try manually: appium driver install uiautomator2
    echo [5/6] FAIL >> "%LOG%"
    SET FAILED=1
    GOTO :step6
)
echo   PASS  UiAutomator2 driver installed.
echo [5/6] PASS >> "%LOG%"

REM ============================================================
REM [6/6] Python packages
REM ============================================================
:step6
echo.
echo [6/6] Python packages...
echo [6/6] Python packages >> "%LOG%"

IF NOT EXIST ".venv" (
    echo   Creating virtual environment...
    python -m venv .venv
    IF ERRORLEVEL 1 (
        echo   FAIL  Could not create .venv.
        echo [6/6] FAIL venv create >> "%LOG%"
        SET FAILED=1
        GOTO :summary
    )
)

IF NOT EXIST ".venv\Scripts\activate.bat" (
    echo   FAIL  .venv\Scripts\activate.bat missing.
    echo   Delete .venv and re-run install.bat.
    echo [6/6] FAIL activate missing >> "%LOG%"
    SET FAILED=1
    GOTO :summary
)

call .venv\Scripts\activate.bat
echo   Installing packages from requirements.txt...
pip install -r requirements.txt
IF ERRORLEVEL 1 (
    echo   FAIL  pip install failed. Check your network connection.
    echo [6/6] FAIL pip >> "%LOG%"
    SET FAILED=1
    GOTO :summary
)
echo   PASS  Packages installed.
echo [6/6] PASS >> "%LOG%"

IF NOT EXIST "logs"    mkdir logs
IF NOT EXIST "runtime" mkdir runtime

:summary
echo.
IF "%FAILED%"=="1" (
    echo   Setup encountered errors.
    echo   Review the messages above, then re-run install.bat.
    echo   Full log: %LOG%
    echo.
    pause
    EXIT /B 1
)
echo   ========================
echo   Setup complete.
echo   Run run.bat to start.
echo   ========================
echo.
echo   Full log: %LOG%
echo.
pause
EXIT /B 0
