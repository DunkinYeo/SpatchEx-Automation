@echo off
REM ============================================================
REM SpatchEx -- Local Runtime Bootstrap
REM install\bootstrap.bat
REM
REM  !! FOR DEVELOPERS AND IT ADMINS ONLY !!
REM  CS/UAT staff: do NOT run this.  Use start.bat instead.
REM
REM  Purpose:
REM    Downloads and installs all required runtimes into the
REM    local runtime\ folder so the tool runs without any
REM    global Python/Node/Appium/Android SDK installation.
REM
REM  After this script finishes successfully:
REM    - runtime\python\       Python 3.12 embeddable + pip packages
REM    - runtime\node\         Node.js 22 LTS portable
REM    - runtime\appium\       Appium + UiAutomator2 driver
REM    - runtime\android-sdk\  Android Platform Tools (adb.exe)
REM    - runtime\.ready        Sentinel: bootstrap is complete
REM
REM  Run once per machine, or delete runtime\.ready and re-run
REM  to refresh all runtimes.
REM ============================================================
REM Keep window open on double-click
IF "%BOOTSTRAP_RUNNING%"=="1" GOTO :run
SET BOOTSTRAP_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0.."
SET "ROOT=%CD%"

REM ── Verify project root ──────────────────────────────────────
IF EXIST "web\app.py" GOTO :root_ok
echo.
echo   ERROR: Must be run from inside the Ex-Automation folder.
echo   Move install\bootstrap.bat and run it from the project root.
echo.
pause
EXIT /B 1
:root_ok

REM ── Versioned download URLs (update here when upgrading) ─────
SET "PY_VER=3.12.9"
SET "PY_URL=https://www.python.org/ftp/python/3.12.9/python-3.12.9-embed-amd64.zip"
SET "NODE_VER=22.14.0"
SET "NODE_URL=https://nodejs.org/dist/v22.14.0/node-v22.14.0-win-x64.zip"
SET "NODE_DIR=node-v22.14.0-win-x64"
SET "PTOOL_URL=https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
SET "GETPIP_URL=https://bootstrap.pypa.io/get-pip.py"

REM ── Timestamp + log ─────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_bootstrap_%_TS%.log"
echo SpatchEx bootstrap started %DATE% %TIME% > "%LOG%"

SET BOOT_FAILED=0

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   SpatchEx -- Local Runtime Bootstrap             ^|
echo   ^|   FOR ADMIN / DEVELOPER USE ONLY                  ^|
echo   +====================================================+
echo.
echo   This will download and install:
echo     Python %PY_VER% embeddable
echo     Node.js %NODE_VER% LTS portable
echo     Appium + UiAutomator2 driver
echo     Android Platform Tools (adb)
echo.
echo   Download size: ~100 MB
echo   Install size:  ~350 MB
echo   Log: %LOG%
echo.

REM ── Check for existing runtime ───────────────────────────────
IF NOT EXIST "runtime\.ready" GOTO :start_bootstrap
echo   Found existing runtime\.ready
echo.
echo   The runtime folder already exists. Re-running will
echo   overwrite all downloaded components.
echo.
echo   Press any key to continue, or close this window to cancel.
pause >nul
echo.

:start_bootstrap
IF NOT EXIST "runtime" mkdir "runtime"
IF NOT EXIST "runtime\_dl" mkdir "runtime\_dl"
echo [boot] Starting %DATE% %TIME% >> "%LOG%"

REM ============================================================
REM [1] Python 3.12 embeddable
REM ============================================================
echo [1/5] Python %PY_VER% embeddable...
echo [1/5] Python %PY_VER% >> "%LOG%"

IF EXIST "runtime\python\python.exe" (
    echo   Already present -- skipping download.
    echo [1/5] skip (already present) >> "%LOG%"
    GOTO :step2
)

