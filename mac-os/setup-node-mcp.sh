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
echo "Node.js 24.4.1 and mcp-remote Setup Script"
echo "(mcp-remote from geelen/mcp-remote)"
echo "========================================"
echo

# Detect architecture and OS
ARCH=$(uname -m)
OS=$(uname -s)

if [[ "$OS" == "Darwin" ]]; then
    print_info "[PLATFORM CHECK] Running on macOS - OK"
    if [[ "$ARCH" == "x86_64" ]]; then
        NODE_ARCH="x64"
        print_info "[ARCH CHECK] Intel x64 architecture detected"
    elif [[ "$ARCH" == "arm64" ]]; then
        NODE_ARCH="arm64"
        print_info "[ARCH CHECK] Apple Silicon (ARM64) architecture detected"
    else
        print_error "[ERROR] Unsupported architecture: $ARCH"
        exit 1
    fi
else
    print_error "[ERROR] This script is designed for macOS only"
    exit 1
fi
echo

# Check for required system tools (all should be available on macOS by default)
echo "Checking system requirements..."
for tool in curl tar; do
    if ! command -v $tool >/dev/null 2>&1; then
        print_error "[ERROR] Required tool '$tool' not found!"
        echo "This tool should be available on macOS by default."
        exit 1
    fi
done
print_info "[SYSTEM CHECK] All required tools available - OK"
echo

# Check Node.js
echo "Checking for existing Node.js installation..."
SKIP_NODE_INSTALL=0

if command -v node >/dev/null 2>&1; then
    CURRENT_NODE_VERSION=$(node --version 2>/dev/null || echo "unknown")
    echo "Found existing Node.js:"
    echo "Current version: $CURRENT_NODE_VERSION"
    
    # Check if it's version 24.4.1
    if [[ "$CURRENT_NODE_VERSION" == "v24.4.1" ]]; then
        print_success "[SUCCESS] Node.js v24.4.1 is already installed!"
        SKIP_NODE_INSTALL=1
    else
        echo "This will be updated to v24.4.1"
    fi
else
    echo "Node.js is NOT installed."
    echo "Will install Node.js v24.4.1"
fi

echo
echo "----------------------------------------"
echo "Press Enter to proceed with setup..."
echo "----------------------------------------"
read -r

# Install Node.js if needed
if [ $SKIP_NODE_INSTALL -eq 1 ]; then
    echo "Skipping Node.js installation - already at target version."
else
    echo "Installing Node.js v24.4.1..."
    echo "Downloading directly from nodejs.org..."
    echo "This may take several minutes..."
    echo
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download Node.js binary
    NODE_URL="https://nodejs.org/dist/v24.4.1/node-v24.4.1-darwin-${NODE_ARCH}.tar.gz"
    echo "Downloading from: $NODE_URL"
    
    if ! curl -L -o "node.tar.gz" "$NODE_URL"; then
        print_error "[ERROR] Failed to download Node.js!"
        echo "Please check your internet connection or install manually from:"
        echo "https://nodejs.org/"
        exit 1
    fi
    
    # Extract the archive
    echo "Extracting Node.js..."
    tar -xzf node.tar.gz
    
    # Find the extracted directory
    NODE_DIR=$(find . -name "node-v24.4.1-darwin-*" -type d | head -1)
    
    if [ -z "$NODE_DIR" ]; then
        print_error "[ERROR] Failed to extract Node.js!"
        exit 1
    fi
    
    # Install to /usr/local (standard location)
    echo "Installing Node.js to /usr/local..."
    
    # Check if we need sudo for installation
    if [ -w "/usr/local/bin" ] && [ -w "/usr/local/lib" ]; then
        SUDO_CMD=""
    else
        echo "Administrator privileges required for installation..."
        SUDO_CMD="sudo"
    fi
    
    # Copy binaries and libraries
    $SUDO_CMD cp -R "$NODE_DIR"/* /usr/local/
    
    # Clean up
    cd /
    rm -rf "$TEMP_DIR"
    
    echo
    echo "Node.js installation completed."
fi
echo

# Refresh PATH (mainly for new shell sessions)
echo "Refreshing environment variables..."
# Source common profile files to pick up any new PATH additions
[ -f "$HOME/.bashrc" ] && source "$HOME/.bashrc" >/dev/null 2>&1 || true
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" >/dev/null 2>&1 || true

# Verify Node.js
echo "Verifying Node.js installation..."
if ! command -v node >/dev/null 2>&1; then
    echo
    print_error "[ERROR] Node.js installation verification failed!"
    echo
    echo "Please:"
    echo "  1. Close this terminal"
    echo "  2. Open a new terminal"
    echo "  3. Run this script again"
    echo
    exit 1
fi

echo
print_success "[SUCCESS] Node.js installed successfully!"
echo
echo "Node version:"
node --version
echo "NPM version:"
npm --version
echo "NPX version:"
npx --version

echo
echo "----------------------------------------"
echo "Press Enter to install mcp-remote..."
echo "----------------------------------------"
read -r

# Install mcp-remote from geelen/mcp-remote
echo
echo "Installing mcp-remote from https://github.com/geelen/mcp-remote..."
echo "This may take a few minutes..."
echo

# Check if we need sudo for npm global install (same logic as Node.js installation)
if [ -w "/usr/local/lib/node_modules" ] 2>/dev/null; then
    NPM_SUDO=""
else
    echo "Administrator privileges required for global npm installation..."
    NPM_SUDO="sudo"
fi

if ! $NPM_SUDO npm install -g mcp-remote; then
    echo
    print_warning "[WARNING] Retrying with --force flag..."
    echo
    $NPM_SUDO npm install -g mcp-remote --force
fi

echo
echo "Verifying mcp-remote installation..."
echo "Checking installed version via npm..."
MCP_VERSION=$(npm list -g mcp-remote 2>/dev/null | grep mcp-remote@ | sed 's/.*mcp-remote@//' | sed 's/ .*//' || echo "unknown")
echo "mcp-remote version: $MCP_VERSION"

echo
echo "========================================"
print_success "SETUP COMPLETE!"
echo "========================================"
echo
echo "Installed Software:"
echo "-------------------"
echo "Node version:"
node --version
echo "NPM version:"
npm --version
echo "NPX version:"
npx --version
echo "mcp-remote version:"
echo "$MCP_VERSION"
echo
echo "You can use mcp-remote with:"
echo "  mcp-remote [command]"
echo
echo "========================================"
echo
echo "Press Enter to close this window..."
read -r