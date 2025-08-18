#!/bin/bash

# Simple GitHub MCP Server Installer - No Xcode Required
set -e

echo "GitHub MCP Server Installer (No Xcode Required)"
echo "================================================"

# Configuration
REPO="github/github-mcp-server"
INSTALL_DIR="/usr/local/bin"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_SUFFIX="x86_64"
    echo "Detected: Intel Mac"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="arm64"
    echo "Detected: Apple Silicon Mac (M1/M2/M3)"
else
    echo "Error: Unsupported architecture: $ARCH"
    exit 1
fi

# Check if already installed
if [ -x "$INSTALL_DIR/github-mcp-server" ]; then
    echo "GitHub MCP Server is already installed at $INSTALL_DIR/github-mcp-server"
    read -p "Do you want to reinstall/update? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo ""
echo "This will install GitHub MCP Server to $INSTALL_DIR"
read -p "Continue? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Get download URL using curl (pre-installed on macOS)
echo ""
echo "Fetching latest release information..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep "browser_download_url.*Darwin_${ARCH_SUFFIX}.tar.gz" | \
    sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep '"tag_name":' | \
    sed 's/.*"tag_name": "\(.*\)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Failed to find download URL"
    exit 1
fi

echo "Found version: $VERSION"
echo "Download URL: $DOWNLOAD_URL"

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
echo ""
echo "Downloading GitHub MCP Server..."
curl -L --progress-bar -o "$TEMP_DIR/github-mcp-server.tar.gz" "$DOWNLOAD_URL"

# Extract using tar (pre-installed on macOS)
echo "Extracting..."
tar -xzf "$TEMP_DIR/github-mcp-server.tar.gz" -C "$TEMP_DIR"

# Find the binary - using basic shell commands instead of find
BINARY=""
for file in "$TEMP_DIR"/* "$TEMP_DIR"/*/*; do
    if [ -f "$file" ] && [ "$(basename "$file")" = "github-mcp-server" ]; then
        BINARY="$file"
        break
    fi
done

if [ -z "$BINARY" ]; then
    echo "Error: Binary not found in archive"
    exit 1
fi

# Install with sudo
echo ""
echo "Installing to $INSTALL_DIR (requires admin password)..."
sudo mkdir -p "$INSTALL_DIR"
sudo mv "$BINARY" "$INSTALL_DIR/github-mcp-server"
sudo chmod +x "$INSTALL_DIR/github-mcp-server"

# Verify installation
if [ -x "$INSTALL_DIR/github-mcp-server" ]; then
    echo ""
    echo "✅ Installation successful!"
    echo "GitHub MCP Server $VERSION has been installed to $INSTALL_DIR"
else
    echo "⚠️ Installation may have failed. Please check $INSTALL_DIR/github-mcp-server"
    exit 1
fi

# Claude Desktop Configuration
echo ""
echo "----------------------------------------"
echo "Claude Desktop Configuration"
echo "----------------------------------------"

CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Claude Desktop config not found."
    read -p "Create configuration? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo '{"mcpServers":{}}' > "$CONFIG_FILE"
    else
        echo "Configuration skipped. You can manually configure it later."
        exit 0
    fi
fi

echo ""
read -p "Do you have a GitHub Personal Access Token (PAT)? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your GitHub Personal Access Token:"
    read -s GITHUB_TOKEN
    echo ""
    
    if [ -n "$GITHUB_TOKEN" ]; then
        # Use python3 (pre-installed on macOS) to update JSON
        python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'
pat_value = '$GITHUB_TOKEN'

try:
    # Read existing config
    try:
        with open(config_file, 'r') as f:
            config = json.load(f)
    except:
        config = {}
    
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
    print('')
    print('⚠️  Please restart Claude Desktop for the changes to take effect.')
except Exception as e:
    print(f'Error updating config: {e}')
    sys.exit(1)
"
    else
        echo "No token provided. Configuration skipped."
    fi
else
    echo ""
    echo "To create a GitHub PAT:"
    echo "1. Go to GitHub Settings > Developer Settings > Personal Access Tokens"
    echo "2. Create a new token with appropriate permissions"
    echo "3. Run this installer again to configure it"
    echo ""
    echo "Installation completed, but configuration was skipped."
fi

echo ""
echo "Done!"