@echo off
setlocal
cd /d "%~dp0"

SET "LOG=%TEMP%\spatch_install.log"
SET FAILED=0
SET "PYTHON_EXE=python"
REM Pre-load well-known tool paths so freshly installed tools are found
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

echo DEBUG: LOG=%LOG%
echo SpatchEx install started > "%LOG%"

echo.
echo   SpatchEx -- Windows Setup
echo.
echo   Log: %LOG%
echo.

REM ============================================================
REM [1/6] Python
REM ============================================================
echo DEBUG: entering step1
echo [1/6] Python...
python --version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    echo   PASS  Python
    echo [1/6] PASS >> "%LOG%"
    SET "PYTHON_EXE=python"
    GOTO :step2
)

echo   Python not found. Attempting automatic install via winget...
echo [1/6] Installing Python via winget... >> "%LOG%"
winget --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  winget not available on this machine.
    echo   Manual: Download Python 3.10+ from https://www.python.org/downloads/
    echo          Enable "Add Python to PATH" during install, then re-run install.bat.
    echo [1/6] FAIL winget missing >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step2
)
winget install -e --id Python.Python.3.12 --silent --accept-package-agreements --accept-source-agreements
IF ERRORLEVEL 1 (
    echo   WARN  winget install failed.
    echo   Manual: Download Python 3.10+ from https://www.python.org/downloads/
    echo          Enable "Add Python to PATH" during install, then re-run install.bat.
    echo [1/6] FAIL winget >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step2
)

REM Dynamically detect Python install directory
REM (winget does not refresh PATH in the current CMD session)
SET "_PYDIR="

REM Method 1: scan %LOCALAPPDATA%\Programs\Python for latest Python3x folder
FOR /F "usebackq tokens=*" %%P IN (`powershell -NoProfile -Command "try { Get-ChildItem ([System.Environment]::GetFolderPath('LocalApplicationData') + '\Programs\Python') -Filter 'Python3*' -ErrorAction Stop | Sort-Object Name -Descending | Select-Object -First 1 -ExpandProperty FullName } catch { '' }" 2^>nul`) DO SET "_PYDIR=%%P"

REM Method 2: fallback -- ask PowerShell where python.exe is already visible
IF NOT DEFINED _PYDIR (
    FOR /F "usebackq tokens=*" %%P IN (`powershell -NoProfile -Command "try { Split-Path -Parent (Get-Command python).Source } catch { '' }" 2^>nul`) DO SET "_PYDIR=%%P"
)

IF NOT DEFINED _PYDIR (
    echo   FAIL  Python installed but install directory not detected.
    echo   Close this window, open a new Command Prompt, and re-run install.bat.
    echo [1/6] FAIL path >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step2
)

SET "PATH=%_PYDIR%;%_PYDIR%\Scripts;%PATH%"
echo   Found Python at: %_PYDIR%

REM Verify Python works -- try PATH first, then direct exe path
python --version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    SET "PYTHON_EXE=python"
    GOTO :python_ready
)

REM PATH not refreshed yet in this session -- invoke python.exe directly
"%_PYDIR%\python.exe" --version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    SET "PYTHON_EXE=%_PYDIR%\python.exe"
    GOTO :python_ready
)

echo   FAIL  Python not responding after PATH update.
echo   Close this window, open a new Command Prompt, and re-run install.bat.
echo [1/6] FAIL verify >> "%LOG%"
pause
SET FAILED=1
GOTO :step2

:python_ready
echo   PASS  Python installed.
echo [1/6] PASS installed >> "%LOG%"

REM ============================================================
REM [2/6] Node.js / npm
REM ============================================================
:step2
echo DEBUG: entering step2
echo.
echo [2/6] Node.js / npm...
node --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :install_node
npm --version >nul 2>&1
IF ERRORLEVEL 1 GOTO :install_node

echo   PASS  Node.js
echo   PASS  npm
echo [2/6] PASS >> "%LOG%"
GOTO :step3

:install_node
echo   Node.js not found. Attempting automatic install via winget...
echo [2/6] Installing Node.js via winget... >> "%LOG%"
winget --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  winget not available on this machine.
    echo   Manual: Download Node.js LTS from https://nodejs.org/
    echo          Then re-run install.bat.
    echo [2/6] FAIL winget missing >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step3
)
winget install -e --id OpenJS.NodeJS.LTS --silent --accept-package-agreements --accept-source-agreements
IF ERRORLEVEL 1 (
    echo   WARN  winget install failed.
    echo   Manual: Download Node.js LTS from https://nodejs.org/
    echo          Then re-run install.bat.
    echo [2/6] FAIL winget >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step3
)

REM Refresh PATH with Node.js install location
SET "PATH=%ProgramFiles%\nodejs;%APPDATA%\npm;%PATH%"

