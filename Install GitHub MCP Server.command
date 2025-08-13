#!/bin/bash

# GitHub MCP Server Installation Script for macOS
# Double-click this file to install

clear
echo "=========================================="
echo "  GitHub MCP Server Installer for macOS"
echo "=========================================="
echo ""

# Change to the script's directory
cd "$(dirname "$0")"

set -e

# Configuration
REPO="github/github-mcp-server"
VERSION="latest"
INSTALL_DIR="/usr/local/bin"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_SUFFIX="x86_64"
    echo "📱 Detected: Intel Mac"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="arm64"
    echo "📱 Detected: Apple Silicon Mac (M1/M2/M3)"
else
    echo "❌ Unsupported architecture: $ARCH"
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Check if already installed
if command -v github-mcp-server &> /dev/null; then
    CURRENT_VERSION=$(github-mcp-server --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo ""
    echo "✅ GitHub MCP Server is already installed"
    echo "   Current version: $CURRENT_VERSION"
    echo ""
    
    # Get latest version
    echo "⏳ Checking for updates..."
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name":' | \
        cut -d '"' -f 4)
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        echo "✅ You already have the latest version ($LATEST_VERSION)"
        echo ""
        echo "Press Enter to exit..."
        read
        osascript -e 'tell application "Terminal" to close first window' &
        exit 0
    else
        echo "🆕 Update available: $LATEST_VERSION"
        echo ""
        echo "Would you like to upgrade? (y/n): "
        read -n 1 UPGRADE_CHOICE
        echo ""
        
        if [[ ! "$UPGRADE_CHOICE" =~ ^[Yy]$ ]]; then
            echo "Installation cancelled."
            echo "Press Enter to exit..."
            read
            osascript -e 'tell application "Terminal" to close first window' &
            exit 0
        fi
        echo "Proceeding with upgrade to $LATEST_VERSION..."
    fi
else
    echo ""
    echo "This installer will:"
    echo "1. Download the latest GitHub MCP Server"
    echo "2. Install it to $INSTALL_DIR"
    echo "3. You may be asked for your password"
    echo ""
    echo "Press Enter to continue or Ctrl+C to cancel..."
    read
fi

# Get the download URL
echo ""
echo "⏳ Fetching download information..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep "browser_download_url.*Darwin_${ARCH_SUFFIX}.tar.gz" | \
    cut -d '"' -f 4)

VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep '"tag_name":' | \
    cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Failed to find download URL"
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

if [ -z "$VERSION" ]; then
    VERSION=$LATEST_VERSION
fi
echo "✅ Installing version: $VERSION"
echo ""
echo "⏳ Downloading..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download with progress bar
curl -L --progress-bar -o "$TEMP_DIR/github-mcp-server.tar.gz" "$DOWNLOAD_URL"

echo ""
echo "⏳ Extracting..."
tar -xzf "$TEMP_DIR/github-mcp-server.tar.gz" -C "$TEMP_DIR"

# Find the binary
BINARY=$(find "$TEMP_DIR" -name "github-mcp-server" -type f | head -1)

if [ -z "$BINARY" ]; then
    echo "❌ Binary not found in archive"
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Install
echo ""
echo "⏳ Installing to $INSTALL_DIR..."
echo "   (You may be asked for your password)"
echo ""

# Create install directory if it doesn't exist
sudo mkdir -p "$INSTALL_DIR"

# Install the binary
sudo mv "$BINARY" "$INSTALL_DIR/github-mcp-server"
sudo chmod +x "$INSTALL_DIR/github-mcp-server"

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "GitHub MCP Server $VERSION has been installed successfully!"
echo ""

# Verify installation
if command -v github-mcp-server &> /dev/null; then
    echo "Version installed:"
    github-mcp-server --version
else
    echo "⚠️  Note: You may need to restart your terminal to use the command."
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
    
    # Check if GitHub MCP is already configured
    if grep -q '"github"' "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ GitHub MCP Server is already configured in Claude Desktop."
        echo ""
        echo "Current configuration:"
        echo "---"
        python3 -c "
import json
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    if 'mcpServers' in config and 'github' in config['mcpServers']:
        github_config = config['mcpServers']['github']
        print(f\"Command: {github_config.get('command', 'Not set')}\")
        if 'env' in github_config and 'GITHUB_PERSONAL_ACCESS_TOKEN' in github_config['env']:
            pat = github_config['env']['GITHUB_PERSONAL_ACCESS_TOKEN']
            if pat.startswith('\$'):
                print(f\"GitHub PAT: Using environment variable {pat}\")
            else:
                print(f\"GitHub PAT: Configured (hidden)\")
        else:
            print('GitHub PAT: Not configured')
except Exception as e:
    print(f'Error reading config: {e}')
" 2>/dev/null || echo "Could not parse configuration"
        echo "---"
        echo ""
        echo "Would you like to reconfigure it? (y/n): "
        read -n 1 RECONFIGURE
        echo ""
        
        if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Configuration skipped."
        else
            # Reconfigure
            echo ""
            echo "Do you have a GitHub Personal Access Token (PAT)? (y/n): "
            read -n 1 HAS_PAT
            echo ""
            
            if [[ "$HAS_PAT" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Enter your GitHub Personal Access Token:"
                read -s GITHUB_TOKEN
                echo ""
                PAT_VALUE="\"$GITHUB_TOKEN\""
            else
                echo ""
                echo "❌ A GitHub Personal Access Token is required for the GitHub MCP Server to work."
                echo ""
                echo "Please follow our guide to create a PAT:"
                echo "https://www.notion.so/rapportlabs/MCP-Claude-1de466b620998067a649e145c6bb0d15?source=copy_link#1df466b6209981afa0ecfc86d8d3a586"
                echo ""
                echo "After getting your PAT, you can rerun this installer to configure it."
                echo ""
                echo "Press Enter to exit..."
                read
                osascript -e 'tell application "Terminal" to close first window' &
                exit 0
            fi
            
            # Update the configuration
            echo "⏳ Updating Claude Desktop configuration..."
            python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'
pat_value = $PAT_VALUE

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    if 'mcpServers' not in config:
        config['mcpServers'] = {}
    
    config['mcpServers']['github'] = {
        'command': '/usr/local/bin/github-mcp-server',
        'args': ['stdio'],
        'env': {
            'GITHUB_PERSONAL_ACCESS_TOKEN': pat_value
        }
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
        # GitHub MCP not configured, ask to add it
        echo "GitHub MCP Server is not configured in Claude Desktop."
        echo ""
        echo "Would you like to configure it now? (y/n): "
        read -n 1 CONFIGURE
        echo ""
        
        if [[ "$CONFIGURE" =~ ^[Yy]$ ]]; then
            echo ""
            echo "Do you have a GitHub Personal Access Token (PAT)? (y/n): "
            read -n 1 HAS_PAT
            echo ""
            
            if [[ "$HAS_PAT" =~ ^[Yy]$ ]]; then
                echo ""
                echo "Enter your GitHub Personal Access Token:"
                read -s GITHUB_TOKEN
                echo ""
                PAT_VALUE="\"$GITHUB_TOKEN\""
            else
                echo ""
                echo "❌ A GitHub Personal Access Token is required for the GitHub MCP Server to work."
                echo ""
                echo "Please follow our guide to create a PAT:"
                echo "https://www.notion.so/rapportlabs/MCP-Claude-1de466b620998067a649e145c6bb0d15?source=copy_link#1df466b6209981afa0ecfc86d8d3a586"
                echo ""
                echo "After getting your PAT, you can rerun this installer to configure it."
                echo ""
                echo "Press Enter to exit..."
                read
                osascript -e 'tell application "Terminal" to close first window' &
                exit 0
            fi
            
            # Add the configuration
            echo "⏳ Updating Claude Desktop configuration..."
            python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'
pat_value = $PAT_VALUE

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
    
    if 'mcpServers' not in config:
        config['mcpServers'] = {}
    
    config['mcpServers']['github'] = {
        'command': '/usr/local/bin/github-mcp-server',
        'args': ['stdio'],
        'env': {
            'GITHUB_PERSONAL_ACCESS_TOKEN': pat_value
        }
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
    echo "Would you like to create the configuration anyway? (y/n): "
    read -n 1 CREATE_CONFIG
    echo ""
    
    if [[ "$CREATE_CONFIG" =~ ^[Yy]$ ]]; then
        echo ""
        echo "Do you have a GitHub Personal Access Token (PAT)? (y/n): "
        read -n 1 HAS_PAT
        echo ""
        
        if [[ "$HAS_PAT" =~ ^[Yy]$ ]]; then
            echo ""
            echo "How would you like to provide your GitHub PAT?"
            echo "1. Enter it directly (will be stored in config)"
            echo "2. Use environment variable \$GITHUB_PAT"
            echo ""
            echo "Choose (1 or 2): "
            read -n 1 PAT_CHOICE
            echo ""
            
            if [ "$PAT_CHOICE" = "1" ]; then
                echo ""
                echo "Enter your GitHub Personal Access Token:"
                read -s GITHUB_TOKEN
                echo ""
                PAT_VALUE="\"$GITHUB_TOKEN\""
            elif [ "$PAT_CHOICE" = "2" ]; then
                PAT_VALUE='"\$GITHUB_PAT"'
                echo ""
                echo "⚠️  Remember to set the GITHUB_PAT environment variable in your shell profile:"
                echo "   export GITHUB_PAT='your-token-here'"
                echo ""
            else
                echo "Invalid choice. Using environment variable option."
                PAT_VALUE='"\$GITHUB_PAT"'
            fi
        else
            echo ""
            echo "⚠️  Note: Without a PAT, the GitHub MCP Server will have limited functionality."
            echo "   You can get a PAT from: https://github.com/settings/tokens"
            echo ""
            PAT_VALUE='"\$GITHUB_PAT"'
        fi
        
        # Create the directory and configuration
        echo "⏳ Creating Claude Desktop configuration..."
        mkdir -p "$(dirname "$CONFIG_FILE")"
        python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'
pat_value = $PAT_VALUE

try:
    config = {
        'mcpServers': {
            'github': {
                'command': '/usr/local/bin/github-mcp-server',
                'args': ['stdio'],
                'env': {
                    'GITHUB_PERSONAL_ACCESS_TOKEN': pat_value
                }
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
echo "You can now use 'github-mcp-server' from the Terminal."
echo ""
echo "Press Enter to close this window..."
read

# Close the Terminal window
osascript -e 'tell application "Terminal" to close first window' &