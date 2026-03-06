@echo off
REM ============================================================
REM SpatchEx Long-Run Test -- Launcher
REM run.bat  (project root)
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

REM ── Check .venv -> auto-install if missing ───────────────────
IF EXIST ".venv\Scripts\activate.bat" GOTO :launch

echo   First run detected. Running installer (5-15 min)...
echo   (Do not close this window)
echo.
echo [run] First run: invoking installer >> "%LOG%"
call install\install.bat
IF ERRORLEVEL 1 GOTO :install_fail
echo [run] Installer completed OK >> "%LOG%"
GOTO :launch

:install_fail
echo.
echo   +==========================================+
echo   ^|   ERROR: Installer did not complete.   ^|
echo   +==========================================+
echo.
echo   See errors above.
echo   Full log: %LOG%
echo.
echo [run] FAIL: installer returned error >> "%LOG%"
SET RUN_FAILED=1
GOTO :done

REM ── Start Appium + Web UI via start\start.bat ────────────────
:launch
echo [run] Calling start\start.bat >> "%LOG%"
call start\start.bat
SET _START_ERR=%ERRORLEVEL%
echo [run] start.bat returned %_START_ERR% >> "%LOG%"
IF "%_START_ERR%"=="0" GOTO :done

echo.
echo   +==========================================+
echo   ^|   ERROR: Server startup failed.         ^|
echo   +==========================================+
echo.
echo   See errors above.
echo   Full log: %LOG%
echo.
SET RUN_FAILED=1
GOTO :done

:done
echo SpatchEx run ended %DATE% %TIME% >> "%LOG%"
echo.
IF "%RUN_FAILED%"=="1" (
    echo   Full log: %LOG%
    echo.
)
echo   Press any key to close...
pause >nul
IF "%RUN_FAILED%"=="1" EXIT /B 1
EXIT /B 0
