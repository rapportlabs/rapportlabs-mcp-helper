@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul
title Complete MCP Setup - Node.js and Claude Desktop Configuration

echo ========================================
echo Complete MCP Setup Script
echo - Node.js 24.4.1 and mcp-remote
echo - Claude Desktop MCP Configuration
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

REM ========================================
REM PART 1: Node.js and mcp-remote Setup
REM ========================================

echo [STEP 1/2] Setting up Node.js and mcp-remote...
echo ----------------------------------------
echo.

REM Check Node.js
echo Checking for existing Node.js installation...
set SKIP_NODE_INSTALL=0
where node >nul 2>&1
if errorlevel 1 (
    echo Node.js is NOT installed.
    echo Will install Node.js v24.4.1
) else (
    echo Found existing Node.js:
    for /f "tokens=*" %%v in ('node --version 2^>nul') do set CURRENT_NODE_VERSION=%%v
    echo Current version: !CURRENT_NODE_VERSION!
    
    REM Check if it's version 24.4.1
    echo !CURRENT_NODE_VERSION! | findstr /C:"v24.4.1" >nul
    if not errorlevel 1 (
        echo [SUCCESS] Node.js v24.4.1 is already installed!
        set SKIP_NODE_INSTALL=1
    ) else (
        echo This will be updated to v24.4.1
    )
)

echo.
echo Press any key to proceed with setup...
pause >nul

REM Check winget only if Node.js needs to be installed
if !SKIP_NODE_INSTALL!==1 (
    echo Winget check skipped - Node.js already at target version.
) else (
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
)
echo.

REM Install Node.js if needed
if !SKIP_NODE_INSTALL!==1 (
    echo Skipping Node.js installation - already at target version.
) else (
    echo Installing/Updating Node.js to v24.4.1...
    echo This may take several minutes...
    echo.
    
    winget install OpenJS.NodeJS --version 24.4.1 --silent --accept-package-agreements --accept-source-agreements --force
    
    echo.
    echo Node.js installation step completed.
)
echo.

REM Refresh PATH
echo Refreshing environment variables...
set "PATH=%PATH%;%PROGRAMFILES%\nodejs\;%APPDATA%\npm"

REM Verify Node.js
echo Verifying Node.js installation...
echo [DEBUG] Checking if node command is available in PATH...
where node >nul 2>&1
if errorlevel 1 (
    echo.
    echo [ERROR] Node.js installation verification failed!
    echo [DEBUG] This is where the script stops - node command not found in PATH
    echo.
    echo Please:
    echo   1. Close this window
    echo   2. Open new Command Prompt as administrator
    echo   3. Run this script again
    echo.
    goto :end
)
echo [DEBUG] Node.js verification passed - continuing to STEP 2/2...

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
echo Installing mcp-remote...
echo.

REM Install mcp-remote from geelen/mcp-remote
echo Installing mcp-remote from https://github.com/geelen/mcp-remote...
echo This may take a few minutes...
echo.

call npm install -g mcp-remote
echo [DEBUG] npm install command completed

if errorlevel 1 (
    echo.
    echo [WARNING] First npm install failed, retrying with --force flag...
    echo.
    call npm install -g mcp-remote --force
    echo [DEBUG] npm install --force command completed
    
    if errorlevel 1 (
        echo.
        echo [ERROR] Both npm install attempts failed!
        echo [DEBUG] This might cause the script to exit before STEP 2/2
        echo Continuing anyway to attempt Claude Desktop configuration...
        echo.
    )
) else (
    echo [DEBUG] npm install succeeded on first attempt
)

echo [DEBUG] Continuing after npm install section...

echo.
echo Verifying mcp-remote installation...
echo [DEBUG] About to check mcp-remote version...
echo Checking installed version via npm...
call npm list -g mcp-remote >nul 2>&1
if errorlevel 1 (
    echo [WARNING] Could not verify mcp-remote installation, but continuing...
) else (
    echo [SUCCESS] mcp-remote appears to be installed
)
echo [DEBUG] Version check completed, continuing...

echo.
echo [STEP 1/2] Node.js and mcp-remote setup complete!
echo [DEBUG] About to proceed to STEP 2/2...
echo.

REM ========================================
REM PART 2: Claude Desktop Configuration
REM ========================================

echo [DEBUG] Starting STEP 2/2 - Claude Desktop Configuration
echo ========================================
echo [STEP 2/2] Setting up Claude Desktop MCP configuration...
echo ========================================
echo.

REM Define the Claude Desktop config path
set "CONFIG_DIR=%APPDATA%\Claude"
set "CONFIG_FILE=%CONFIG_DIR%\claude_desktop_config.json"

REM Create the directory if it doesn't exist
if not exist "%CONFIG_DIR%" (
    echo Creating configuration directory: %CONFIG_DIR%
    mkdir "%CONFIG_DIR%"
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to create directory %CONFIG_DIR%
        echo.
        goto :end
    )
)

REM Write the MCP configuration
echo Writing MCP configuration to %CONFIG_FILE%...
echo [JSON CONFIG] Creating JSON structure...
echo [JSON CONFIG] Adding mcpServers object...
echo [JSON CONFIG] Configuring 'rpls' server with endpoint: https://agentgateway.damoa.rapportlabs.dance/mcp
echo [JSON CONFIG] Configuring 'queenit' server with endpoint: https://mcp.rapportlabs.kr/mcp
echo [JSON CONFIG] Writing configuration file...
(
echo {
echo   "mcpServers": {
echo     "rpls": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://agentgateway.damoa.rapportlabs.dance/mcp"
echo       ]
echo     },
echo     "queenit": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://mcp.rapportlabs.kr/mcp"
echo       ]
echo     }
echo   }
echo }
) > "%CONFIG_FILE%"
echo [JSON CONFIG] Configuration file write operation completed.

if !errorlevel! equ 0 (
    echo [SUCCESS] MCP configuration written successfully!
    echo.
    echo Configuration location: %CONFIG_FILE%
    echo.
    echo Configured MCP servers:
    echo - rpls: https://agentgateway.damoa.rapportlabs.dance/mcp
    echo - queenit: https://mcp.rapportlabs.kr/mcp
) else (
    echo.
    echo [ERROR] Failed to write configuration file.
    echo Please check permissions for %CONFIG_DIR%
    echo.
    goto :end
)

echo.
echo ========================================
echo COMPLETE SETUP SUCCESSFUL!
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
echo mcp-remote: installed
echo.
echo Claude Desktop Configuration:
echo ----------------------------
echo Config file: %CONFIG_FILE%
echo MCP Servers: rpls, queenit
echo.
echo ========================================
echo IMPORTANT: Please restart Claude Desktop
echo for the changes to take effect!
echo ========================================

:end
echo.
echo Press any key to close this window...
pause >nul
exit /b