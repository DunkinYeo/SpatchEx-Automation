@echo off
setlocal
chcp 65001 >nul
cd /d "%~dp0"
REM ============================================================
REM SpatchEx -- Environment Setup
REM install.bat  (project root)
REM
REM  Run this ONCE before using run.bat.
REM  This script ONLY prepares the environment.
REM  It does NOT start any servers or run any tests.
REM
REM  Steps:
REM    [1] Verify Python 3.10+
REM    [2] Verify Node.js / npm
REM    [3] Android SDK Detection + ADB Validation
REM    [4] Install Appium (if missing)
REM    [5] Install UiAutomator2 driver (if missing)
REM    [6] Create Python virtual environment
REM    [7] pip install requirements.txt
REM    [Done] SpatchEx Automation Installed
REM ============================================================
REM Keep window open on double-click
IF "%INSTALL_RUNNING%"=="1" GOTO :run
SET INSTALL_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run

REM ── Verify project root ──────────────────────────────────────
IF EXIST "web\app.py" GOTO :root_ok
echo.
echo   ERROR: web\app.py not found.
echo   Run install.bat from inside the SpatchEx-Automation folder.
echo.
pause
EXIT /B 1
:root_ok
SET "PYTHON_EXE=python"

REM ── Timestamp + log ─────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_install_%_TS%.log"
echo SpatchEx install started %DATE% %TIME% > "%LOG%"

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +==============================================+
echo   ^|   SpatchEx -- Environment Setup             ^|
echo   +==============================================+
echo.
echo   Log: %LOG%
echo.

SET _FAIL=0

REM ============================================================
REM [1] Verify Python 3.10+
REM ============================================================
echo [1] Verify Python 3.10+...
python --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo.
    echo   ERROR  Python not found in PATH.
    echo.
    echo   Python 3.10 or later is required.
    echo   Download from: https://www.python.org/downloads/
    echo   During install: check "Add Python to PATH"
    echo.
    echo [1] FAIL: python not found >> "%LOG%"
    SET _FAIL=1
    GOTO :step2
)
SET "_PYVER="
FOR /F "tokens=2" %%v IN ('python --version 2^>^&1') DO SET "_PYVER=%%v"
SET "_PYMAJ=0"
SET "_PYMIN=0"
FOR /F "tokens=1 delims=." %%a IN ("%_PYVER%") DO SET "_PYMAJ=%%a"
FOR /F "tokens=2 delims=." %%a IN ("%_PYVER%") DO SET "_PYMIN=%%a"
IF %_PYMAJ% LSS 3 GOTO :py_old
IF %_PYMAJ% EQU 3 IF %_PYMIN% LSS 10 GOTO :py_old
echo   PASS  Python %_PYVER%
echo [1] PASS: Python %_PYVER% >> "%LOG%"
GOTO :step2

:py_old
echo.
echo   ERROR  Python %_PYVER% found, but 3.10 or later is required.
echo   Download from: https://www.python.org/downloads/
echo.
echo [1] FAIL: Python %_PYVER% too old >> "%LOG%"
SET _FAIL=1

:step2
REM ============================================================
REM [2] Verify Node.js / npm
REM ============================================================
echo.
echo [2] Verify Node.js / npm...
node --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo.
    echo   ERROR  Node.js not found in PATH.
    echo.
    echo   Node.js 18 LTS or later is required.
    echo   Download from: https://nodejs.org/  (choose LTS version)
    echo.
    echo [2] FAIL: node not found >> "%LOG%"
    SET _FAIL=1
    GOTO :step3
)
npm --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   WARN  Node.js found but npm not detected.
    echo   Reinstall Node.js from https://nodejs.org/
    echo [2] WARN: npm not found >> "%LOG%"
    GOTO :step3
)
FOR /F "tokens=*" %%v IN ('node --version 2^>^&1') DO echo   PASS  Node.js %%v
FOR /F "tokens=*" %%v IN ('npm --version 2^>^&1') DO echo   PASS  npm v%%v
echo [2] PASS >> "%LOG%"

REM ── Inject Node.js global paths so appium.cmd is findable ────
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

:step3
REM ============================================================
REM [3] Android SDK Detection + ADB Validation
REM
REM  Checks ANDROID_HOME, ANDROID_SDK_ROOT, and common paths.
REM  Sets ANDROID_HOME, ANDROID_SDK_ROOT, and PATH.
REM  Fails hard if SDK is not found -- Appium requires ADB.
REM ============================================================
echo.
echo [3] Android SDK detection...
echo [3] Checking Android SDK... >> "%LOG%"

SET "_SDK_FOUND=0"
SET "_SDK_PATH="

REM Priority 1: ANDROID_HOME already set and valid
IF NOT "%ANDROID_HOME%"=="" (
    IF EXIST "%ANDROID_HOME%\platform-tools\adb.exe" (
        SET "_SDK_PATH=%ANDROID_HOME%"
        SET "_SDK_FOUND=1"
        GOTO :sdk_found
    )
)

