@echo off
cd /d "%~dp0"

REM Activate virtual environment
if exist ".venv\Scripts\activate.bat" (
  call .venv\Scripts\activate.bat
) else (
  echo [ERROR] Virtual environment (.venv) not found.
  echo         Run install.bat first.
  pause
  exit /b 1
)

REM Ensure Flask is installed
python -c "import flask" 2>nul || pip install flask -q

echo.
echo   Starting SpatchEx Test UI...
echo   Browser will open -^> http://127.0.0.1:5001
echo.
echo   Close this window to stop.
echo.

python web\app.py
pause
