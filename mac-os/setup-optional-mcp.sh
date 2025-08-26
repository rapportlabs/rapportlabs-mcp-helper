#!/bin/bash

# GitHub MCP Server Installer - Final Version (No Xcode Required)
set -e

echo "GitHub MCP Server Installer"
echo "==========================="

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

# Get download URL
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

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
echo ""
echo "Downloading GitHub MCP Server..."
curl -L --progress-bar -o "$TEMP_DIR/github-mcp-server.tar.gz" "$DOWNLOAD_URL"

# Extract
echo "Extracting..."
tar -xzf "$TEMP_DIR/github-mcp-server.tar.gz" -C "$TEMP_DIR"

# Find the binary
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
echo "=========================================="
echo "Claude Desktop Configuration"
echo "=========================================="

CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

# Function to update config using osascript (JavaScript for Automation)
update_config_with_jxa() {
    local token="$1"
    local config_file="$2"
    
    # Create backup
    cp "$config_file" "$config_file.backup" 2>/dev/null || true
    
    # Use osascript with JavaScript to handle JSON properly
    osascript -l JavaScript << EOF
var app = Application.currentApplication();
app.includeStandardAdditions = true;

// Read file or create empty config
var config = {};
try {
    var configPath = "$config_file";
    var configContent = app.read(Path(configPath));
    config = JSON.parse(configContent);
} catch(e) {
    // File doesn't exist or is invalid
    config = {};
}

// Ensure mcpServers exists
if (!config.mcpServers) {
    config.mcpServers = {};
}

// Add or update github config
config.mcpServers.github = {
    "command": "/usr/local/bin/github-mcp-server",
    "args": ["stdio"],
    "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$token"
    }
};

// Write back to file
try {
    var configPath = "$config_file";
    var configDir = configPath.substring(0, configPath.lastIndexOf('/'));
    
    // Create directory if it doesn't exist
    app.doShellScript("mkdir -p '" + configDir + "'");
    
    // Write the config file
    var file = app.openForAccess(Path(configPath), { writePermission: true });
    app.setEof(file, { to: 0 }); // Clear existing content
    app.write(JSON.stringify(config, null, 2), { to: file });
    app.closeAccess(file);
    
    "success";
} catch(e) {
    "error: " + e.toString();
}
EOF
}

# Simple bash-only fallback for config creation
create_simple_config() {
    local token="$1"
    local config_file="$2"
    
    mkdir -p "$(dirname "$config_file")"
    
    # If file exists, backup and overwrite
    if [ -f "$config_file" ]; then
        cp "$config_file" "$config_file.backup"
        echo "⚠️  Note: Existing config backed up to $config_file.backup"
    fi
    
    # Create new config with just github server
    cat > "$config_file" << EOF
{
  "mcpServers": {
    "github": {
      "command": "/usr/local/bin/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "$token"
      }
    }
  }
}
EOF
}

echo ""
read -p "Do you have a GitHub Personal Access Token (PAT)? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "Enter your GitHub Personal Access Token:"
    read -s GITHUB_TOKEN
    echo ""
    
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Updating configuration..."
        
        # Try to use osascript/JXA first (works on all macOS without Xcode)
        result=$(update_config_with_jxa "$GITHUB_TOKEN" "$CONFIG_FILE" 2>&1)
        
        if [[ "$result" == "success" ]]; then
            echo "✅ Configuration updated successfully!"
            if [ -f "$CONFIG_FILE.backup" ]; then
                echo "   Previous config backed up to: $CONFIG_FILE.backup"
            fi
        else
            echo "⚠️  Advanced config merge failed, using simple replacement..."
            create_simple_config "$GITHUB_TOKEN" "$CONFIG_FILE"
            echo "✅ Configuration created (simple mode)"
            echo "   If you had other MCP servers, restore from: $CONFIG_FILE.backup"
        fi
        
        echo ""
        echo "⚠️  Please restart Claude Desktop for the changes to take effect."
    else
        echo "No token provided. Configuration skipped."
    fi
else
    echo ""
    echo "To get a GitHub Personal Access Token:"
    echo "1. Go to: https://github.com/settings/tokens"
    echo "2. Click 'Generate new token (classic)'"
    echo "3. Give it 'repo' scope"
    echo "4. Run this installer again with your token"
    echo ""
    echo "Installation completed, configuration skipped."
fi

echo ""
echo "Done!"