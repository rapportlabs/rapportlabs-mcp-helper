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
echo     "bq": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
echo       ]
echo     },
echo     "notion": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://mcp.notion.com/mcp"
echo       ]
echo     },
echo     "slack": {
echo       "command": "npx",
echo       "args": [
echo         "mcp-remote",
echo         "https://slack-mcp.damoa.rapportlabs.dance/sse"
echo       ]
echo       ]
echo     }
echo   }
echo }
) > "%CONFIG_FILE%"

:: Setup Antigravity
set "ANTIGRAVITY_DIR=%USERPROFILE%\.gemini\antigravity"
set "ANTIGRAVITY_FILE=%ANTIGRAVITY_DIR%\mcp_config.json"
if exist "%ANTIGRAVITY_DIR%" (
    echo Writing MCP configuration to %ANTIGRAVITY_FILE%...
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
    echo     "bq": {
    echo       "command": "npx",
    echo       "args": [
    echo         "mcp-remote",
    echo         "https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
    echo       ]
    echo     },
    echo     "notion": {
    echo       "command": "npx",
    echo       "args": [
    echo         "mcp-remote",
    echo         "https://mcp.notion.com/mcp"
    echo       ]
    echo     },
    echo     "slack": {
    echo       "command": "npx",
    echo       "args": [
    echo         "mcp-remote",
    echo         "https://slack-mcp.damoa.rapportlabs.dance/sse"
    echo       ]
    echo     }
    echo   }
    echo }
    ) > "%ANTIGRAVITY_FILE%"
    echo Antigravity configuration updated.
)

:: Setup Kiro
set "KIRO_BASE_DIR=%USERPROFILE%\.kiro"
set "KIRO_DIR=%KIRO_BASE_DIR%\settings"
set "KIRO_FILE=%KIRO_DIR%\mcp.json"
if exist "%KIRO_BASE_DIR%" (
    if not exist "%KIRO_DIR%" mkdir "%KIRO_DIR%"
    echo Writing MCP configuration to %KIRO_FILE%...
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
    echo     "bq": {
    echo       "command": "npx",
    echo       "args": [
    echo         "mcp-remote",
    echo         "https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
    echo       ]
    echo     },
    echo     "notion": {
    echo       "command": "npx",
    echo       "args": [
    echo         "mcp-remote",
    echo         "https://mcp.notion.com/mcp"
    echo       ]
    echo     },
    echo     "slack": {
    echo       "command": "npx",
    echo       "args": [
    echo         "mcp-remote",
    echo         "https://slack-mcp.damoa.rapportlabs.dance/sse"
    echo       ]
    echo     }
    echo   }
    echo }
    ) > "%KIRO_FILE%"
    echo Kiro configuration updated.
)

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