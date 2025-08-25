@echo off
chcp 65001 >nul
title Node.js 24.4.1 and mcp-remote Setup

echo ========================================
echo Node.js 24.4.1 and mcp-remote Setup Script
echo (mcp-remote from geelen/mcp-remote)
echo ========================================
echo.

REM Keep window open
if "%1"=="" (
    cmd /k "%~f0" RUN
    exit
)

REM Check admin
net session >nul 2>&1
if errorlevel 1 (
    echo [ERROR] This script requires administrator privileges.
    echo.
    echo Please right-click and Run as administrator
    echo.
    goto :end
)

echo [ADMIN CHECK] Running with administrator privileges - OK
echo.

REM Check Node.js
echo Checking for existing Node.js installation...
where node >nul 2>&1
if errorlevel 1 (
    echo Node.js is NOT installed.
    echo Will install Node.js v24.4.1
) else (
    echo Found existing Node.js:
    node --version
    echo This will be updated to v24.4.1
)

echo.
echo ----------------------------------------
echo Press any key to proceed with setup...
echo ----------------------------------------
pause >nul

REM Check winget
echo.
echo Checking for Windows Package Manager...
where winget >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] winget not found!
    echo.
    echo Please install Node.js 24.4.1 manually from:
    echo https://nodejs.org/
    echo.
    goto :end
)

echo [WINGET CHECK] Windows Package Manager found - OK
echo.

REM Install Node.js
echo Installing/Updating Node.js to v24.4.1...
echo This may take several minutes...
echo.

winget install OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements --force

echo.
echo Node.js installation step completed.
echo.

REM Refresh PATH
echo Refreshing environment variables...
set "PATH=%PATH%;%PROGRAMFILES%\nodejs\;%APPDATA%\npm"

REM Verify Node.js
echo Verifying Node.js installation...
where node >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Node.js installation verification failed!
    echo.
    echo Please:
    echo   1. Close this window
    echo   2. Open new Command Prompt as administrator
    echo   3. Run this script again
    echo.
    goto :end
)

echo.
echo [SUCCESS] Node.js installed successfully!
echo.
echo Node version:
call node --version
echo NPM version:
call npm --version
echo NPX version:
call npx --version

echo.
echo ----------------------------------------
echo Press any key to install mcp-remote...
echo ----------------------------------------
pause >nul

REM Install mcp-remote from geelen/mcp-remote
echo.
echo Installing mcp-remote from https://github.com/geelen/mcp-remote...
echo This may take a few minutes...
echo.

npm install -g mcp-remote

if errorlevel 1 (
    echo.
    echo [WARNING] Retrying with --force flag...
    echo.
    npm install -g mcp-remote --force
)

echo.
echo ========================================
echo SETUP COMPLETE!
echo ========================================
echo.
echo Installed Software:
echo -------------------
echo Node version:
call node --version
echo NPM version:
call npm --version
echo NPX version:
call npx --version
echo.
echo mcp-remote (global) from geelen/mcp-remote
echo.
echo You can use mcp-remote with:
echo   mcp-remote [command]
echo.
echo ========================================

:end
echo.
echo Press any key to close this window...
pause >nul
exit /b