@echo off
cd /d "%~dp0"

echo.
echo   +--------------------------------------+
echo   |    SpatchEx Long-Run Test UI         |
echo   +--------------------------------------+
echo.

if not exist ".venv" (
  echo   First run detected. Installing required tools (5-15 min)...
  echo.
  call install.bat
  if errorlevel 1 (
    echo   [ERROR] Setup failed. Check the error messages above.
    pause
    exit /b 1
  )
)

call start.bat
