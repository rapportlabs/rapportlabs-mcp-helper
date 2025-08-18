#!/bin/bash

# GitHub MCP Server Installer - Smart Config Merge
set -e

echo "GitHub MCP Server Installer (Smart Config)"
echo "=========================================="

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

# Function to merge config using pure bash
merge_github_config() {
    local token="$1"
    local config_file="$2"
    
    # Create backup
    cp "$config_file" "$config_file.backup" 2>/dev/null || true
    
    # GitHub server configuration to add
    local github_config='    "github": {
      "command": "/usr/local/bin/github-mcp-server",
      "args": ["stdio"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "'$token'"
      }
    }'
    
    if [ ! -f "$config_file" ] || [ ! -s "$config_file" ]; then
        # Create new config file
        cat > "$config_file" << EOF
{
  "mcpServers": {
${github_config}
  }
}
EOF
        echo "✅ Created new config file with GitHub MCP server"
    else
        # Read existing file
        local content=$(cat "$config_file")
        
        # Check if github already exists and remove it
        if echo "$content" | grep -q '"github"'; then
            echo "Found existing GitHub config, updating..."
            
            # Create a temp file to work with
            local temp_file="$config_file.temp"
            local in_github=0
            local brace_count=0
            local skip_comma=0
            
            # Process line by line to remove existing github config
            while IFS= read -r line; do
                # Check if we're entering github config
                if [[ $line == *'"github"'* ]] && [[ $in_github -eq 0 ]]; then
                    in_github=1
                    brace_count=0
                    continue
                fi
                
                # Count braces if we're in github config
                if [[ $in_github -eq 1 ]]; then
                    # Count opening braces
                    local opens=$(echo "$line" | grep -o '{' | wc -l)
                    # Count closing braces  
                    local closes=$(echo "$line" | grep -o '}' | wc -l)
                    brace_count=$((brace_count + opens - closes))
                    
                    # If brace count is back to 0, we've closed the github section
                    if [[ $brace_count -eq 0 ]] && [[ $line == *"}"* ]]; then
                        in_github=0
                        # Check if next line is a comma and skip it
                        skip_comma=1
                    fi
                    continue
                fi
                
                # Skip comma after github block if needed
                if [[ $skip_comma -eq 1 ]]; then
                    if [[ $line == *","* ]] && [[ $(echo "$line" | tr -d ' \t') == "," ]]; then
                        skip_comma=0
                        continue
                    fi
                    skip_comma=0
                fi
                
                # Write non-github lines
                echo "$line" >> "$temp_file"
            done < "$config_file"
            
            # Now add the new github config
            # Find where to insert (inside mcpServers)
            local result=""
            local added=0
            
            while IFS= read -r line; do
                result+="$line"$'\n'
                
                # Add github config after "mcpServers": {
                if [[ $line == *'"mcpServers"'* ]] && [[ $added -eq 0 ]]; then
                    # Read next line (should be {)
                    IFS= read -r line
                    result+="$line"$'\n'
                    
                    # Check if mcpServers is empty
                    IFS= read -r next_line
                    if [[ $next_line == *"}"* ]]; then
                        # Empty mcpServers, add github config
                        result+="${github_config}"$'\n'
                    else
                        # Has other servers, add github config with comma
                        result+="${github_config},"$'\n'
                        result+="$next_line"$'\n'
                    fi
                    added=1
                fi
            done < "$temp_file"
            
            echo "$result" > "$config_file"
            rm -f "$temp_file"
            
        else
            # No existing github config, need to add it to mcpServers
            echo "Adding GitHub config to existing file..."
            
            # Check if mcpServers exists
            if echo "$content" | grep -q '"mcpServers"'; then
                # Add github config inside existing mcpServers
                # This is a simplified approach - finds mcpServers and adds after the opening brace
                
                local new_content=$(echo "$content" | sed '/"mcpServers".*{/a\
    "github": {\
      "command": "/usr/local/bin/github-mcp-server",\
      "args": ["stdio"],\
      "env": {\
        "GITHUB_PERSONAL_ACCESS_TOKEN": "'$token'"\
      }\
    },')
                
                echo "$new_content" > "$config_file"
            else
                # No mcpServers at all, wrap existing content and add
                cat > "$config_file" << EOF
{
  "mcpServers": {
${github_config}
  }
}
EOF
            fi
        fi
        
        echo "✅ Config updated with GitHub MCP server"
    fi
}

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Claude Desktop config not found."
    read -p "Create configuration? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
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
        merge_github_config "$GITHUB_TOKEN" "$CONFIG_FILE"
        echo ""
        echo "⚠️  Please restart Claude Desktop for the changes to take effect."
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
    echo "2. Run this installer again with your token"
    echo ""
    echo "Installation completed, but configuration was skipped."
fi

echo ""
echo "Done!"