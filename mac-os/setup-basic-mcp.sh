#!/bin/bash

set -e  # Exit on error

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

# Script header
echo "========================================"
echo "Node.js 24.4.1 and mcp-remote 0.1.18 Setup Script"
echo "(No git/Xcode dependencies - Using nvm for Node.js management)"
echo "========================================"
echo

# Detect OS
OS=$(uname -s)

if [[ "$OS" != "Darwin" ]]; then
    print_error "[ERROR] This script is designed for macOS only"
    exit 1
fi

print_info "[PLATFORM CHECK] Running on macOS - OK"
echo

# Check for curl (should be available on macOS by default)
if ! command -v curl >/dev/null 2>&1; then
    print_error "[ERROR] Required tool 'curl' not found!"
    echo "This tool should be available on macOS by default."
    exit 1
fi
print_info "[SYSTEM CHECK] curl is available - OK"
echo

# Pinned versions
NVM_VERSION="v0.39.0"
NODE_VERSION="24.4.1"
MCP_REMOTE_VERSION="0.1.18"

echo "Versions to install:"
echo "  nvm: $NVM_VERSION"
echo "  Node.js: $NODE_VERSION"
echo "  mcp-remote: $MCP_REMOTE_VERSION"
echo

# Check if nvm is already installed
echo "Checking for nvm installation..."
if [ -s "$HOME/.nvm/nvm.sh" ]; then
    print_info "[NVM CHECK] nvm is already installed"
    # Load nvm
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
    
    CURRENT_NVM_VERSION=$(nvm --version 2>/dev/null || echo "unknown")
    echo "Current nvm version: $CURRENT_NVM_VERSION"
    SKIP_NVM_INSTALL=1
else
    print_info "[NVM CHECK] nvm is not installed - will install $NVM_VERSION"
    SKIP_NVM_INSTALL=0
fi

# Check Node.js
echo
echo "Checking for existing Node.js installation..."
SKIP_NODE_INSTALL=0

# Load nvm if available
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" >/dev/null 2>&1

if command -v node >/dev/null 2>&1; then
    CURRENT_NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo "Found existing Node.js: $CURRENT_NODE_VERSION"
    
    # Check if it's version 24.1.1
    if [[ "$CURRENT_NODE_VERSION" == "v$NODE_VERSION" ]]; then
        print_success "[SUCCESS] Node.js v$NODE_VERSION is already installed!"
        SKIP_NODE_INSTALL=1
    else
        echo "This will be updated to v$NODE_VERSION using nvm"
    fi
else
    echo "Node.js is NOT installed."
    echo "Will install Node.js v$NODE_VERSION using nvm"
fi

echo
echo "========================================"
echo "Ready to proceed with installation"
echo "========================================"
echo
print_warning "⚠️  IMPORTANT NOTICE FOR DEVELOPERS ⚠️"
echo "This script is designed for users WITHOUT existing Node.js development environments."
echo "If you are a developer with existing Node.js/nvm setups, this script may:"
echo "  • Change your default Node.js version to 24.4.1"
echo "  • Modify your nvm configuration"
echo "  • Install global npm packages that may conflict with your projects"
echo
echo "For experienced developers, consider manual installation instead."
echo

while true; do
    read -p "Do you want to continue with the installation? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        print_info "Installation cancelled by user."
        exit 0
    else
        print_error "Invalid input. Please enter 'y' or 'n'."
    fi
done

