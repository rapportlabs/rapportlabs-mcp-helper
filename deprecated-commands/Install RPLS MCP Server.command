#!/bin/bash

# RPLS MCP Server Installation Script for macOS
# Double-click this file to install

clear
echo "=========================================="
echo "  RPLS MCP Server Installer for macOS"
echo "=========================================="
echo ""

# Change to the script's directory
cd "$(dirname "$0")"

set -e

echo ""
echo "This installer will:"
echo "1. Check if Node.js and npm are available"
echo "2. Install mcp-remote package if needed"
echo "3. Configure Claude Desktop for RPLS MCP Server"
echo ""
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Check if Node.js and npm are available
echo ""
echo "⏳ Checking Node.js and npm..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed."
    echo ""
    echo "Please install Node.js first:"
    echo "1. Visit: https://nodejs.org"
    echo "2. Download and install the LTS version"
    echo "3. Restart your terminal"
    echo "4. Run this installer again"
    echo ""
    echo "Press Enter to exit..."
    read
    osascript -e 'tell application "Terminal" to close first window' &
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not available."
    echo ""
    echo "npm should come with Node.js. Please reinstall Node.js:"
    echo "1. Visit: https://nodejs.org"
    echo "2. Download and install the LTS version"
    echo "3. Restart your terminal"
    echo "4. Run this installer again"
    echo ""
    echo "Press Enter to exit..."
    read
    osascript -e 'tell application "Terminal" to close first window' &
    exit 1
fi

NODE_VERSION=$(node --version)
NPM_VERSION=$(npm --version)

echo "✅ Node.js version: $NODE_VERSION"
echo "✅ npm version: $NPM_VERSION"

# Check if mcp-remote is available
echo ""
echo "⏳ Checking mcp-remote package..."

if ! npm list -g mcp-remote &> /dev/null; then
    echo "📦 Installing mcp-remote package globally..."
    npm install -g mcp-remote
    echo "✅ mcp-remote installed successfully!"
else
    echo "✅ mcp-remote is already installed"
fi

echo ""
echo "=========================================="
echo "  Claude Desktop Configuration"
echo "=========================================="
echo ""

# Check for Claude Desktop config
CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

if [ -f "$CONFIG_FILE" ]; then
    echo "Found Claude Desktop config file."
    echo ""
    
    # Check if RPLS MCP is already configured
    if grep -q '"rpls"' "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ RPLS MCP Server is already configured in Claude Desktop."
        echo ""
        echo "Current configuration:"
        echo "---"
        python3 -c "
import json
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    if 'mcpServers' in config and 'rpls' in config['mcpServers']:
        rpls_config = config['mcpServers']['rpls']
        print(f\"Command: {rpls_config.get('command', 'Not set')}\")
        args = rpls_config.get('args', [])
        if args:
            print(f\"Args: {' '.join(args)}\")
        else:
            print('Args: Not set')
except Exception as e:
    print(f'Error reading config: {e}')
" 2>/dev/null || echo "Could not parse configuration"
        echo "---"
        echo ""
        while true; do
            echo "Would you like to reconfigure it? (y/n): "
            read -n 1 RECONFIGURE
            echo ""
            
            if [[ "$RECONFIGURE" =~ ^[YyNn]$ ]]; then
                break
            else
                echo "Invalid option. Please enter 'y' or 'n'."
                echo ""
            fi
        done
        
        if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Configuration skipped."
        else
            # Update the configuration
            echo "⏳ Updating Claude Desktop configuration..."
            python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    if 'mcpServers' not in config:
        config['mcpServers'] = {}
    
    config['mcpServers']['rpls'] = {
        'command': 'npx',
        'args': [
            'mcp-remote',
            'https://agentgateway.damoa.rapportlabs.dance/mcp'
        ]
    }
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ Configuration updated successfully!')
except Exception as e:
    print(f'❌ Error updating config: {e}')
    sys.exit(1)
"
            echo ""
        fi
    else
        # RPLS MCP not configured, ask to add it
        echo "RPLS MCP Server is not configured in Claude Desktop."
        echo ""
        while true; do
            echo "Would you like to configure it now? (y/n): "
            read -n 1 CONFIGURE
            echo ""
            
            if [[ "$CONFIGURE" =~ ^[YyNn]$ ]]; then
                break
            else
                echo "Invalid option. Please enter 'y' or 'n'."
                echo ""
            fi
        done
        
        if [[ "$CONFIGURE" =~ ^[Yy]$ ]]; then
            # Add the configuration
            echo "⏳ Updating Claude Desktop configuration..."
            python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    if 'mcpServers' not in config:
        config['mcpServers'] = {}
    
    config['mcpServers']['rpls'] = {
        'command': 'npx',
        'args': [
            'mcp-remote',
            'https://agentgateway.damoa.rapportlabs.dance/mcp'
        ]
    }
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ Configuration added successfully!')
except Exception as e:
    print(f'❌ Error updating config: {e}')
    sys.exit(1)
"
            echo ""
            echo "⚠️  Please restart Claude Desktop for the changes to take effect."
            echo ""
        else
            echo ""
            echo "Configuration skipped."
            echo "You can manually configure it later by editing:"
            echo "$CONFIG_FILE"
            echo ""
        fi
    fi
else
    echo "⚠️  Claude Desktop config file not found."
    echo "   Expected location: $CONFIG_FILE"
    echo ""
    while true; do
        echo "Would you like to create the configuration anyway? (y/n): "
        read -n 1 CREATE_CONFIG
        echo ""
        
        if [[ "$CREATE_CONFIG" =~ ^[YyNn]$ ]]; then
            break
        else
            echo "Invalid option. Please enter 'y' or 'n'."
            echo ""
        fi
    done
    
    if [[ "$CREATE_CONFIG" =~ ^[Yy]$ ]]; then
        # Create the directory and configuration
        echo "⏳ Creating Claude Desktop configuration..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'

try:
    config = {
        'mcpServers': {
            'rpls': {
                'command': 'npx',
                'args': [
                    'mcp-remote',
                    'https://agentgateway.damoa.rapportlabs.dance/mcp'
                ]
            }
        }
    }
    
    with open(config_file, 'w') as f:
        json.dump(config, f, indent=2)
    
    print('✅ Configuration created successfully!')
except Exception as e:
    print(f'❌ Error creating config: {e}')
    sys.exit(1)
"
        echo ""
        echo "⚠️  Please restart Claude Desktop for the changes to take effect."
        echo ""
    else
        echo ""
        echo "Configuration skipped."
        echo "You can manually configure it later by creating:"
        echo "$CONFIG_FILE"
        echo ""
    fi
fi

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "RPLS MCP Server has been configured successfully!"
echo ""
echo "The server will be available through npx and mcp-remote."
echo ""
echo "Press Enter to close this window..."
read

# Close the Terminal window
osascript -e 'tell application "Terminal" to close first window' &