echo   Downloading Python %PY_VER% embeddable (~11 MB)...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%PY_URL%' -OutFile 'runtime\_dl\python.zip' -UseBasicParsing"
IF ERRORLEVEL 1 GOTO :py_dl_fail

echo   Extracting...
IF EXIST "runtime\python" rmdir /S /Q "runtime\python"
powershell -NoProfile -Command "Expand-Archive -Path 'runtime\_dl\python.zip' -DestinationPath 'runtime\python' -Force"
IF ERRORLEVEL 1 GOTO :py_ex_fail
del "runtime\_dl\python.zip" >nul 2>&1

REM Enable site-packages by uncommenting "import site" in the _pth file
echo   Enabling site-packages...
powershell -NoProfile -Command "Get-ChildItem 'runtime\python' -Filter '*._pth' | ForEach-Object { (Get-Content $_.FullName) -replace '#import site','import site' | Set-Content $_.FullName }"

REM Install pip into embeddable Python
echo   Installing pip...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%GETPIP_URL%' -OutFile 'runtime\_dl\get-pip.py' -UseBasicParsing"
IF ERRORLEVEL 1 GOTO :pip_dl_fail
"runtime\python\python.exe" "runtime\_dl\get-pip.py" --no-warn-script-location >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :pip_inst_fail
del "runtime\_dl\get-pip.py" >nul 2>&1
echo   OK  Python + pip installed
echo [1/5] OK >> "%LOG%"
GOTO :step2

:py_dl_fail
echo   ERROR: Failed to download Python. Check your internet connection.
echo [1/5] FAIL: download >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:py_ex_fail
echo   ERROR: Failed to extract Python ZIP.
echo [1/5] FAIL: extract >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:pip_dl_fail
echo   ERROR: Failed to download get-pip.py.
echo [1/5] FAIL: get-pip download >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:pip_inst_fail
echo   ERROR: pip installation failed. See log: %LOG%
echo [1/5] FAIL: pip install >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

REM ============================================================
REM [2] Python packages (requirements.txt)
REM ============================================================
:step2
echo.
echo [2/5] Python packages (requirements.txt)...
echo [2/5] pip install requirements >> "%LOG%"

IF NOT EXIST "requirements.txt" GOTO :req_missing
"runtime\python\python.exe" -m pip install -r requirements.txt --no-warn-script-location >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :req_fail
echo   OK  Packages installed
echo [2/5] OK >> "%LOG%"
GOTO :step3

:req_missing
echo   WARNING: requirements.txt not found -- skipping pip install.
echo [2/5] WARNING: no requirements.txt >> "%LOG%"
GOTO :step3

:req_fail
echo   ERROR: pip install -r requirements.txt failed. See log: %LOG%
echo [2/5] FAIL >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

REM ============================================================
REM [3] Node.js 22 LTS portable
REM ============================================================
:step3
echo.
echo [3/5] Node.js %NODE_VER% LTS portable...
echo [3/5] Node.js %NODE_VER% >> "%LOG%"

IF EXIST "runtime\node\node.exe" (
    echo   Already present -- skipping download.
    echo [3/5] skip (already present) >> "%LOG%"
    GOTO :step4
)

echo   Downloading Node.js %NODE_VER% (~34 MB)...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%NODE_URL%' -OutFile 'runtime\_dl\node.zip' -UseBasicParsing"
IF ERRORLEVEL 1 GOTO :node_dl_fail

echo   Extracting...
IF EXIST "runtime\_dl\node_ex" rmdir /S /Q "runtime\_dl\node_ex"
powershell -NoProfile -Command "Expand-Archive -Path 'runtime\_dl\node.zip' -DestinationPath 'runtime\_dl\node_ex' -Force"
IF ERRORLEVEL 1 GOTO :node_ex_fail

REM Move the versioned subfolder to runtime\node\
IF EXIST "runtime\node" rmdir /S /Q "runtime\node"
powershell -NoProfile -Command "$sub = (Get-ChildItem 'runtime\_dl\node_ex' | Where-Object {$_.PSIsContainer} | Select-Object -First 1).FullName; Move-Item $sub 'runtime\node' -Force"
IF ERRORLEVEL 1 GOTO :node_mv_fail