node --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  Node.js installed but not found in PATH yet.
    echo   Close this window, open a new Command Prompt, and re-run install.bat.
    echo [2/6] FAIL path >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step3
)
npm --version >nul 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  npm not found after Node.js install.
    echo   Close this window, open a new Command Prompt, and re-run install.bat.
    echo [2/6] FAIL npm >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step3
)
echo   PASS  Node.js installed.
echo   PASS  npm
echo [2/6] PASS installed >> "%LOG%"

REM ============================================================
REM [3/6] ADB (Android platform-tools)
REM ============================================================
:step3
echo DEBUG: entering step3
echo.
echo [3/6] ADB...

REM Check if bundled runtime\platform-tools exists (previous install or manual extract)
IF EXIST "runtime\platform-tools\adb.exe" (
    SET "PATH=%CD%\runtime\platform-tools;%PATH%"
)

adb version >nul 2>&1
IF NOT ERRORLEVEL 1 (
    echo   PASS  ADB ready
    echo [3/6] PASS >> "%LOG%"
    GOTO :step4
)

echo   ADB not found. Downloading Android platform-tools...
echo [3/6] Downloading platform-tools... >> "%LOG%"

IF NOT EXIST "runtime" mkdir runtime
SET "_PTZIP=%TEMP%\spatch_pt.zip"

powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile '%_PTZIP%' -UseBasicParsing"
IF ERRORLEVEL 1 (
    echo   FAIL  Download failed. Check your internet connection.
    echo   Manual: https://developer.android.com/tools/releases/platform-tools
    echo          Extract to runtime\platform-tools, then re-run install.bat.
    echo [3/6] FAIL download >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step4
)

echo   Extracting platform-tools...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%_PTZIP%' -DestinationPath 'runtime' -Force"
IF ERRORLEVEL 1 (
    echo   FAIL  Extraction failed.
    echo [3/6] FAIL extract >> "%LOG%"
    del "%TEMP%\spatch_pt.zip" >nul 2>&1
    pause
    SET FAILED=1
    GOTO :step4
)
del "%_PTZIP%" >nul 2>&1

IF NOT EXIST "runtime\platform-tools\adb.exe" (
    echo   FAIL  adb.exe not found after extraction.
    echo [3/6] FAIL adb.exe missing >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step4
)

SET "PATH=%CD%\runtime\platform-tools;%PATH%"
echo   PASS  ADB installed to runtime\platform-tools
echo [3/6] PASS installed >> "%LOG%"

REM ============================================================
REM [4/6] Appium
REM ============================================================
:step4
echo DEBUG: entering step4
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
call npm install -g appium
IF ERRORLEVEL 1 (
    echo   FAIL  npm install appium failed.
    echo   Try running install.bat as Administrator.
    echo [4/6] FAIL install >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :step5
)
call appium -v > "%_APV_TMP%" 2>&1
IF ERRORLEVEL 1 (
    echo   FAIL  appium -v failed after install.
    echo   Close this window and re-run install.bat.
    echo [4/6] FAIL verify >> "%LOG%"
    del "%_APV_TMP%" >nul 2>&1
    pause
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
echo DEBUG: entering step5
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
    pause
    SET FAILED=1
    GOTO :step6
)
echo   PASS  UiAutomator2 driver installed.
echo [5/6] PASS >> "%LOG%"

REM ============================================================
REM [6/6] Python packages
REM ============================================================
:step6
echo DEBUG: entering step6
echo DEBUG: PYTHON_EXE=%PYTHON_EXE%
echo.
echo [6/6] Python packages...
echo [6/6] Python packages >> "%LOG%"

IF NOT EXIST ".venv" (
    echo   Creating virtual environment...
    "%PYTHON_EXE%" -m venv .venv
    IF ERRORLEVEL 1 (
        echo   FAIL  Could not create .venv.
        echo [6/6] FAIL venv create >> "%LOG%"
        pause
        SET FAILED=1
        GOTO :summary
    )
)

IF NOT EXIST ".venv\Scripts\activate.bat" (
    echo   FAIL  .venv\Scripts\activate.bat missing.
    echo   Delete .venv and re-run install.bat.
    echo [6/6] FAIL activate missing >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :summary
)

echo DEBUG: using venv python for package install
echo   Upgrading pip inside venv...
.venv\Scripts\python.exe -m pip install --upgrade pip
IF ERRORLEVEL 1 (
    echo   FAIL  pip upgrade failed.
    echo [6/6] FAIL pip upgrade >> "%LOG%"
    pause
    SET FAILED=1
    GOTO :summary
)
echo   Installing packages from requirements.txt...
.venv\Scripts\python.exe -m pip install -r requirements.txt
IF ERRORLEVEL 1 (
    echo   FAIL  pip install failed. Check your network connection.
    echo [6/6] FAIL pip >> "%LOG%"
    pause
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
