#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info() { echo -e "${BLUE}$1${NC}"; }

echo "========================================"
echo "GitHub MCP Server Installation Script"
echo "========================================"
echo ""
print_info "[INFO] This script will install the GitHub MCP Server for use with Claude Desktop."
print_info "[INFO] The GitHub MCP Server allows Claude to interact with GitHub repositories."
echo ""
while true; do
    read -p "Do you want to install the GitHub MCP Server? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        print_warning "[CANCELLED] Installation cancelled by user."
        exit 0
    else
        print_error "[ERROR] Invalid input. Please enter 'y' or 'n'."
    fi
done

# Configuration
REPO="github/github-mcp-server"
INSTALL_DIR="/usr/local/bin"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
    ARCH_SUFFIX="x86_64"
    print_info "[PLATFORM] Detected: Intel Mac"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="arm64"
    print_info "[PLATFORM] Detected: Apple Silicon Mac (M1/M2/M3)"
else
    print_error "[ERROR] Unsupported architecture: $ARCH"
    exit 1
fi

# Check if already installed
if [ -x "$INSTALL_DIR/github-mcp-server" ]; then
    print_warning "[CHECK] GitHub MCP Server is already installed at $INSTALL_DIR/github-mcp-server"
    while true; do
        read -p "Do you want to reinstall/update? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            break
        elif [[ $REPLY =~ ^[Nn]$ ]]; then
            exit 0
        else
            print_error "[ERROR] Invalid input. Please enter 'y' or 'n'."
        fi
    done
fi

echo ""
print_info "[INSTALL] This will install GitHub MCP Server to $INSTALL_DIR"
while true; do
    read -p "Continue? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        exit 0
    else
        print_error "[ERROR] Invalid input. Please enter 'y' or 'n'."
    fi
done

# Get download URL
echo ""
print_info "[FETCH] Fetching latest release information..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep "browser_download_url.*Darwin_${ARCH_SUFFIX}.tar.gz" | \
    sed 's/.*"browser_download_url": "\(.*\)".*/\1/')

VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep '"tag_name":' | \
    sed 's/.*"tag_name": "\(.*\)".*/\1/')

if [ -z "$DOWNLOAD_URL" ]; then
    print_error "[ERROR] Failed to find download URL"
    exit 1
fi

print_success "[VERSION] Found version: $VERSION"

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
echo ""
print_info "[DOWNLOAD] Downloading GitHub MCP Server..."
curl -L --progress-bar -o "$TEMP_DIR/github-mcp-server.tar.gz" "$DOWNLOAD_URL"

# Extract
print_info "[EXTRACT] Extracting archive..."
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
    print_error "[ERROR] Binary not found in archive"
    exit 1
fi

# Install with sudo
echo ""
print_warning "[SUDO] Installing to $INSTALL_DIR (Enter MacBook Password)..."
sudo mkdir -p "$INSTALL_DIR"
sudo mv "$BINARY" "$INSTALL_DIR/github-mcp-server"
sudo chmod +x "$INSTALL_DIR/github-mcp-server"

# Verify installation
if [ -x "$INSTALL_DIR/github-mcp-server" ]; then
    echo ""
    print_success "✅ [SUCCESS] Installation successful!"
    print_success "[INSTALLED] GitHub MCP Server $VERSION has been installed to $INSTALL_DIR"
else
    print_error "⚠️ [ERROR] Installation may have failed. Please check $INSTALL_DIR/github-mcp-server"
    exit 1
fi

# Claude Desktop Configuration
echo ""
echo "=========================================="
print_info "Claude Desktop Configuration"
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
        print_warning "⚠️  [BACKUP] Existing config backed up to $config_file.backup"
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
while true; do
    read -p "Do you have a GitHub Personal Access Token (PAT)? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        REPLY="n"
        break
    else
        print_error "[ERROR] Invalid input. Please enter 'y' or 'n'."
    fi
done

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    print_info "[INPUT] Enter your GitHub Personal Access Token:"
    read -s GITHUB_TOKEN
    echo ""
    
    if [ -n "$GITHUB_TOKEN" ]; then
        print_info "[CONFIG] Updating configuration..."
        
        # Try to use osascript/JXA first (works on all macOS without Xcode)
        result=$(update_config_with_jxa "$GITHUB_TOKEN" "$CONFIG_FILE" 2>&1)
        
        if [[ "$result" == "success" ]]; then
            print_success "✅ [SUCCESS] Configuration updated successfully!"
            if [ -f "$CONFIG_FILE.backup" ]; then
                print_info "[BACKUP] Previous config backed up to: $CONFIG_FILE.backup"
            fi
        else
            print_warning "⚠️  [FALLBACK] Advanced config merge failed, using simple replacement..."
            create_simple_config "$GITHUB_TOKEN" "$CONFIG_FILE"
            print_success "✅ [SUCCESS] Configuration created (simple mode)"
            print_info "[NOTE] If you had other MCP servers, restore from: $CONFIG_FILE.backup"
        fi
        
        echo ""
        print_warning "⚠️  [RESTART] Please restart Claude Desktop for the changes to take effect."
    else
        print_warning "[SKIP] No token provided. Configuration skipped."
    fi
else
    echo ""
    print_info "[HELP] To get a GitHub Personal Access Token:"
    print_info "  1. Go to: https://github.com/settings/tokens"
    print_info "  2. Click 'Generate new token (classic)'"
    print_info "  3. Give it 'repo' scope"
    print_info "  4. Run this installer again with your token"
    echo ""
    print_warning "[COMPLETE] Installation completed, configuration skipped."
fi

echo ""
print_success "✅ [DONE] Script completed successfully!"