del "runtime\_dl\node.zip" >nul 2>&1
rmdir /S /Q "runtime\_dl\node_ex" >nul 2>&1
echo   OK  Node.js %NODE_VER% installed at runtime\node\
echo [3/5] OK >> "%LOG%"
GOTO :step4

:node_dl_fail
echo   ERROR: Failed to download Node.js. Check your internet connection.
echo [3/5] FAIL: download >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:node_ex_fail
echo   ERROR: Failed to extract Node.js ZIP.
echo [3/5] FAIL: extract >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:node_mv_fail
echo   ERROR: Failed to move Node.js folder to runtime\node\.
echo [3/5] FAIL: move >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

REM ============================================================
REM [4] Appium + UiAutomator2 driver
REM ============================================================
:step4
echo.
echo [4/5] Appium + UiAutomator2 driver...
echo [4/5] Appium >> "%LOG%"

SET "NODE_EXE=%ROOT%\runtime\node\node.exe"
SET "NPM_CMD=%ROOT%\runtime\node\npm.cmd"
SET "APPIUM_PREFIX=%ROOT%\runtime\appium"
SET "APPIUM_BIN=%APPIUM_PREFIX%\node_modules\.bin\appium.cmd"
SET "NPM_CONFIG_CACHE=%ROOT%\runtime\_npm_cache"

IF EXIST "%APPIUM_BIN%" (
    echo   Appium already installed -- skipping.
    echo [4/5] skip appium (already installed) >> "%LOG%"
    GOTO :uia2_check
)

IF NOT EXIST "%NPM_CMD%" GOTO :npm_missing

echo   Installing Appium (this can take 2-5 minutes)...
echo   (Downloading ~150 MB of packages)
IF NOT EXIST "%APPIUM_PREFIX%" mkdir "%APPIUM_PREFIX%"
call "%NPM_CMD%" --prefix "%APPIUM_PREFIX%" install appium >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :appium_fail

IF NOT EXIST "%APPIUM_BIN%" GOTO :appium_bin_missing
echo   OK  Appium installed
echo [4/5] appium install OK >> "%LOG%"

:uia2_check
echo   Checking UiAutomator2 driver...
SET "PATH=%ROOT%\runtime\node;%PATH%"
SET "DRIVER_TMP=%TEMP%\boot_drivers_%_TS%.txt"
call "%APPIUM_BIN%" driver list --installed > "%DRIVER_TMP%" 2>&1
findstr /i "uiautomator2" "%DRIVER_TMP%" >nul 2>&1
IF NOT ERRORLEVEL 1 (
    echo   OK  UiAutomator2 already installed
    echo [4/5] UiAutomator2 already installed >> "%LOG%"
    GOTO :step5
)

echo   Installing UiAutomator2 driver (this can take a few minutes)...
call "%APPIUM_BIN%" driver install uiautomator2 >> "%LOG%" 2>&1
IF ERRORLEVEL 1 GOTO :uia2_fail
echo   OK  UiAutomator2 installed
echo [4/5] OK >> "%LOG%"
GOTO :step5

:npm_missing
echo   ERROR: runtime\node\npm.cmd not found. Complete step [3] first.
echo [4/5] FAIL: npm missing >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:appium_fail
echo   ERROR: npm install appium failed. See log: %LOG%
echo [4/5] FAIL: npm install appium >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:appium_bin_missing
echo   ERROR: appium.cmd not found after install. See log: %LOG%
echo   Expected: %APPIUM_BIN%
echo [4/5] FAIL: appium.cmd not found >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:uia2_fail
echo   ERROR: UiAutomator2 install failed. See log: %LOG%
echo [4/5] FAIL: uiautomator2 >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

