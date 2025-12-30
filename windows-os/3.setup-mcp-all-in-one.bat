@echo off
pushd "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "3.setup-mcp-all-in-one.ps1"
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] 스크립트 실행 중 문제가 발생했습니다.
    pause
) else (
    echo.
    echo [SUCCESS] 모든 설정이 완료되었습니다!
    pause
)
popd
