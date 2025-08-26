# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This repository contains setup scripts for configuring MCP (Model Context Protocol) servers with Claude Desktop across different platforms. The scripts handle:

1. **Node.js and npm setup** - Installing specific versions (Node.js 24.4.1) required for MCP
2. **mcp-remote package installation** - Installing the mcp-remote npm package globally
3. **Claude Desktop configuration** - Setting up MCP server configurations in Claude Desktop
4. **Optional GitHub MCP server** - Installing native GitHub MCP server binaries

## Repository Structure

- `mac-os/` - macOS setup scripts
  - `setup-basic-mcp.sh` - Main installer for Node.js, mcp-remote, and Claude config
  - `setup-optional-mcp.sh` - Optional GitHub MCP server installer
- `windows-os/` - Windows setup scripts  
  - `setup-node-mcp.bat` - Node.js and mcp-remote installer (uses winget)
  - `setup-claude-mcp.bat` - Claude Desktop configuration script
- `claude_desktop_config.json` - Example Claude Desktop configuration

## Script Architecture

### macOS Scripts (`setup-basic-mcp.sh`)
- Uses **nvm** for Node.js version management
- Installs Node.js 24.4.1 via nvm
- Configures mcp-remote@0.1.18 globally
- Creates Claude Desktop config at `~/Library/Application Support/Claude/`
- Sets up two MCP servers: rpls and queenit

### Windows Scripts
- `setup-node-mcp.bat`: Uses winget for Node.js installation, requires admin privileges
- `setup-claude-mcp.bat`: Creates config at `%APPDATA%\Claude\`

### Optional GitHub MCP Server (`setup-optional-mcp.sh`)
- Downloads platform-specific binaries from GitHub releases
- Installs to `/usr/local/bin/` (requires sudo)
- Integrates with Claude Desktop config using JXA (JavaScript for Automation)

## Key Commands

### Running Scripts
```bash
# macOS - Install basic MCP setup
./setup-basic-mcp.sh

# macOS - Install optional GitHub MCP server
./setup-optional-mcp.sh

# Windows - Run as administrator
setup-node-mcp.bat
setup-claude-mcp.bat
```

### Testing MCP Remote
```bash
# After installation, test mcp-remote
npx mcp-remote https://agentgateway.damoa.rapportlabs.dance/mcp
```

## Configuration Details

The scripts configure Claude Desktop with these MCP servers:

1. **rpls**: `https://agentgateway.damoa.rapportlabs.dance/mcp`
2. **queenit**: `https://mcp.rapportlabs.kr/mcp`
3. **github** (optional): Uses native binary with GitHub PAT authentication

## Important Implementation Notes

- Scripts perform version checking to avoid reinstalling if target versions exist
- All scripts create backups of existing Claude Desktop configurations
- macOS script uses nvm to avoid system-wide Node.js changes
- Windows scripts require administrator privileges for system-wide installation
- GitHub MCP server script uses osascript/JXA for safe JSON config merging

## Platform Requirements

- **macOS**: curl (pre-installed), bash
- **Windows**: winget (Windows Package Manager), administrator access
- **Both**: Claude Desktop application installed