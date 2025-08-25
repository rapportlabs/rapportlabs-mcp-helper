@echo off
title Node.js 24.4.1 and mcp-remote Setup

echo ========================================
echo Node.js 24.4.1 and mcp-remote Setup Script
echo ========================================
echo.

REM Keep window open on any exit
if "%1"=="" (
    cmd /k "%~f0" RUN
    exit
)

REM Check if running as administrator
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] This script requires administrator privileges.
    echo.
    echo Please right-click the script and select "Run as administrator"
    echo.
    goto :end
)

echo [ADMIN CHECK] Running with administrator privileges - OK
echo.

REM Check current Node.js installation
echo Checking for existing Node.js installation...
where node >nul 2>&1
if %errorLevel% equ 0 (
    echo.
    echo Found existing Node.js:
    for /f "tokens=*" %%i in ('node --version 2^>nul') do echo Current version: %%i
    echo.
    echo This will be updated to v24.4.1
) else (
    echo.
    echo Node.js is not currently installed.
    echo Will install Node.js v24.4.1
)

echo.
echo ----------------------------------------
echo Press any key to proceed with setup...
echo ----------------------------------------
pause >nul

REM Check for winget availability
echo.
echo Checking for Windows Package Manager (winget)...
where winget >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Windows Package Manager (winget) not found!
    echo.
    echo Please install Node.js 24.4.1 manually:
    echo   1. Visit: https://nodejs.org/
    echo   2. Download Node.js v24.4.1
    echo   3. Run the installer
    echo   4. Re-run this script after installation
    echo.
    goto :end
)

echo [WINGET CHECK] Windows Package Manager found - OK
echo.

REM Install or update Node.js
echo Installing/Updating Node.js to v24.4.1...
echo This may take several minutes...
echo.

REM Try to uninstall existing Node.js first if present
where node >nul 2>&1
if %errorLevel% equ 0 (
    echo Attempting to update existing Node.js installation...
    winget upgrade OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements
    if %errorLevel% neq 0 (
        echo Update failed, attempting fresh installation...
        winget install OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements --force
    )
) else (
    echo Installing Node.js fresh...
    winget install OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements
)

echo.
echo Node.js installation step completed.
echo.

REM Refresh PATH
echo Refreshing environment variables...
set "PATH=%PATH%;%PROGRAMFILES%\nodejs\;%APPDATA%\npm"

REM Verify Node.js installation
echo Verifying Node.js installation...
where node >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo [ERROR] Node.js installation verification failed!
    echo.
    echo Possible solutions:
    echo   1. Close this window and open a new Command Prompt as administrator
    echo   2. Restart your computer
    echo   3. Install Node.js manually from https://nodejs.org/
    echo.
    goto :end
)

echo.
echo [SUCCESS] Node.js installed successfully!
echo.
for /f "tokens=*" %%i in ('node --version 2^>nul') do echo Node version: %%i
for /f "tokens=*" %%i in ('npm --version 2^>nul') do echo NPM version: %%i
for /f "tokens=*" %%i in ('npx --version 2^>nul') do echo NPX version: %%i

echo.
echo ----------------------------------------
echo Press any key to install mcp-remote...
echo ----------------------------------------
pause >nul

REM Install mcp-remote
echo.
echo Installing @rapportlabs/mcp-remote@0.1.18...
echo This may take a few minutes...
echo.

npm install -g @rapportlabs/mcp-remote@0.1.18

if %errorLevel% neq 0 (
    echo.
    echo [WARNING] First installation attempt failed.
    echo Retrying with --force flag...
    echo.
    npm install -g @rapportlabs/mcp-remote@0.1.18 --force
    
    if %errorLevel% neq 0 (
        echo.
        echo [ERROR] Failed to install mcp-remote!
        echo.
        echo Please try manually running:
        echo   npm install -g @rapportlabs/mcp-remote@0.1.18
        echo.
        goto :end
    )
)

echo.
echo ========================================
echo SETUP COMPLETE!
echo ========================================
echo.
echo Installed Software:
echo -------------------
for /f "tokens=*" %%i in ('node --version 2^>nul') do echo Node.js: %%i
for /f "tokens=*" %%i in ('npm --version 2^>nul') do echo NPM: %%i
for /f "tokens=*" %%i in ('npx --version 2^>nul') do echo NPX: %%i
echo mcp-remote: v0.1.18 (global)
echo.
echo You can now use mcp-remote with:
echo   npx @rapportlabs/mcp-remote [command]
echo   or
echo   mcp-remote [command]
echo.
echo ========================================

:end
echo.
echo Press any key to close this window...
pause >nul
exit /b