@echo off
REM ============================================================
REM SpatchEx -- Build Distributable UAT Bundle
REM install\make_bundle.bat
REM
REM  !! FOR DEVELOPERS AND IT ADMINS ONLY !!
REM  CS/UAT staff: do NOT run this.
REM
REM  Purpose:
REM    Packages the project + bundled runtime into a ZIP file
REM    that CS/UAT staff can download, unzip, and use immediately.
REM
REM  Prerequisites:
REM    - Run install\bootstrap.bat first (creates runtime\ folder)
REM    - runtime\.ready must exist
REM
REM  Output:
REM    %USERPROFILE%\Desktop\SpatchEx-Automation_UAT_<timestamp>.zip
REM
REM  What is included in the bundle:
REM    00_README_QuickStart.txt   User guide
REM    run.bat                    Entry point (double-click)
REM    STOP.bat                   Stop script
REM    start\start.bat            Startup logic
REM    src\                       Automation framework
REM    web\                       Web UI
REM    config\spatch-ex.yaml      App configuration
REM    requirements.txt           (for reference)
REM    runtime\                   Bundled Python/Node/Appium/ADB
REM
REM  What is excluded:
REM    install\     Developer tools
REM    docs\        Developer documentation
REM    .venv\       System-based Python venv (not needed with runtime\)
REM    output\      Test artifacts
REM    .git\        Version control
REM    __pycache__  Python bytecode
REM    config\_web_run.yaml  Auto-generated config (excluded)
REM ============================================================
REM Keep window open on double-click
IF "%BUNDLE_RUNNING%"=="1" GOTO :run
SET BUNDLE_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0.."
SET "ROOT=%CD%"

REM ── Timestamp ────────────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_bundle_%_TS%.log"
SET "STAGE=%TEMP%\spatch_stage_%_TS%"
SET "ZIPNAME=SpatchEx-Automation_UAT_%_TS%.zip"
SET "ZIPOUT=%USERPROFILE%\Desktop\%ZIPNAME%"

echo SpatchEx make_bundle started %DATE% %TIME% > "%LOG%"
SET BUNDLE_FAILED=0

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   SpatchEx -- Build UAT Bundle                    ^|
echo   +====================================================+
echo.
echo   Output: %ZIPOUT%
echo   Log:    %LOG%
echo.

REM ── Verify project root ──────────────────────────────────────
IF EXIST "web\app.py" GOTO :root_ok
echo   ERROR: Must be run from inside the Ex-Automation folder.
SET BUNDLE_FAILED=1
GOTO :done

:root_ok

REM ── Check runtime\.ready ─────────────────────────────────────
IF EXIST "runtime\.ready" GOTO :runtime_ok
echo.
echo   WARNING: runtime\.ready not found.
echo   Run install\bootstrap.bat first to prepare the bundled runtime.
echo.
echo   The bundle will be created WITHOUT a bundled runtime.
echo   CS/UAT staff will need Python/Node/Appium installed manually.
echo.
echo   Press any key to continue anyway, or close to cancel.
pause >nul
echo.
:runtime_ok

REM ── Create staging folder ─────────────────────────────────────
echo   Creating staging folder...
IF EXIST "%STAGE%" rmdir /S /Q "%STAGE%"
mkdir "%STAGE%\SpatchEx-Automation"
SET "DEST=%STAGE%\SpatchEx-Automation"

REM ── Copy user-facing files ────────────────────────────────────
echo   Copying user-facing files...
IF EXIST "00_README_QuickStart.txt" copy "00_README_QuickStart.txt" "%DEST%\" >nul
IF EXIST "run.bat"                  copy "run.bat"                  "%DEST%\" >nul
IF EXIST "STOP.bat"                 copy "STOP.bat"                 "%DEST%\" >nul
IF EXIST "requirements.txt"        copy "requirements.txt"         "%DEST%\" >nul

REM ── Copy start\ (startup logic called by run.bat) ─────────────
IF EXIST "start" (
    mkdir "%DEST%\start"
    xcopy "start" "%DEST%\start\" /E /I /Q /Y >nul
)

