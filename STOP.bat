@echo off
setlocal
cd /d "%~dp0"
REM ============================================================
REM SpatchEx -- Stop All Services
REM STOP.bat  (project root -- double-click to stop)
REM
REM  Terminates:
REM    - Appium server (port 4723)
REM    - Python web server (port 5001)
REM    - Any running test subprocess (main.py)
REM ============================================================

echo.
echo   +==============================================+
echo   ^|   SpatchEx -- Stopping All Services...     ^|
echo   +==============================================+
echo.

REM ── Stop web UI (port 5001) ──────────────────────────────────
echo   Stopping web server (port 5001)...
SET _STOPPED_WEB=0
FOR /F "tokens=5" %%P IN ('netstat -ano 2^>nul ^| findstr /R ":5001 "') DO (
    IF NOT "%%P"=="0" (
        taskkill /PID %%P /F >nul 2>&1
        SET _STOPPED_WEB=1
    )
)
IF "%_STOPPED_WEB%"=="1" (
    echo   OK  Web server stopped.
) ELSE (
    echo   Web server was not running.
)

REM ── Stop Appium server (port 4723) ───────────────────────────
echo   Stopping Appium server (port 4723)...
SET _STOPPED_APPIUM=0
FOR /F "tokens=5" %%P IN ('netstat -ano 2^>nul ^| findstr /R ":4723 "') DO (
    IF NOT "%%P"=="0" (
        taskkill /PID %%P /F >nul 2>&1
        SET _STOPPED_APPIUM=1
    )
)
IF "%_STOPPED_APPIUM%"=="1" (
    echo   OK  Appium server stopped.
) ELSE (
    echo   Appium server was not running.
)

REM ── Stop any running test subprocess (main.py) ───────────────
echo   Stopping test runner...
wmic process where "commandline like '%%main.py%%'" delete >nul 2>&1

echo.
echo   +==============================================+
echo   ^|   All services stopped. Safe to close.     ^|
echo   +==============================================+
echo.
echo   Press any key to close this window...
pause >nul
EXIT /B 0
