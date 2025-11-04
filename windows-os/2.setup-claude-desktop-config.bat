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
echo     "rpwiki": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp"
echo       ]
echo     },
echo     "notion": {
echo       "command": "npx",
echo       "args": [
echo         "-y",
echo         "mcp-remote",
echo         "https://mcp.notion.com/mcp"
echo       ]
echo     },
echo     "bq": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
echo       ]
echo     },
echo     "slack": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://slack-mcp.damoa.rapportlabs.dance/sse"
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
    echo - rpwiki: https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp
    echo - notion: https://notion-mcp.damoa.rapportlabs.dance/mcp
    echo - bq: https://bigquery-mcp.damoa.rapportlabs.dance/mcp
    echo - slack: https://slack-mcp.damoa.rapportlabs.dance/sse
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