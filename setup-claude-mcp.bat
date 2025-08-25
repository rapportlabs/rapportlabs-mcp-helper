@echo off
setlocal enabledelayedexpansion

echo Setting up Claude Desktop MCP configuration...
echo.

:: Define the Claude Desktop config path
set "CONFIG_DIR=%APPDATA%\Claude"
set "CONFIG_FILE=%CONFIG_DIR%\claude_desktop_config.json"

:: Create the directory if it doesn't exist
if not exist "%CONFIG_DIR%" (
    echo Creating configuration directory: %CONFIG_DIR%
    mkdir "%CONFIG_DIR%"
    if !errorlevel! neq 0 (
        echo Error: Failed to create directory %CONFIG_DIR%
        pause
        exit /b 1
    )
)

:: Write the MCP configuration
echo Writing MCP configuration to %CONFIG_FILE%...
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

if !errorlevel! equ 0 (
    echo.
    echo Success! MCP configuration has been written to:
    echo %CONFIG_FILE%
    echo.
    echo The following MCP servers have been configured:
    echo - rpls: https://agentgateway.damoa.rapportlabs.dance/mcp
    echo - queenit: https://mcp.rapportlabs.kr/mcp
    echo.
    echo Please restart Claude Desktop for the changes to take effect.
) else (
    echo.
    echo Error: Failed to write configuration file.
    echo Please check permissions for %CONFIG_DIR%
    pause
    exit /b 1
)

echo.
pause