echo
# Install nvm if needed
if [ $SKIP_NVM_INSTALL -eq 0 ]; then
    echo "Installing nvm $NVM_VERSION..."
    echo "Downloading nvm as tarball (no git required)..."
    
    # Create nvm directory
    mkdir -p "$HOME/.nvm"
    
    # Download nvm tarball instead of using git
    TARBALL_URL="https://github.com/nvm-sh/nvm/archive/$NVM_VERSION.tar.gz"
    TEMP_DIR=$(mktemp -d)
    
    echo "Downloading from $TARBALL_URL..."
    if ! curl -L "$TARBALL_URL" | tar -xz -C "$TEMP_DIR"; then
        print_error "[ERROR] Failed to download nvm tarball!"
        echo "Please check your internet connection."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Move nvm files to the correct location
    mv "$TEMP_DIR/nvm-${NVM_VERSION#v}"/* "$HOME/.nvm/"
    rm -rf "$TEMP_DIR"
    
    # Make nvm.sh executable
    chmod +x "$HOME/.nvm/nvm.sh"
    
    # Add nvm to profile files if they exist
    for profile in ~/.bash_profile ~/.zshrc ~/.profile ~/.bashrc; do
        if [[ -f "$profile" ]]; then
            if ! grep -q 'NVM_DIR.*nvm' "$profile"; then
                echo 'export NVM_DIR="$HOME/.nvm"' >> "$profile"
                echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm' >> "$profile"
                echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion' >> "$profile"
                echo "Added nvm configuration to $profile"
            fi
        fi
    done
    
    print_success "[SUCCESS] nvm $NVM_VERSION installed successfully (without git)!"
    echo
fi

# Load nvm
echo "Loading nvm..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Verify nvm is loaded
if ! command -v nvm >/dev/null 2>&1; then
    print_error "[ERROR] Failed to load nvm!"
    echo "Please restart your terminal and run this script again."
    exit 1
fi

print_success "[SUCCESS] nvm loaded successfully!"
echo "nvm version: $(nvm --version)"
echo

# Install Node.js if needed
if [ $SKIP_NODE_INSTALL -eq 1 ]; then
    echo "Skipping Node.js installation - already at target version."
else
    echo "Installing Node.js v$NODE_VERSION using nvm..."
    echo "This may take several minutes..."
    echo
    
    # Install Node.js 24.1.1
    if ! nvm install $NODE_VERSION; then
        print_error "[ERROR] Failed to install Node.js v$NODE_VERSION!"
        exit 1
    fi
    
    # Use Node.js 24.1.1
    nvm use $NODE_VERSION
    
    # Set as default
    nvm alias default $NODE_VERSION
    
    print_success "[SUCCESS] Node.js v$NODE_VERSION installed and set as default!"
fi
echo

# Verify Node.js installation
echo "Verifying Node.js installation..."

# Load nvm and use the correct version
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use $NODE_VERSION >/dev/null 2>&1

if ! command -v node >/dev/null 2>&1; then
    print_error "[ERROR] Node.js installation verification failed!"
    exit 1
fi

# Check version
CURRENT_VERSION=$(node --version)
if [[ "$CURRENT_VERSION" != "v$NODE_VERSION" ]]; then
    print_error "[ERROR] Node.js version mismatch!"
    echo "Expected: v$NODE_VERSION"
    echo "Current: $CURRENT_VERSION"
    exit 1
fi

echo
print_success "[SUCCESS] Node.js installed successfully!"
echo
echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"
echo "NPX version: $(npx --version)"
echo

# Install mcp-remote from geelen/mcp-remote
echo "========================================"
echo "Installing mcp-remote@$MCP_REMOTE_VERSION"
echo "========================================"
echo

# Ensure we're using the correct Node.js/npm through nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use $NODE_VERSION >/dev/null 2>&1

echo "Using Node.js $(node --version) and npm $(npm --version)"
echo

# Install specific version of mcp-remote
echo "Installing mcp-remote@$MCP_REMOTE_VERSION from npm..."
if ! npm install -g mcp-remote@$MCP_REMOTE_VERSION; then
    print_error "[ERROR] Failed to install mcp-remote@$MCP_REMOTE_VERSION"
    exit 1
fi

echo
echo "Verifying mcp-remote installation..."

# Ensure we're still using nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use $NODE_VERSION >/dev/null 2>&1

# Check mcp-remote version
MCP_VERSION=$(npm list -g mcp-remote 2>/dev/null | grep mcp-remote@ | sed 's/.*mcp-remote@//' | sed 's/ .*//' || echo "unknown")
echo "mcp-remote version: $MCP_VERSION"

if [[ "$MCP_VERSION" != "$MCP_REMOTE_VERSION" ]]; then
    print_warning "[WARNING] mcp-remote version might not match exactly. Expected: $MCP_REMOTE_VERSION, Got: $MCP_VERSION"
fi

print_success "[SUCCESS] mcp-remote installed!"
echo

# Configure Claude Desktop MCP
echo "========================================"
echo "Configuring Claude Desktop MCP servers"
echo "========================================"
echo

# Define the Claude Desktop config path for macOS
CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

# Create the directory if it doesn't exist
if [ ! -d "$CONFIG_DIR" ]; then
    echo "Creating configuration directory: $CONFIG_DIR"
    mkdir -p "$CONFIG_DIR"
    if [ $? -ne 0 ]; then
        print_error "[ERROR] Failed to create directory $CONFIG_DIR"
        exit 1
    fi
fi

# Check if config already exists
if [ -f "$CONFIG_FILE" ]; then
    echo "Existing configuration found at $CONFIG_FILE"
    echo "Creating backup..."
    cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
    print_info "Backup created successfully"
fi

# Create the configuration with rpls and queenit servers
echo "Creating Claude Desktop configuration..."

cat > "$CONFIG_FILE" << 'EOF'
{
  "mcpServers": {
    "rpwiki": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp"
      ]
    },
    "notion": {
      "command": "npx",
      "args": [
        "-y",
        "mcp-remote",
        "https://mcp.notion.com/mcp"
      ]
    },
    "bigquery": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
      ]
    },
    "slack": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://slack-mcp.damoa.rapportlabs.dance/sse"
      ]
    },
    "queenit": {
      "command": "npx",
      "args": [
        "mcp-remote",
        "https://mcp.rapportlabs.kr/mcp"
      ]
    }
  }
}
EOF

if [ $? -eq 0 ]; then
    print_success "[SUCCESS] Configuration created successfully!"
else
    print_error "[ERROR] Failed to create configuration file"
    exit 1
fi

echo
echo "========================================"
echo "Verification Complete!"
echo "========================================"
echo

# Final verification
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
nvm use $NODE_VERSION >/dev/null 2>&1

echo "Installed Software:"
echo "-------------------"
echo "nvm version: $(nvm --version)"
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"
echo "NPX version: $(npx --version)"
echo "mcp-remote version: $MCP_VERSION"
echo
echo "MCP Configuration:"
echo "------------------"
echo "Config file: $CONFIG_FILE"
echo "Configured servers:"
echo "  - rpls: https://agentgateway.damoa.rapportlabs.dance/mcp"
echo "  - queenit: https://mcp.rapportlabs.kr/mcp"
echo

print_success "========================================"
print_success "INSTALLATION COMPLETE!"
print_success "========================================"
echo
print_info "Please restart Claude Desktop for the changes to take effect."
echo
echo "You can now use mcp-remote with:"
echo "  npx mcp-remote <url>"
echo
echo "Setup complete! 🎉"
