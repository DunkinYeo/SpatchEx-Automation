@echo off
chcp 65001 >nul
cd /d "%~dp0"

echo.
echo   ╔══════════════════════════════════════╗
echo   ║    SpatchEx 장기 실행 테스트 UI      ║
echo   ╚══════════════════════════════════════╝
echo.

if not exist ".venv" (
  echo   처음 실행입니다. 필요한 도구를 설치합니다 ^(5~15분 소요^)...
  echo.
  call install.bat
  if errorlevel 1 (
    echo   [오류] 설치에 실패했습니다. 위 오류 메시지를 확인하세요.
    pause
    exit /b 1
  )
)

call start.bat
