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

REM ── Verify project root ──────────────────────────────────────
IF NOT EXIST "web\app.py" (
    echo.
    echo   ERROR: web\app.py not found.
    echo   Run install.bat from inside the SpatchEx-Automation folder.
    echo.
    pause
    EXIT /B 1
)

REM ── Run setup ────────────────────────────────────────────────
call scripts\setup_env.bat
IF ERRORLEVEL 1 (
    pause
    EXIT /B 1
)
pause
EXIT /B 0
