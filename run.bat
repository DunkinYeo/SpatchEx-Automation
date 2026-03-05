@echo off
REM ============================================================
REM SpatchEx Long-Run Test -- Launcher
REM run.bat (project root)
REM ============================================================
REM Keep window open: re-launch inside cmd /k on direct double-click
IF "%SPATCHEX_RUNNING%"=="1" GOTO :run
SET SPATCHEX_RUNNING=1
cmd /k "%~f0"
EXIT /B

:run
cd /d "%~dp0"

REM ── Timestamp + log ─────────────────────────────────────────
FOR /F "usebackq tokens=*" %%T IN (`powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"`) DO SET _TS=%%T
SET "LOG=%TEMP%\spatch_run_%_TS%.log"
echo SpatchEx run started %DATE% %TIME% > "%LOG%"

SET RUN_FAILED=0

REM ── Banner ───────────────────────────────────────────────────
echo.
echo   +==========================================+
echo   ^|   SpatchEx Long-Run Test -- Launcher   ^|
echo   +==========================================+
echo.
echo   Log: %LOG%
echo.

REM ── Check .venv → auto-install if missing ───────────────────
IF EXIST ".venv" GOTO :start_server

echo   First run detected. Installing required tools (5-15 min)...
echo   (Do not close this window)
echo.
echo First run: starting install >> "%LOG%"
call install\install.bat
IF ERRORLEVEL 1 GOTO :install_fail
echo Install completed OK >> "%LOG%"
GOTO :start_server

:install_fail
echo.
echo   ERROR: Setup did not complete. See messages above.
echo   Full log: %LOG%
SET RUN_FAILED=1
GOTO :done

REM ── Start Appium + Web UI (start.bat also opens browser) ────
:start_server
echo   Starting server...
echo Starting server >> "%LOG%"
call start\start.bat
IF ERRORLEVEL 1 GOTO :start_fail

REM ── (Defensive) Re-open browser after server exits ───────────
timeout /t 2 /nobreak >nul
start "" http://127.0.0.1:5001
GOTO :done

:start_fail
echo.
echo   ERROR: Server failed to start. See messages above.
echo   Full log: %LOG%
SET RUN_FAILED=1
GOTO :done

:done
echo SpatchEx run ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%RUN_FAILED%"=="1" (
    echo   +==========================================+
    echo   ^|   Run did NOT complete.                ^|
    echo   ^|   See errors above.                    ^|
    echo   +==========================================+
    echo.
    echo   Full log: %LOG%
    echo.
)
echo   Press any key to close...
pause >nul
IF "%RUN_FAILED%"=="1" EXIT /B 1
EXIT /B 0
