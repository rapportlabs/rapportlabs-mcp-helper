#!/bin/bash

# GitHub MCP Server Installation Script for macOS (Korean)
# Double-click this file to install

clear
echo "=========================================="
echo "  GitHub MCP Server 설치 프로그램 (macOS)"
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
    echo "📱 감지됨: Intel Mac"
elif [ "$ARCH" = "arm64" ]; then
    ARCH_SUFFIX="arm64"
    echo "📱 감지됨: Apple Silicon Mac (M1/M2/M3)"
else
    echo "❌ 지원되지 않는 아키텍처: $ARCH"
    echo "아무 키나 눌러 종료하세요..."
    read -n 1
    exit 1
fi

# Check if already installed
if command -v github-mcp-server &> /dev/null; then
    CURRENT_VERSION=$(github-mcp-server --version 2>&1 | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
    echo ""
    echo "✅ GitHub MCP Server가 이미 설치되어 있습니다"
    echo "   현재 버전: $CURRENT_VERSION"
    echo ""
    
    # Get latest version
    echo "⏳ 업데이트 확인 중..."
    LATEST_VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
        grep '"tag_name":' | \
        cut -d '"' -f 4)
    
    if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
        echo "✅ 이미 최신 버전을 사용하고 있습니다 ($LATEST_VERSION)"
        echo ""
        echo "Enter를 눌러 종료하세요..."
        read
        osascript -e 'tell application "Terminal" to close first window' &
        exit 0
    else
        echo "🆕 업데이트 사용 가능: $LATEST_VERSION"
        echo ""
        while true; do
            echo "업그레이드 하시겠습니까? (y/n): "
            read -n 1 UPGRADE_CHOICE
            echo ""
            
            if [[ "$UPGRADE_CHOICE" =~ ^[YyNn]$ ]]; then
                break
            else
                echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
                echo ""
            fi
        done
        
        if [[ ! "$UPGRADE_CHOICE" =~ ^[Yy]$ ]]; then
            echo "설치가 취소되었습니다."
            echo "Enter를 눌러 종료하세요..."
            read
            osascript -e 'tell application "Terminal" to close first window' &
            exit 0
        fi
        echo "$LATEST_VERSION로 업그레이드를 진행합니다..."
    fi
else
    echo ""
    echo "이 설치 프로그램은 다음과 같은 작업을 수행합니다:"
    echo "1. 최신 GitHub MCP Server를 다운로드합니다"
    echo "2. $INSTALL_DIR에 설치합니다"
    echo "3. 비밀번호를 요청할 수 있습니다"
    echo ""
    echo "계속하려면 Enter를 누르고, 취소하려면 Ctrl+C를 누르세요..."
    read
fi

# Get the download URL
echo ""
echo "⏳ 다운로드 정보를 가져오는 중..."
DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep "browser_download_url.*Darwin_${ARCH_SUFFIX}.tar.gz" | \
    cut -d '"' -f 4)

VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
    grep '"tag_name":' | \
    cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ 다운로드 URL을 찾을 수 없습니다"
    echo "아무 키나 눌러 종료하세요..."
    read -n 1
    exit 1
fi

if [ -z "$VERSION" ]; then
    VERSION=$LATEST_VERSION
fi
echo "✅ 설치할 버전: $VERSION"
echo ""
echo "⏳ 다운로드 중..."

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download with progress bar
curl -L --progress-bar -o "$TEMP_DIR/github-mcp-server.tar.gz" "$DOWNLOAD_URL"

echo ""
echo "⏳ 압축 해제 중..."
tar -xzf "$TEMP_DIR/github-mcp-server.tar.gz" -C "$TEMP_DIR"

# Find the binary
BINARY=$(find "$TEMP_DIR" -name "github-mcp-server" -type f | head -1)

if [ -z "$BINARY" ]; then
    echo "❌ 압축 파일에서 바이너리를 찾을 수 없습니다"
    echo "아무 키나 눌러 종료하세요..."
    read -n 1
    exit 1
fi

# Install
echo ""
echo "⏳ $INSTALL_DIR에 설치 중..."
echo "   (비밀번호를 요청할 수 있습니다)"
echo ""

# Create install directory if it doesn't exist
sudo mkdir -p "$INSTALL_DIR"

# Install the binary
sudo mv "$BINARY" "$INSTALL_DIR/github-mcp-server"
sudo chmod +x "$INSTALL_DIR/github-mcp-server"

echo ""
echo "=========================================="
echo "✅ 설치 완료!"
echo "=========================================="
echo ""
echo "GitHub MCP Server $VERSION이 성공적으로 설치되었습니다!"
echo ""

