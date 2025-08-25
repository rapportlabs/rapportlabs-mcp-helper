@echo off
setlocal enabledelayedexpansion

echo ========================================
echo Node.js 24.4.1 and mcp-remote Setup Script
echo ========================================
echo.

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo This script requires administrator privileges.
    echo Please run as administrator.
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Check if Node.js is installed
where node >nul 2>&1
if %errorLevel% equ 0 (
    echo Current Node.js version:
    node --version
    echo.
    echo Updating to Node.js 24.4.1...
) else (
    echo Node.js is not installed.
    echo Installing Node.js 24.4.1...
    echo.
)
echo.
echo Press any key to continue with installation...
pause >nul
echo.

REM Install or update Node.js 24.4.1 using winget (Windows Package Manager)
echo Setting up Node.js 24.4.1...
where winget >nul 2>&1
if %errorLevel% equ 0 (
    REM First try to upgrade if already installed, otherwise install
    winget upgrade OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements >nul 2>&1
    if %errorLevel% neq 0 (
        winget install OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements
    )
    if %errorLevel% neq 0 (
        echo Failed to install/update Node.js via winget.
        echo Please install Node.js 24.4.1 manually from https://nodejs.org/
        echo.
        echo Press any key to exit...
        pause >nul
        exit /b 1
    )
    echo.
    echo Node.js installation/update completed!
    echo Press any key to continue...
    pause >nul
) else (
    echo Windows Package Manager (winget) not found.
    echo.
    echo Please install Node.js 24.4.1 manually:
    echo 1. Visit https://nodejs.org/
    echo 2. Download Node.js 24.4.1 version
    echo 3. Run the installer
    echo 4. Re-run this script after installation
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

REM Refresh environment variables
call refreshenv >nul 2>&1

REM Verify Node.js installation
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo Node.js installation verification failed.
    echo Please restart Command Prompt and try again.
    echo.
    echo Press any key to exit...
    pause >nul
    exit /b 1
)

echo.
echo Node.js installed successfully!
node --version
echo.
echo Press any key to continue with npm and mcp-remote setup...
pause >nul
echo.

REM Check npm version
echo NPM version:
call npm --version
echo.

REM npx comes bundled with npm (since npm 5.2.0)
echo NPX version:
call npx --version
echo.

REM Install mcp-remote globally
echo Installing mcp-remote v0.1.18...
echo This may take a few minutes...
echo.
call npm install -g @rapportlabs/mcp-remote@0.1.18

if %errorLevel% neq 0 (
    echo Failed to install mcp-remote.
    echo Trying with administrator privileges...
    call npm install -g @rapportlabs/mcp-remote@0.1.18 --force
    if !errorLevel! neq 0 (
        echo.
        echo Failed to install mcp-remote. Please try manually:
        echo npm install -g @rapportlabs/mcp-remote@0.1.18
        echo.
        echo Press any key to exit...
        pause >nul
        exit /b 1
    )
)

echo.
echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Installed versions:
echo -------------------
call node --version
call npm --version
call npx --version
echo.
echo mcp-remote version:
call npx @rapportlabs/mcp-remote --version 2>nul
if %errorLevel% neq 0 (
    echo mcp-remote v0.1.18 (installed globally)
) 

echo.
echo You can now use mcp-remote with:
echo   npx @rapportlabs/mcp-remote [command]
echo   or
echo   mcp-remote [command]
echo.
echo ========================================
echo.
echo Press any key to exit...
pause >nul