REM Priority 2: ANDROID_SDK_ROOT already set and valid
IF NOT "%ANDROID_SDK_ROOT%"=="" (
    IF EXIST "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
        SET "_SDK_PATH=%ANDROID_SDK_ROOT%"
        SET "_SDK_FOUND=1"
        GOTO :sdk_found
    )
)

REM Priority 3: %LOCALAPPDATA%\Android\Sdk (Android Studio default)
IF EXIST "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    SET "_SDK_PATH=%LOCALAPPDATA%\Android\Sdk"
    SET "_SDK_FOUND=1"
    GOTO :sdk_found
)

REM Priority 4: %USERPROFILE%\AppData\Local\Android\Sdk
IF EXIST "%USERPROFILE%\AppData\Local\Android\Sdk\platform-tools\adb.exe" (
    SET "_SDK_PATH=%USERPROFILE%\AppData\Local\Android\Sdk"
    SET "_SDK_FOUND=1"
    GOTO :sdk_found
)

echo.
echo   ERROR  Android SDK not found.
echo.
echo   Please install Android Studio or Android command-line tools.
echo   Download: https://developer.android.com/studio
echo.
echo   After installing, re-run install.bat.
echo.
echo [3] FAIL: Android SDK not found >> "%LOG%"
pause
EXIT /B 1

:sdk_found
SET "ANDROID_HOME=%_SDK_PATH%"
SET "ANDROID_SDK_ROOT=%_SDK_PATH%"
SET "PATH=%ANDROID_HOME%\platform-tools;%PATH%"

echo   Detected Android SDK:
echo   %ANDROID_HOME%
echo [3] SDK: %ANDROID_HOME% >> "%LOG%"

adb version >nul 2>&1
IF ERRORLEVEL 1 (
    echo.
    echo   ERROR  Android platform-tools missing or adb not executable.
    echo   Expected adb.exe at: %ANDROID_HOME%\platform-tools
    echo.
    echo [3] FAIL: adb not executable >> "%LOG%"
    pause
    EXIT /B 1
)
FOR /F "tokens=1,2,3" %%a IN ('adb version 2^>^&1 ^| findstr /i "android debug"') DO (
    echo   PASS  %%a %%b %%c
    echo [3] PASS: %%a %%b %%c >> "%LOG%"
)

:step4
REM ============================================================
REM [4] Install Appium (if missing)
REM
REM  NOTE: appium resolves to appium.cmd on Windows.
REM  All appium calls MUST use CALL or the parent script exits.
REM ============================================================
echo.
echo [4] Appium...
echo   Checking if Appium is installed...
echo [4] Checking appium... >> "%LOG%"

SET "_APV_TMP=%TEMP%\spatch_apv_%_TS%.txt"

REM IMPORTANT: use CALL so control returns after appium.cmd finishes
call appium -v > "%_APV_TMP%" 2>&1
IF ERRORLEVEL 1 GOTO :install_appium

REM Appium found -- read version from temp file
SET "_APPIUM_VER="
FOR /F "usebackq tokens=*" %%v IN ("%_APV_TMP%") DO (
    IF NOT DEFINED _APPIUM_VER SET "_APPIUM_VER=%%v"
)
del "%_APV_TMP%" >nul 2>&1
echo   PASS  Appium %_APPIUM_VER%
echo [4] PASS: Appium %_APPIUM_VER% >> "%LOG%"
GOTO :step5

:install_appium
del "%_APV_TMP%" >nul 2>&1
echo   Appium not found. Installing globally via npm...
echo   (This may take 1-3 minutes)
echo [4] Installing appium via npm... >> "%LOG%"

call npm install -g appium
IF ERRORLEVEL 1 (
    echo.
    echo   FAIL  npm install -g appium failed.
    echo.
    echo   Possible causes:
    echo     - Node.js is not installed or not in PATH
    echo     - npm permission error (try running as Administrator)
    echo.
    echo   Exact command tried: npm install -g appium
    echo   Full log: %LOG%
    echo.
    echo [4] FAIL: npm install -g appium >> "%LOG%"
    SET _FAIL=1
    GOTO :step5
)

REM Verify installation succeeded
echo   Verifying Appium installation...
call appium -v > "%_APV_TMP%" 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Appium was installed but appium -v still fails.
    echo         Close this window and re-run install.bat.
    echo   appium -v output:
    type "%_APV_TMP%" 2>nul
    echo   Full log: %LOG%
    echo [4] FAIL: post-install verify >> "%LOG%"
    del "%_APV_TMP%" >nul 2>&1
    SET _FAIL=1
    GOTO :step5
)
SET "_APPIUM_VER="
FOR /F "usebackq tokens=*" %%v IN ("%_APV_TMP%") DO (
    IF NOT DEFINED _APPIUM_VER SET "_APPIUM_VER=%%v"
)
del "%_APV_TMP%" >nul 2>&1
echo   PASS  Appium %_APPIUM_VER% installed.
echo [4] PASS: Appium %_APPIUM_VER% >> "%LOG%"

