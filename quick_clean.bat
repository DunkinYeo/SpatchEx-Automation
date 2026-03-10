@echo off
setlocal
cd /d "%~dp0"

echo.
echo   SpatchEx Quick Cleanup
echo.

REM Remove logs/artifacts/tmp only
IF EXIST "logs"      ( echo   Removing logs...      && rmdir /s /q "logs" )
IF EXIST "artifacts" ( echo   Removing artifacts... && rmdir /s /q "artifacts" )
IF EXIST "tmp"       ( echo   Removing tmp...       && rmdir /s /q "tmp" )

REM Recreate base folders
mkdir logs
mkdir artifacts

echo.
echo   Quick cleanup complete.
echo   You can now run run.bat
echo.
pause
EXIT /B 0
