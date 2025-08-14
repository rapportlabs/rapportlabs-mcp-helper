#!/bin/bash

# GitHub MCP Server Installation Script for macOS - Automator Version
# For use in Automator as "Run Shell Script" action

set -e

# Configuration
REPO="github/github-mcp-server"
VERSION="latest"
INSTALL_DIR="/usr/local/bin"

# Add /usr/local/bin to PATH for this script
export PATH="/usr/local/bin:$PATH"

# Helper function for displaying dialogs
show_dialog() {
    osascript -e "display dialog \"$1\" buttons {\"OK\"} default button 1 with title \"GitHub MCP Server Installer\""
}

show_dialog_with_choice() {
    # Use a simpler approach - check the exit code directly
    osascript <<EOF 2>/dev/null
display dialog "$1" buttons {"No", "Yes"} default button 2 with title "GitHub MCP Server Installer"
if button returned of result is "Yes" then
    return 0
else
    error number -128
end if
EOF
    return $?
}

get_text_input() {
    local prompt="$1"
    local default_text="${2:-}"
    local hidden="${3:-false}"
    
    if [ "$hidden" = "true" ]; then
        osascript -e "display dialog \"$prompt\" default answer \"\" with hidden answer buttons {\"Cancel\", \"OK\"} default button 2 with title \"GitHub MCP Server Installer\"" 2>/dev/null | awk -F: '{print $NF}'
    else
        osascript -e "display dialog \"$prompt\" default answer \"$default_text\" buttons {\"Cancel\", \"OK\"} default button 2 with title \"GitHub MCP Server Installer\"" 2>/dev/null | awk -F: '{print $NF}'
    fi
}

# Start installation
osascript -e 'display notification "Starting GitHub MCP Server installation..." with title "GitHub MCP Server Installer"'

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_SUFFIX="x86_64"
    ARCH_DISPLAY="Intel Mac"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="arm64"
    ARCH_DISPLAY="Apple Silicon Mac (M1/M2/M3)"
else
    show_dialog "❌ Unsupported architecture: $ARCH"
    exit 1
fi