:step5
REM ============================================================
REM [5] Install UiAutomator2 driver (if missing)
REM ============================================================
echo.
echo [5] UiAutomator2 driver...
REM IMPORTANT: must use CALL -- appium is appium.cmd on Windows
call appium -v >nul 2>&1
IF ERRORLEVEL 1 (
    echo   SKIP  Appium unavailable -- skipping driver check.
    echo [5] SKIP >> "%LOG%"
    GOTO :step6
)
SET "_DRIVER_TMP=%TEMP%\spatch_drivers_%_TS%.txt"
call appium driver list --installed > "%_DRIVER_TMP%" 2>&1
findstr /i "uiautomator2" "%_DRIVER_TMP%" >nul 2>&1
IF ERRORLEVEL 1 GOTO :install_driver
echo   PASS  UiAutomator2 driver already installed.
echo [5] PASS >> "%LOG%"
del "%_DRIVER_TMP%" >nul 2>&1
GOTO :step6

:install_driver
del "%_DRIVER_TMP%" >nul 2>&1
echo   UiAutomator2 not found. Installing...
echo   (This may take 1-3 minutes)
echo [5] Installing uiautomator2... >> "%LOG%"
call appium driver install uiautomator2
IF ERRORLEVEL 1 (
    echo.
    echo   ERROR  Failed to install UiAutomator2 driver.
    echo   Try manually: appium driver install uiautomator2
    echo.
    echo [5] FAIL: driver install >> "%LOG%"
    SET _FAIL=1
    GOTO :step6
)
echo   PASS  UiAutomator2 driver installed.
echo [5] PASS >> "%LOG%"

:step6
REM ============================================================
REM [6] Create Python virtual environment
REM ============================================================
echo.
echo [6] Python virtual environment...
IF "%_FAIL%"=="1" (
    echo   SKIP  Skipping venv creation due to earlier errors.
    echo [6] SKIP: earlier failures >> "%LOG%"
    GOTO :step7
)
IF NOT EXIST "requirements.txt" (
    echo   ERROR  requirements.txt not found.
    echo [6] FAIL: requirements.txt missing >> "%LOG%"
    SET _FAIL=1
    GOTO :step7
)
IF EXIST ".venv\Scripts\activate.bat" (
    echo   INFO  .venv already exists. Skipping creation.
    GOTO :step7
)
echo   Creating .venv...
REM python.exe is a native executable -- do NOT use CALL
"%PYTHON_EXE%" -m venv .venv
IF ERRORLEVEL 1 (
    echo.
    echo   ERROR  Failed to create .venv.
    echo   Ensure Python 3.10+ is installed correctly.
    echo.
    echo [6] FAIL: venv create >> "%LOG%"
    SET _FAIL=1
    GOTO :step7
)
echo   PASS  .venv created.
echo [6] PASS >> "%LOG%"

:step7
REM ============================================================
REM [7] pip install requirements.txt
REM ============================================================
echo.
echo [7] pip install requirements.txt...
IF "%_FAIL%"=="1" (
    echo   SKIP  Skipping pip install due to earlier errors.
    echo [7] SKIP: earlier failures >> "%LOG%"
    GOTO :create_folders
)
REM Verify activate.bat exists before calling it
IF NOT EXIST ".venv\Scripts\activate.bat" (
    echo.
    echo   ERROR  .venv\Scripts\activate.bat not found.
    echo   Delete .venv and re-run install.bat.
    echo.
    echo [7] FAIL: activate.bat missing >> "%LOG%"
    SET _FAIL=1
    GOTO :create_folders
)
REM activate.bat is a batch script -- CALL is correct here
call .venv\Scripts\activate.bat
pip install -r requirements.txt --quiet
IF ERRORLEVEL 1 (
    echo.
    echo   ERROR  pip install failed.
    echo   Check your network connection and requirements.txt.
    echo.
    echo [7] FAIL: pip install >> "%LOG%"
    SET _FAIL=1
    GOTO :create_folders
)
echo   PASS  All packages installed.
echo [7] PASS >> "%LOG%"

:create_folders
REM ── Create required runtime folders ─────────────────────────
IF NOT EXIST "logs"    mkdir logs
IF NOT EXIST "runtime" mkdir runtime

REM ============================================================
REM Summary
REM ============================================================
echo.
echo SpatchEx install ended %DATE% %TIME% >> "%LOG%"

IF "%_FAIL%"=="1" (
    echo   +==============================================+
    echo   ^|   Setup encountered errors.                ^|
    echo   +==============================================+
    echo.
    echo   One or more steps failed. Fix the errors above and re-run install.bat.
    echo   Full log: %LOG%
    echo.
    pause
    EXIT /B 1
)

echo.
echo   ----------------------------------
echo   SpatchEx Automation Installed
echo   ----------------------------------
echo.
echo   Next step:
echo.
echo   Run:
echo   run.bat
echo.
echo   Full log: %LOG%
echo.
echo [DONE] >> "%LOG%"
pause
EXIT /B 0