REM ── Copy framework (src\ and web\) ────────────────────────────
echo   Copying framework (src\, web\)...
IF EXIST "src" (
    xcopy "src" "%DEST%\src\" /E /I /Q /Y /EXCLUDE:install\bundle_excludes.txt >nul 2>&1
    IF ERRORLEVEL 1 xcopy "src" "%DEST%\src\" /E /I /Q /Y >nul
)
IF EXIST "web" (
    xcopy "web" "%DEST%\web\" /E /I /Q /Y >nul
)

REM ── Copy app config (only the app yaml, not _web_run.yaml) ────
echo   Copying config...
mkdir "%DEST%\config"
IF EXIST "config\spatch-ex.yaml" copy "config\spatch-ex.yaml" "%DEST%\config\" >nul
IF EXIST "config\_web_run.example.yaml" copy "config\_web_run.example.yaml" "%DEST%\config\" >nul

REM ── Copy runtime\ (if .ready exists) ─────────────────────────
IF NOT EXIST "runtime\.ready" GOTO :skip_runtime
echo   Copying bundled runtime (this may take a moment)...
xcopy "runtime" "%DEST%\runtime\" /E /I /Q /Y /EXCLUDE:install\bundle_excludes.txt >nul 2>&1
IF ERRORLEVEL 1 (
    echo   WARNING: xcopy exclude failed -- copying without filter.
    xcopy "runtime" "%DEST%\runtime\" /E /I /Q /Y >nul
)
REM Remove download temp and npm cache from staging (not needed at runtime)
IF EXIST "%DEST%\runtime\_dl"        rmdir /S /Q "%DEST%\runtime\_dl"
IF EXIST "%DEST%\runtime\_npm_cache" rmdir /S /Q "%DEST%\runtime\_npm_cache"
echo   OK  Runtime copied.
:skip_runtime

REM ── Remove __pycache__ from staging ──────────────────────────
echo   Cleaning __pycache__...
FOR /F "delims=" %%D IN ('dir /S /B /AD "%DEST%\__pycache__" 2^>nul') DO rmdir /S /Q "%%D"

REM ── Calculate staging size ────────────────────────────────────
FOR /F "tokens=3" %%S IN ('dir /S /-C "%DEST%" 2^>nul ^| findstr /R "^[0-9]"') DO SET _SIZE=%%S
echo   Staging size: approx %_SIZE% bytes

REM ── Compress to ZIP ──────────────────────────────────────────
echo.
echo   Compressing to ZIP...
echo   Destination: %ZIPOUT%
IF EXIST "%ZIPOUT%" del "%ZIPOUT%"
powershell -NoProfile -Command "Compress-Archive -Path '%STAGE%\SpatchEx-Automation' -DestinationPath '%ZIPOUT%' -CompressionLevel Optimal"
IF ERRORLEVEL 1 GOTO :zip_fail

echo [bundle] ZIP created OK >> "%LOG%"

REM ── Cleanup staging ──────────────────────────────────────────
echo   Cleaning up staging folder...
rmdir /S /Q "%STAGE%" >nul 2>&1

REM ── Done ─────────────────────────────────────────────────────
echo.
echo   +====================================================+
echo   ^|   Bundle COMPLETE                                 ^|
echo   +====================================================+
echo.
echo   ZIP: %ZIPOUT%
echo.
echo   Distribute this file to CS/UAT staff.
echo   Instructions: unzip, double-click run.bat.
echo.
GOTO :done

:zip_fail
echo.
echo   ERROR: Compress-Archive failed. See log: %LOG%
echo   Staging folder (not deleted): %STAGE%
echo [bundle] FAIL: compress >> "%LOG%"
SET BUNDLE_FAILED=1

:done
echo SpatchEx make_bundle ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%BUNDLE_FAILED%"=="1" (
    echo   Bundle did NOT complete. See errors above.
    echo   Log: %LOG%
)
echo   Press any key to close...
pause >nul
IF "%BUNDLE_FAILED%"=="1" EXIT /B 1
EXIT /B 0