# Verify installation
if command -v github-mcp-server &> /dev/null; then
    echo "설치된 버전:"
    github-mcp-server --version
else
    echo "⚠️  참고: 명령어를 사용하려면 터미널을 재시작해야 할 수 있습니다."
fi

echo ""
echo "=========================================="
echo "  Claude Desktop 설정"
echo "=========================================="
echo ""

# Check for Claude Desktop config
CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"

if [ -f "$CONFIG_FILE" ]; then
    echo "Claude Desktop 설정 파일을 찾았습니다."
    echo ""
    
    # Check if GitHub MCP is already configured
    if grep -q '"github"' "$CONFIG_FILE" 2>/dev/null; then
        echo "✅ GitHub MCP Server가 이미 Claude Desktop에 설정되어 있습니다."
        echo ""
        echo "현재 설정:"
        echo "---"
        python3 -c "
import json
import sys
try:
    with open('$CONFIG_FILE', 'r') as f:
        config = json.load(f)
    if 'mcpServers' in config and 'github' in config['mcpServers']:
        github_config = config['mcpServers']['github']
        print(f\"명령어: {github_config.get('command', '설정되지 않음')}\")
        if 'env' in github_config and 'GITHUB_PERSONAL_ACCESS_TOKEN' in github_config['env']:
            pat = github_config['env']['GITHUB_PERSONAL_ACCESS_TOKEN']
            if pat.startswith('\$'):
                print(f\"GitHub PAT: 환경 변수 {pat} 사용\")
            else:
                print(f\"GitHub PAT: 설정됨 (숨김)\")
        else:
            print('GitHub PAT: 설정되지 않음')
except Exception as e:
    print(f'설정 읽기 오류: {e}')
" 2>/dev/null || echo "설정을 파싱할 수 없습니다"
        echo "---"
        echo ""
        while true; do
            echo "다시 설정하시겠습니까? (y/n): "
            read -n 1 RECONFIGURE
            echo ""
            
            if [[ "$RECONFIGURE" =~ ^[YyNn]$ ]]; then
                break
            else
                echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
                echo ""
            fi
        done
        
        if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
            echo ""
            echo "설정을 건너뛰었습니다."
        else
            # Reconfigure
            echo ""
            while true; do
                echo "GitHub Personal Access Token (PAT)을 가지고 있습니까? (y/n): "
                read -n 1 HAS_PAT
                echo ""
                
                if [[ "$HAS_PAT" =~ ^[YyNn]$ ]]; then
                    break
                else
                    echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
                    echo ""
                fi
            done
            
            if [[ "$HAS_PAT" =~ ^[Yy]$ ]]; then
                echo ""
                echo "GitHub Personal Access Token을 입력하세요:"
                read -s GITHUB_TOKEN
                echo ""
                PAT_VALUE="\"$GITHUB_TOKEN\""
            else
                echo ""
                echo "❌ GitHub MCP Server가 작동하려면 GitHub Personal Access Token이 필요합니다."
                echo ""
                echo "PAT 생성 가이드를 참고하세요:"
                echo "https://www.notion.so/rapportlabs/MCP-Claude-1de466b620998067a649e145c6bb0d15?source=copy_link#1df466b6209981afa0ecfc86d8d3a586"
                echo ""
                echo "PAT를 받은 후 이 설치 프로그램을 다시 실행하여 설정할 수 있습니다."
                echo ""
                echo "Enter를 눌러 종료하세요..."
                read
                osascript -e 'tell application "Terminal" to close first window' &
                exit 0
            fi
            
            # Update the configuration
            echo "⏳ Claude Desktop 설정을 업데이트하는 중..."
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
    
    print('✅ 설정이 성공적으로 업데이트되었습니다!')
except Exception as e:
    print(f'❌ 설정 업데이트 오류: {e}')
    sys.exit(1)
"
            echo ""
        fi
    else
        # GitHub MCP not configured, ask to add it
        echo "GitHub MCP Server가 Claude Desktop에 설정되어 있지 않습니다."
        echo ""
        while true; do
            echo "지금 설정하시겠습니까? (y/n): "
            read -n 1 CONFIGURE
            echo ""
            
            if [[ "$CONFIGURE" =~ ^[YyNn]$ ]]; then
                break
            else
                echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
                echo ""
            fi
        done
        
        if [[ "$CONFIGURE" =~ ^[Yy]$ ]]; then
            echo ""
            while true; do
                echo "GitHub Personal Access Token (PAT)을 가지고 있습니까? (y/n): "
                read -n 1 HAS_PAT
                echo ""
                
                if [[ "$HAS_PAT" =~ ^[YyNn]$ ]]; then
                    break
                else
                    echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
                    echo ""
                fi
            done
            
            if [[ "$HAS_PAT" =~ ^[Yy]$ ]]; then
                echo ""
                echo "GitHub Personal Access Token을 입력하세요:"
                read -s GITHUB_TOKEN
                echo ""
                PAT_VALUE="\"$GITHUB_TOKEN\""
            else
                echo ""
                echo "❌ GitHub MCP Server가 작동하려면 GitHub Personal Access Token이 필요합니다."
                echo ""
                echo "PAT 생성 가이드를 참고하세요:"
                echo "https://www.notion.so/rapportlabs/MCP-Claude-1de466b620998067a649e145c6bb0d15?source=copy_link#1df466b6209981afa0ecfc86d8d3a586"
                echo ""
                echo "PAT를 받은 후 이 설치 프로그램을 다시 실행하여 설정할 수 있습니다."
                echo ""
                echo "Enter를 눌러 종료하세요..."
                read
                osascript -e 'tell application "Terminal" to close first window' &
                exit 0
            fi
            
            # Add the configuration
            echo "⏳ Claude Desktop 설정을 업데이트하는 중..."
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
    
    print('✅ 설정이 성공적으로 추가되었습니다!')
except Exception as e:
    print(f'❌ 설정 업데이트 오류: {e}')
    sys.exit(1)
"
            echo ""
            echo "⚠️  변경 사항을 적용하려면 Claude Desktop을 재시작하세요."
            echo ""
        else
            echo ""
            echo "설정을 건너뛰었습니다."
            echo "나중에 다음 파일을 편집하여 수동으로 설정할 수 있습니다:"
            echo "$CONFIG_FILE"
            echo ""
        fi
    fi
else
    echo "⚠️  Claude Desktop 설정 파일을 찾을 수 없습니다."
    echo "   예상 위치: $CONFIG_FILE"
    echo ""
    while true; do
        echo "그래도 설정 파일을 생성하시겠습니까? (y/n): "
        read -n 1 CREATE_CONFIG
        echo ""
        
        if [[ "$CREATE_CONFIG" =~ ^[YyNn]$ ]]; then
            break
        else
            echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
            echo ""
        fi
    done
    
    if [[ "$CREATE_CONFIG" =~ ^[Yy]$ ]]; then
        echo ""
        while true; do
            echo "GitHub Personal Access Token (PAT)을 가지고 있습니까? (y/n): "
            read -n 1 HAS_PAT
            echo ""
            
            if [[ "$HAS_PAT" =~ ^[YyNn]$ ]]; then
                break
            else
                echo "잘못된 선택입니다. 'y' 또는 'n'을 입력하세요."
                echo ""
            fi
        done
        
        if [[ "$HAS_PAT" =~ ^[Yy]$ ]]; then
            echo ""
            echo "GitHub Personal Access Token을 입력하세요:"
            read -s GITHUB_TOKEN
            echo ""
            PAT_VALUE="\"$GITHUB_TOKEN\""
        else
            echo ""
            echo "❌ GitHub MCP Server가 작동하려면 GitHub Personal Access Token이 필요합니다."
            echo ""
            echo "PAT 생성 가이드를 참고하세요:"
            echo "https://www.notion.so/rapportlabs/MCP-Claude-1de466b620998067a649e145c6bb0d15?source=copy_link#1df466b6209981afa0ecfc86d8d3a586"
            echo ""
            echo "PAT를 받은 후 이 설치 프로그램을 다시 실행하여 설정할 수 있습니다."
            echo ""
            echo "Enter를 눌러 종료하세요..."
            read
            osascript -e 'tell application "Terminal" to close first window' &
            exit 0
        fi
        
        # Create the directory and configuration
        echo "⏳ Claude Desktop 설정을 생성하는 중..."
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
    
    print('✅ 설정이 성공적으로 생성되었습니다!')
except Exception as e:
    print(f'❌ 설정 생성 오류: {e}')
    sys.exit(1)
"
        echo ""
        echo "⚠️  변경 사항을 적용하려면 Claude Desktop을 재시작하세요."
        echo ""
    else
        echo ""
        echo "설정을 건너뛰었습니다."
        echo "나중에 다음 파일을 생성하여 수동으로 설정할 수 있습니다:"
        echo "$CONFIG_FILE"
        echo ""
    fi
fi

echo ""
echo "이제 터미널에서 'github-mcp-server'를 사용할 수 있습니다."
echo ""
echo "Enter를 눌러 창을 닫으세요..."
read

# Close the Terminal window
osascript -e 'tell application "Terminal" to close first window' &