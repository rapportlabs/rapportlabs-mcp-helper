#!/bin/bash

# GitHub MCP Server Installer - No Python/Xcode Required
set -e

echo "GitHub MCP Server Installer (No Dependencies)"
echo "=============================================="

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

# Get download URL using curl and sed (both pre-installed on macOS)
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

# Extract using tar (pre-installed on macOS)
echo "Extracting..."
tar -xzf "$TEMP_DIR/github-mcp-server.tar.gz" -C "$TEMP_DIR"

# Find the binary - using basic shell commands
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

# Function to update JSON using sed/awk (no Python needed)
update_config_with_token() {
    local token="$1"
    local config_file="$2"
    
    # Create backup
    cp "$config_file" "$config_file.backup" 2>/dev/null || true
    
    # Check if file exists and has content
    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        # Create new config file
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
    else
        # Check if github server already exists in config
        if grep -q '"github"' "$config_file"; then
            echo "⚠️  GitHub MCP Server already configured in Claude Desktop."
            echo "   To update manually, edit: $config_file"
            echo ""
            echo "   Add or update the 'github' section:"
            echo '   "github": {'
            echo '     "command": "/usr/local/bin/github-mcp-server",'
            echo '     "args": ["stdio"],'
            echo '     "env": {'
            echo "       \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"$token\""
            echo '     }'
            echo '   }'
        else
            echo "⚠️  Existing config found. Please manually add to $config_file:"
            echo ""
            echo "In the 'mcpServers' section, add:"
            echo '  "github": {'
            echo '    "command": "/usr/local/bin/github-mcp-server",'
            echo '    "args": ["stdio"],'
            echo '    "env": {'
            echo "      \"GITHUB_PERSONAL_ACCESS_TOKEN\": \"your-token-here\""
            echo '    }'
            echo '  }'
        fi
        return 1
    fi
    
    return 0
}

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Claude Desktop config not found."
    read -p "Create configuration? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        # Create empty JSON structure
        echo '{"mcpServers":{}}' > "$CONFIG_FILE"
    else
        echo ""
        echo "Configuration skipped."
        echo "To configure manually later, create/edit:"
        echo "$CONFIG_FILE"
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
        if update_config_with_token "$GITHUB_TOKEN" "$CONFIG_FILE"; then
            echo "✅ Configuration file created/updated!"
            echo ""
            echo "⚠️  Please restart Claude Desktop for the changes to take effect."
        fi
    else
        echo "No token provided. Configuration skipped."
    fi
else
    echo ""
    echo "Manual configuration instructions:"
    echo "=================================="
    echo ""
    echo "1. Create a GitHub Personal Access Token:"
    echo "   - Go to GitHub Settings > Developer Settings > Personal Access Tokens"
    echo "   - Create a new token with repo permissions"
    echo ""
    echo "2. Edit the Claude Desktop config file:"
    echo "   $CONFIG_FILE"
    echo ""
    echo "3. Add this configuration in the 'mcpServers' section:"
    echo '   "github": {'
    echo '     "command": "/usr/local/bin/github-mcp-server",'
    echo '     "args": ["stdio"],'
    echo '     "env": {'
    echo '       "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token-here"'
    echo '     }'
    echo '   }'
    echo ""
    echo "4. Restart Claude Desktop"
fi

echo ""
echo "Installation complete!"