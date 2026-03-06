@echo off
setlocal
chcp 65001 >/dev/null
cd /d "%~dp0"
REM ============================================================
REM SpatchEx -- First-Time Setup (Windows)
REM install.bat  (project root)
REM
REM  Run this ONCE before using run.bat.
REM  All setup logic lives in scripts\setup_env.bat.
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

REM ── Run setup ────────────────────────────────────────────────
call scripts\setup_env.bat
IF ERRORLEVEL 1 (
    pause
    EXIT /B 1
)
pause
EXIT /B 0
