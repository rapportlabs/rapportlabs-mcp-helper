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
echo "You can now use 'github-mcp-server' from the Terminal."
echo ""
echo "Press Enter to close this window..."
read

# Close the Terminal window
osascript -e 'tell application "Terminal" to close first window' &