REM ============================================================
REM [5] Android Platform Tools (adb.exe)
REM     Extracted to runtime\android-sdk\ so ANDROID_HOME works.
REM     ZIP already contains platform-tools\ as top-level folder.
REM ============================================================
:step5
echo.
echo [5/5] Android Platform Tools (adb)...
echo [5/5] Platform Tools >> "%LOG%"

IF EXIST "runtime\android-sdk\platform-tools\adb.exe" (
    echo   Already present -- skipping download.
    echo [5/5] skip (already present) >> "%LOG%"
    GOTO :all_done
)

echo   Downloading Android Platform Tools (~12 MB)...
powershell -NoProfile -Command "Invoke-WebRequest -Uri '%PTOOL_URL%' -OutFile 'runtime\_dl\platform-tools.zip' -UseBasicParsing"
IF ERRORLEVEL 1 GOTO :ptool_dl_fail

echo   Extracting to runtime\android-sdk\ ...
IF NOT EXIST "runtime\android-sdk" mkdir "runtime\android-sdk"
powershell -NoProfile -Command "Expand-Archive -Path 'runtime\_dl\platform-tools.zip' -DestinationPath 'runtime\android-sdk' -Force"
IF ERRORLEVEL 1 GOTO :ptool_ex_fail
del "runtime\_dl\platform-tools.zip" >nul 2>&1

IF NOT EXIST "runtime\android-sdk\platform-tools\adb.exe" GOTO :ptool_adb_missing
echo   OK  adb.exe ready at runtime\android-sdk\platform-tools\
echo [5/5] OK >> "%LOG%"
GOTO :all_done

:ptool_dl_fail
echo   ERROR: Failed to download Platform Tools. Check internet connection.
echo [5/5] FAIL: download >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:ptool_ex_fail
echo   ERROR: Failed to extract Platform Tools ZIP.
echo [5/5] FAIL: extract >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

:ptool_adb_missing
echo   ERROR: adb.exe not found after extraction.
echo   Expected: runtime\android-sdk\platform-tools\adb.exe
echo [5/5] FAIL: adb.exe missing >> "%LOG%"
SET BOOT_FAILED=1
GOTO :done_tail

REM ============================================================
REM All done -- create .ready sentinel + cleanup
REM ============================================================
:all_done
echo.
echo   Cleaning up download cache...
IF EXIST "runtime\_dl" rmdir /S /Q "runtime\_dl" >nul 2>&1
IF EXIST "runtime\_npm_cache" rmdir /S /Q "runtime\_npm_cache" >nul 2>&1

echo SpatchEx bootstrap completed OK %DATE% %TIME% >> "%LOG%"
echo 1 > "runtime\.ready"

echo.
echo   +====================================================+
echo   ^|   Bootstrap COMPLETE                              ^|
echo   +====================================================+
echo.
echo   Runtime installed at: %ROOT%\runtime\
echo.
echo   Runtime layout:
echo     runtime\python\                 Python %PY_VER%
echo     runtime\node\                   Node.js %NODE_VER%
echo     runtime\appium\                 Appium + UiAutomator2
echo     runtime\android-sdk\            Android Platform Tools
echo.
echo   Next: run install\make_bundle.bat to create the
echo   distributable ZIP for CS/UAT staff.
echo.
echo   Log: %LOG%
GOTO :done

:done_tail
echo.
echo   ---- Last 30 lines from log ----
powershell -NoProfile -Command "if (Test-Path '%LOG%') { Get-Content '%LOG%' -Tail 30 } else { Write-Host 'Log not found.' }"
echo   ---- End of log ----
echo.

:done
echo SpatchEx bootstrap ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%BOOT_FAILED%"=="1" (
    echo   Bootstrap did NOT complete. See errors above.
    echo   Full log: %LOG%
    echo.
)
echo   Press any key to close...
pause >nul
IF "%BOOT_FAILED%"=="1" EXIT /B 1
EXIT /B 0
