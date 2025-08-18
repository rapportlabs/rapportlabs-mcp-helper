#!/usr/bin/env bash
set -euo pipefail

# Claude Desktop 대상 사용자만 진행
CLAUDE_APP1="/Applications/Claude.app"
CLAUDE_APP2="$HOME/Applications/Claude.app"
if [ ! -d "$CLAUDE_APP1" ] && [ ! -d "$CLAUDE_APP2" ]; then
  echo "[INFO] Claude Desktop 미설치로 판단되어 작업을 생략합니다."
  exit 0
fi

echo "[INFO] Claude Desktop 설치 감지됨. 환경 구성 시작"

# 1) Node가 없으면 nvm 설치 후 LTS Node 설치
if ! command -v node >/dev/null 2>&1; then
  echo "[INFO] node 미설치. nvm 설치 및 LTS Node 설치를 진행합니다."

  # 네트워크 연결 확인
  if ! curl -fsSL --connect-timeout 5 https://httpbin.org/status/200 >/dev/null 2>&1; then
    echo "[ERROR] 인터넷 연결을 확인할 수 없습니다. 네트워크 연결 상태를 점검해주세요." >&2
    echo "[SOLUTION] 1) Wi-Fi 연결 확인 2) 방화벽 설정 확인 3) VPN 비활성화 후 재시도" >&2
    exit 1
  fi

  # nvm 설치 (curl 공식 스크립트 사용)
  if [ ! -d "$HOME/.nvm" ]; then
    echo "[INFO] nvm 설치 스크립트 실행 (네트워크 연결 확인됨)"
    if ! curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash; then
      echo "[ERROR] nvm 설치 실패. 수동 설치를 진행하세요:" >&2
      echo "[SOLUTION] 1) https://nodejs.org 에서 Node.js 직접 설치" >&2
      echo "[SOLUTION] 2) 또는 Homebrew: brew install node" >&2
      exit 1
    fi
  fi

  # 현재 셸 세션에 nvm 로드
  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1090
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

  # zsh 사용자의 영구 설정 추가 (필요 시)
  ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
  if [ -n "${ZSH_VERSION:-}" ] || [ -f "$ZSHRC" ]; then
    if ! grep -q 'export NVM_DIR="$HOME/.nvm"' "$ZSHRC" 2>/dev/null; then
      {
        echo ''
        echo 'export NVM_DIR="$HOME/.nvm"'
        echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
      } >> "$ZSHRC"
      echo "[INFO] $ZSHRC 에 nvm 초기화 스니펫 추가"
    fi
  fi

  # bash 사용자의 영구 설정 추가 (백업 경로)
  BASHRC="$HOME/.bashrc"
  if [ -f "$BASHRC" ]; then
    if ! grep -q 'export NVM_DIR="$HOME/.nvm"' "$BASHRC" 2>/dev/null; then
      {
        echo ''
        echo 'export NVM_DIR="$HOME/.nvm"'
        echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'
      } >> "$BASHRC"
      echo "[INFO] $BASHRC 에 nvm 초기화 스니펫 추가"
    fi
  fi

  echo "[INFO] LTS Node 설치 중..."
  nvm install --lts
  nvm alias default 'lts/*'
  nvm use default
else
  echo "[INFO] node 설치됨 (버전: $(node -v))"
fi

# npm 사용 가능 보장
if ! command -v npm >/dev/null 2>&1; then
  echo "[ERROR] npm을 찾을 수 없습니다. nvm/Node 설치가 실패했을 수 있습니다." >&2
  exit 1
fi

# 2) mcp-remote 설치 확인/설치
if command -v mcp-remote >/dev/null 2>&1; then
  echo "[INFO] mcp-remote 설치됨 (경로: $(command -v mcp-remote))"
else
  echo "[INFO] mcp-remote 미설치. 전역 설치 진행 (npm i -g mcp-remote)"
  
  # npm 글로벌 설치 권한 확인
  if ! npm config get prefix >/dev/null 2>&1; then
    echo "[ERROR] npm 설정에 접근할 수 없습니다." >&2
    exit 1
  fi
  
  # mcp-remote 설치 시도
  if ! npm install -g mcp-remote 2>/dev/null; then
    echo "[WARNING] 글로벌 설치 실패. 권한 문제일 수 있습니다."
    echo "[INFO] 대안: npx를 통한 실행을 사용합니다 (설치 불필요)"
    
    # npx로 테스트
    if ! npx --yes mcp-remote --help >/dev/null 2>&1; then
      echo "[ERROR] npx로도 mcp-remote 실행 실패" >&2
      echo "[SOLUTION] 수동으로 설치해주세요: npm install -g mcp-remote" >&2
      echo "[SOLUTION] 또는 관리자 권한으로 재시도: sudo npm install -g mcp-remote" >&2
    else
      echo "[SUCCESS] npx를 통한 mcp-remote 실행 가능 확인됨"
    fi
  else
    echo "[SUCCESS] mcp-remote 글로벌 설치 완료"
  fi
fi

# 3) Claude Desktop 설정 파일에 mcpServers 구성 추가 (신/구 경로 모두 지원)
NEW_CONFIG_DIR="$HOME/Library/Application Support/Claude"
NEW_CONFIG_FILE="$NEW_CONFIG_DIR/claude_desktop_config.json"
OLD_CONFIG_DIR="$HOME/.claude"
OLD_CONFIG_FILE="$OLD_CONFIG_DIR/config.json"

mkdir -p "$NEW_CONFIG_DIR" "$OLD_CONFIG_DIR"

echo "[INFO] Claude 설정 업데이트: $NEW_CONFIG_FILE 및 $OLD_CONFIG_FILE"
node <<'NODE'
const fs = require('fs');
const path = require('path');

const home = process.env.HOME;
const targets = [
  path.join(home, 'Library', 'Application Support', 'Claude', 'claude_desktop_config.json'),
  path.join(home, '.claude', 'config.json'),
];

for (const configFile of targets) {
  try {
    // 디렉토리 보장
    fs.mkdirSync(path.dirname(configFile), { recursive: true });

    let data = {};
    try {
      const raw = fs.readFileSync(configFile, 'utf8');
      data = JSON.parse(raw);
    } catch (e) {
      data = {};
    }

    if (!data || typeof data !== 'object') data = {};
    if (!data.mcpServers || typeof data.mcpServers !== 'object') data.mcpServers = {};

    data.mcpServers['rpls'] = {
      command: 'npx',
      args: ['mcp-remote', 'https://agentgateway.damoa.rapportlabs.dance/mcp'],
    };

    fs.writeFileSync(configFile, JSON.stringify(data, null, 2) + '\n');
    console.log(`[INFO] Updated: ${configFile}`);
  } catch (err) {
    console.error(`[WARN] Failed to update: ${configFile} -> ${err?.message || err}`);
  }
}
NODE

echo "[SUCCESS] 설정이 완료되었습니다. Claude Desktop을 재시작하면 반영됩니다."


