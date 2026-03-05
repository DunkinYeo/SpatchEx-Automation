@echo off
setlocal

REM ============================================================
REM SpatchEx -- Create Test Install ZIP
REM install/make_test_zip.bat
REM
REM Creates SpatchEx-Automation_TEST_INSTALL.zip on the Desktop.
REM Contents: install\  src\  config\  requirements.txt  run.bat
REM ============================================================

cd /d "%~dp0.."
SET "ROOT=%CD%"
SET "DESKTOP=%USERPROFILE%\Desktop"
SET "ZIP_NAME=SpatchEx-Automation_TEST_INSTALL.zip"
SET "ZIP_PATH=%DESKTOP%\%ZIP_NAME%"

FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "TMPDIR=%TEMP%\SpatchEx_pkg_%_TS%"
SET "PKG=%TMPDIR%\Ex-Automation"

echo.
echo   +-------------------------------------------------+
echo   ^|  SpatchEx -- Create Test Install ZIP           ^|
echo   +-------------------------------------------------+
echo.
echo   Project root : %ROOT%
echo   Output       : %ZIP_PATH%
echo.

REM ── Verify required source files exist ───────────────────────
IF NOT EXIST "%ROOT%\install\" GOTO :missing
IF NOT EXIST "%ROOT%\src\" GOTO :missing
IF NOT EXIST "%ROOT%\config\" GOTO :missing
IF NOT EXIST "%ROOT%\requirements.txt" GOTO :missing
IF NOT EXIST "%ROOT%\run.bat" GOTO :missing
GOTO :sources_ok

:missing
echo   ERROR: Required project files not found.
echo   Run this script from inside the Ex-Automation folder.
GOTO :done_fail

:sources_ok

REM ── Create temp package folder ───────────────────────────────
echo   Creating package structure...
mkdir "%PKG%" 2>nul
IF ERRORLEVEL 1 GOTO :mkdir_fail

REM ── Build xcopy exclude list (skip __pycache__ and .pyc) ─────
SET "EXCL=%TEMP%\spatchex_xcopy_excl_%_TS%.txt"
echo __pycache__ > "%EXCL%"
echo .pyc >> "%EXCL%"

REM ── Copy required contents ───────────────────────────────────
echo   Copying install\...
xcopy /S /I /Q "%ROOT%\install" "%PKG%\install\" >nul 2>&1

echo   Copying src\...
xcopy /S /I /Q /EXCLUDE:"%EXCL%" "%ROOT%\src" "%PKG%\src\" >nul 2>&1

echo   Copying config\...
xcopy /S /I /Q "%ROOT%\config" "%PKG%\config\" >nul 2>&1

echo   Copying requirements.txt...
copy /Y "%ROOT%\requirements.txt" "%PKG%\" >nul 2>&1
IF ERRORLEVEL 1 GOTO :copy_fail

echo   Copying run.bat...
copy /Y "%ROOT%\run.bat" "%PKG%\" >nul 2>&1
IF ERRORLEVEL 1 GOTO :copy_fail

del "%EXCL%" >nul 2>&1

REM ── Remove old ZIP if present ────────────────────────────────
IF EXIST "%ZIP_PATH%" (
    del /Q "%ZIP_PATH%"
    echo   Removed existing %ZIP_NAME%
)

REM ── Create ZIP with PowerShell Compress-Archive ──────────────
echo   Creating ZIP...
powershell -NoProfile -Command "Compress-Archive -Path '%PKG%' -DestinationPath '%ZIP_PATH%' -Force"
IF ERRORLEVEL 1 GOTO :zip_fail

REM ── Cleanup temp folder ──────────────────────────────────────
rmdir /S /Q "%TMPDIR%" >nul 2>&1

echo.
echo   +====================================================+
echo   ^|   ZIP created successfully!                       ^|
echo   +====================================================+
echo.
echo   File : %ZIP_PATH%
echo.
echo   Contents:
echo     Ex-Automation\install\
echo     Ex-Automation\src\
echo     Ex-Automation\config\
echo     Ex-Automation\requirements.txt
echo     Ex-Automation\run.bat
echo.
GOTO :done

:mkdir_fail
echo   ERROR: Failed to create temp directory: %TMPDIR%
rmdir /S /Q "%TMPDIR%" >nul 2>&1
GOTO :done_fail

:copy_fail
echo   ERROR: Failed to copy project files.
rmdir /S /Q "%TMPDIR%" >nul 2>&1
GOTO :done_fail

:zip_fail
echo   ERROR: Failed to create ZIP.
echo   Make sure PowerShell is available and try again.
rmdir /S /Q "%TMPDIR%" >nul 2>&1
GOTO :done_fail

:done_fail
echo.
echo   ZIP creation FAILED.
echo.

:done
echo   Press any key to close...
pause >nul
endlocal