# Check if already installed
if command -v github-mcp-server &> /dev/null || [ -x "$INSTALL_DIR/github-mcp-server" ]; then
    if [ -x "$INSTALL_DIR/github-mcp-server" ]; then
        CURRENT_VERSION=$("$INSTALL_DIR/github-mcp-server" --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    else
        CURRENT_VERSION=$(github-mcp-server --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    fi
    
    # Get latest version
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name":' | \
        cut -d '"' -f 4)
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        show_dialog "✅ You already have the latest version ($LATEST_VERSION)"
        exit 0
    else
        if ! show_dialog_with_choice "GitHub MCP Server is already installed.\n\nCurrent version: $CURRENT_VERSION\nLatest version: $LATEST_VERSION\n\nWould you like to upgrade?"; then
            exit 0
        fi
    fi
else
    if ! show_dialog_with_choice "This installer will:\n\n1. Download the latest GitHub MCP Server\n2. Install it to $INSTALL_DIR\n3. Configure Claude Desktop (optional)\n\nDetected: $ARCH_DISPLAY\n\nContinue with installation?"; then
        exit 0
    fi
fi

# Get the download URL
osascript -e 'display notification "Fetching download information..." with title "GitHub MCP Server Installer"'

DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep "browser_download_url.*Darwin_${ARCH_SUFFIX}.tar.gz" | \
    cut -d '"' -f 4)

VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep '"tag_name":' | \
    cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    show_dialog "❌ Failed to find download URL"
    exit 1
fi

osascript -e 'display notification "Downloading GitHub MCP Server..." with title "GitHub MCP Server Installer"'

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
curl -L --progress-bar -o "$TEMP_DIR/github-mcp-server.tar.gz" "$DOWNLOAD_URL"

osascript -e 'display notification "Extracting files..." with title "GitHub MCP Server Installer"'

# Extract
tar -xzf "$TEMP_DIR/github-mcp-server.tar.gz" -C "$TEMP_DIR"

# Find the binary
BINARY=$(find "$TEMP_DIR" -name "github-mcp-server" -type f | head -1)

if [ -z "$BINARY" ]; then
    show_dialog "❌ Binary not found in archive"
    exit 1
fi

# Install with admin privileges
osascript -e 'display notification "Installing (admin password required)..." with title "GitHub MCP Server Installer"'

# Request admin password and install
osascript -e "do shell script \"mkdir -p '$INSTALL_DIR' && mv '$BINARY' '$INSTALL_DIR/github-mcp-server' && chmod +x '$INSTALL_DIR/github-mcp-server'\" with administrator privileges"

# Add /usr/local/bin to PATH for this script
export PATH="/usr/local/bin:$PATH"

# Verify installation by checking the actual file
if [ -x "$INSTALL_DIR/github-mcp-server" ]; then
    INSTALLED_VERSION=$("$INSTALL_DIR/github-mcp-server" --version 2>&1 | head -1)
    osascript -e 'display notification "Installation successful!" with title "GitHub MCP Server Installer"'
else
    show_dialog "⚠️ Installation may have failed. Please check $INSTALL_DIR/github-mcp-server"
fi

# Claude Desktop Configuration
CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

if [ -f "$CONFIG_FILE" ]; then
    # Check if GitHub MCP is already configured
    if grep -q '"github"' "$CONFIG_FILE" 2>/dev/null; then
        show_dialog_with_choice "GitHub MCP Server is already configured in Claude Desktop.\n\nWould you like to reconfigure it?"
        if [ $? -eq 0 ]; then
            RECONFIGURE="yes"
        else
            show_dialog "✅ GitHub MCP Server is already installed and configured.\n\nNo changes were made."
            exit 0
        fi
    else
        show_dialog_with_choice "Would you like to configure GitHub MCP Server in Claude Desktop?"
        if [ $? -eq 0 ]; then
            RECONFIGURE="yes"
        else
            show_dialog "✅ Installation complete!\n\nGitHub MCP Server $VERSION has been installed to $INSTALL_DIR.\n\nConfiguration was skipped."
            exit 0
        fi
    fi
else
    show_dialog_with_choice "Claude Desktop config not found.\n\nWould you like to create the configuration?"
    if [ $? -eq 0 ]; then
        RECONFIGURE="yes"
        mkdir -p "$(dirname "$CONFIG_FILE")"
        echo '{"mcpServers":{}}' > "$CONFIG_FILE"
    else
        show_dialog "✅ Installation complete!\n\nGitHub MCP Server $VERSION has been installed to $INSTALL_DIR.\n\nConfiguration was skipped."
        exit 0
    fi
fi

# At this point, RECONFIGURE is always "yes" since we exit otherwise
if show_dialog_with_choice "Do you have a GitHub Personal Access Token (PAT)?\n\nA PAT is required for full functionality."; then
    # Get PAT from user
    GITHUB_TOKEN=$(get_text_input "Enter your GitHub Personal Access Token:" "" "true")
    
    if [ -n "$GITHUB_TOKEN" ]; then
        # Update the configuration
        osascript -e 'display notification "Updating Claude Desktop configuration..." with title "GitHub MCP Server Installer"'
        
        python3 -c "
import json
import sys

config_file = '$CONFIG_FILE'
pat_value = '$GITHUB_TOKEN'

try:
    # Read existing config or create new one
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
    
    print('Configuration updated successfully!')
except Exception as e:
    print(f'Error updating config: {e}')
    sys.exit(1)
"
        
        show_dialog "✅ Installation and configuration complete!\n\nGitHub MCP Server $VERSION has been installed to $INSTALL_DIR.\n\n⚠️ Please restart Claude Desktop for the changes to take effect."
    else
        show_dialog "❌ No token provided.\n\nInstallation completed at $INSTALL_DIR/github-mcp-server\n\nConfiguration skipped. You can manually configure it later."
    fi
else
    # Provide information about getting a PAT
    MESSAGE="GitHub MCP Server $VERSION has been installed to $INSTALL_DIR.

A GitHub Personal Access Token is required for full functionality.

To create a PAT:
1. Go to GitHub Settings > Developer Settings > Personal Access Tokens
2. Create a new token with appropriate permissions
3. Run this installer again to configure it

Installation completed successfully, but configuration was skipped."
    osascript -e "display dialog \"$MESSAGE\" buttons {\"OK\"} default button 1 with title \"GitHub MCP Server Installer\""
fi

exit 0
