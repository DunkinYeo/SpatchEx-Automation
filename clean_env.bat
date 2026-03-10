@echo off
setlocal
cd /d "%~dp0"

echo.
echo   SpatchEx Clean Test Environment
echo.

REM Remove build/runtime folders
IF EXIST ".venv"     ( echo   Removing .venv...     && rmdir /s /q ".venv" )
IF EXIST "logs"      ( echo   Removing logs...      && rmdir /s /q "logs" )
IF EXIST "artifacts" ( echo   Removing artifacts... && rmdir /s /q "artifacts" )
IF EXIST "tmp"       ( echo   Removing tmp...       && rmdir /s /q "tmp" )
IF EXIST "runtime"   ( echo   Removing runtime...   && rmdir /s /q "runtime" )

REM Recreate base folders
mkdir logs
mkdir runtime
mkdir artifacts

echo.
echo   Environment reset complete.
echo   Next step: run install.bat
echo.
pause
EXIT /B 0
