#!/bin/bash

set -euo pipefail

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_success() { echo -e "${GREEN}$1${NC}"; }
print_error() { echo -e "${RED}$1${NC}"; }
print_warning() { echo -e "${YELLOW}$1${NC}"; }
print_info() { echo -e "${BLUE}$1${NC}"; }

echo "========================================"
echo "Node.js 24.4.1 and mcp-remote 0.1.18 Setup Script"
echo "(No git/Xcode dependencies - Using nvm for Node.js management)"
echo "========================================"
echo

OS="$(uname -s)"
if [[ "$OS" != "Darwin" ]]; then
  print_error "[ERROR] This script is designed for macOS only"
  exit 1
fi

print_info "[PLATFORM CHECK] Running on macOS - OK"
echo

if ! command -v curl >/dev/null 2>&1; then
  print_error "[ERROR] Required tool 'curl' not found!"
  echo "curl should be available on macOS by default."
  exit 1
fi
print_info "[SYSTEM CHECK] curl is available - OK"
echo

ensure_path_entry() {
  local profile_path="$1"
  local path_dir="$2"

  if [[ -z "${profile_path:-}" || -z "${path_dir:-}" ]]; then
    return
  fi

  if [[ ! -f "$profile_path" ]]; then
    return
  fi

  if grep -Fq "$path_dir" "$profile_path"; then
    return
  fi

  {
    printf '\n'
    printf '# Added by Node MCP setup: ensure custom CLI directory on PATH\n'
    printf 'if [[ ":$PATH:" != *":%s:"* ]]; then\n' "$path_dir"
    printf '  export PATH="%s:$PATH"\n' "$path_dir"
    printf 'fi\n'
  } >>"$profile_path"
  echo "Added $path_dir to PATH in $profile_path"
}

add_nvm_to_profile() {
  local profile_path="$1"
  local ensure_file="${2:-0}"
  local node_version="${3:-$NODE_VERSION}"

  if [[ "$ensure_file" -eq 1 && ! -f "$profile_path" ]]; then
    touch "$profile_path"
    echo "Created $profile_path"
  fi

  if [[ ! -f "$profile_path" ]]; then
    return
  fi

  if ! grep -Fq 'export NVM_DIR="$HOME/.nvm"' "$profile_path"; then
    {
      printf '\n'
      printf 'export NVM_DIR="$HOME/.nvm"\n'
      printf '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # Loads nvm\n'
      printf '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # Loads nvm bash_completion\n'
      printf 'if command -v nvm >/dev/null 2>&1; then\n'
      printf '  nvm use default >/dev/null 2>&1 || nvm use %s >/dev/null 2>&1 || true\n' "$node_version"
      printf 'fi\n'
    } >>"$profile_path"
    echo "Added nvm configuration to $profile_path"
  fi
}

write_claude_desktop_config() {
  local target="$1"
  {
    printf '{\n'
    printf '  "mcpServers": {\n'
    local total="${#MCP_SERVERS[@]}"
    for idx in "${!MCP_SERVERS[@]}"; do
      local entry="${MCP_SERVERS[$idx]}"
      local name="${entry%%|*}"
      local url="${entry#*|}"
      printf '    "%s": {\n' "$name"
      printf '      "command": "npx",\n'
      printf '      "args": [\n'
      printf '        "mcp-remote",\n'
      printf '        "%s"\n' "$url"
      printf '      ]\n'
      printf '    }'
      if (( idx < total - 1 )); then
        printf ','
      fi
      printf '\n'
    done
    printf '  }\n'
    printf '}\n'
  } >"$target"
}

NVM_VERSION="v0.39.0"
NODE_VERSION="24.4.1"
MCP_REMOTE_VERSION="0.1.18"

MCP_SERVERS=(
  "rpwiki|https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp"
  "notion|https://notion-mcp.damoa.rapportlabs.dance/mcp"
  "bigquery|https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
  "slack|https://slack-mcp.damoa.rapportlabs.dance/sse"
  "queenit|https://mcp.rapportlabs.kr/mcp"
)

LOCAL_BIN_DIR="$HOME/.local/bin"
PATH_PROFILE_FILES=(
  "$HOME/.zshrc"
  "$HOME/.zprofile"
  "$HOME/.profile"
  "$HOME/.bash_profile"
  "$HOME/.bashrc"
)

echo "Versions to install:"
echo "  nvm: $NVM_VERSION"
echo "  Node.js: $NODE_VERSION"
echo "  mcp-remote: $MCP_REMOTE_VERSION"
echo

SKIP_NVM_INSTALL=0
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  print_info "[NVM CHECK] nvm is already installed"
  export NVM_DIR="$HOME/.nvm"
  # shellcheck source=/dev/null
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  CURRENT_NVM_VERSION="$(nvm --version 2>/dev/null || echo "unknown")"
  echo "Current nvm version: $CURRENT_NVM_VERSION"
  SKIP_NVM_INSTALL=1
else
  print_info "[NVM CHECK] nvm is not installed - will install $NVM_VERSION"
fi

echo
echo "Checking for existing Node.js installation..."
SKIP_NODE_INSTALL=0

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" >/dev/null 2>&1

if command -v node >/dev/null 2>&1; then
  CURRENT_NODE_VERSION="$(node --version 2>/dev/null || echo "unknown")"
  echo "Found existing Node.js: $CURRENT_NODE_VERSION"
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
  read -rp "Do you want to continue with the installation? (y/n): " -n 1 REPLY
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
if [ "$SKIP_NVM_INSTALL" -eq 0 ]; then
  echo "Installing nvm $NVM_VERSION..."
  echo "Downloading nvm as tarball (no git required)..."
  mkdir -p "$HOME/.nvm"
  TARBALL_URL="https://github.com/nvm-sh/nvm/archive/$NVM_VERSION.tar.gz"
  TEMP_DIR="$(mktemp -d)"
  echo "Downloading from $TARBALL_URL..."
  if ! curl -L "$TARBALL_URL" | tar -xz -C "$TEMP_DIR"; then
    print_error "[ERROR] Failed to download nvm tarball!"
    echo "Please check your internet connection."
    rm -rf "$TEMP_DIR"
    exit 1
  fi
  mv "$TEMP_DIR/nvm-${NVM_VERSION#v}"/* "$HOME/.nvm/"
  rm -rf "$TEMP_DIR"
  chmod +x "$HOME/.nvm/nvm.sh"

  case "${SHELL:-}" in
    *zsh*) primary_profile="$HOME/.zshrc" ;;
    *bash*) primary_profile="$HOME/.bash_profile" ;;
    *) primary_profile="$HOME/.zshrc" ;;
  esac

  PROFILE_CANDIDATES=(
    "$primary_profile"
    "$HOME/.zprofile"
    "$HOME/.profile"
    "$HOME/.bash_profile"
    "$HOME/.bashrc"
    "$HOME/.zshrc"
  )

  processed_profiles=()
  for candidate in "${PROFILE_CANDIDATES[@]}"; do
    if [[ -z "$candidate" ]]; then
      continue
    fi
    already_processed=0
    for processed in "${processed_profiles[@]}"; do
      if [[ "$processed" == "$candidate" ]]; then
        already_processed=1
        break
      fi
    done
    if [[ "$already_processed" -eq 1 ]]; then
      continue
    fi
    processed_profiles+=("$candidate")
    if [[ "$candidate" == "$primary_profile" ]]; then
      ensure_flag=0
      if [[ "$candidate" == "$primary_profile" ]]; then
        ensure_flag=1
      elif [[ "$candidate" == "$HOME/.zprofile" ]]; then
        ensure_flag=1
      elif [[ "$candidate" == "$HOME/.bash_profile" ]]; then
        ensure_flag=1
      fi
      add_nvm_to_profile "$candidate" "$ensure_flag" "$NODE_VERSION"
    else
      add_nvm_to_profile "$candidate" 0 "$NODE_VERSION"
    fi
  done
  print_success "[SUCCESS] nvm $NVM_VERSION installed successfully (without git)!"
  echo
fi

echo "Loading nvm..."
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

if ! command -v nvm >/dev/null 2>&1; then
  print_error "[ERROR] Failed to load nvm!"
  echo "Please restart your terminal and run this script again."
  exit 1
fi

print_success "[SUCCESS] nvm loaded successfully!"
echo "nvm version: $(nvm --version)"
echo

if [ "$SKIP_NODE_INSTALL" -eq 1 ]; then
  echo "Skipping Node.js installation - already at target version."
else
  echo "Installing Node.js v$NODE_VERSION using nvm..."
  echo "This may take several minutes..."
  echo
  if ! nvm install "$NODE_VERSION"; then
    print_error "[ERROR] Failed to install Node.js v$NODE_VERSION!"
    exit 1
  fi
  nvm use "$NODE_VERSION"
  nvm alias default "$NODE_VERSION"
  print_success "[SUCCESS] Node.js v$NODE_VERSION installed and set as default!"
fi
echo

echo "Verifying Node.js installation..."
export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use "$NODE_VERSION" >/dev/null 2>&1

NODE_PREFIX="$NVM_DIR/versions/node/v$NODE_VERSION"
NODE_BIN="$NODE_PREFIX/bin"
NODE_EXEC="$NODE_BIN/node"

if [ ! -x "$NODE_EXEC" ]; then
  print_error "[ERROR] Node.js binaries not found at $NODE_EXEC"
  exit 1
fi

CURRENT_VERSION="$("$NODE_EXEC" --version)"
if [[ "$CURRENT_VERSION" != "v$NODE_VERSION" ]]; then
  print_error "[ERROR] Node.js version mismatch!"
  echo "Expected: v$NODE_VERSION"
  echo "Current: $CURRENT_VERSION"
  exit 1
fi

echo
print_success "[SUCCESS] Node.js installed successfully!"
echo
echo "Node version: $("$NODE_EXEC" --version)"
echo "NPM version: $("$NODE_BIN/npm" --version)"
echo "NPX version: $("$NODE_BIN/npx" --version)"
echo

echo "========================================"
echo "Installing mcp-remote@$MCP_REMOTE_VERSION"
echo "========================================"
echo

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use "$NODE_VERSION" >/dev/null 2>&1

echo "Using Node.js $("$NODE_EXEC" --version) and npm $("$NODE_BIN/npm" --version)"
echo

if ! "$NODE_BIN/npm" install -g "mcp-remote@$MCP_REMOTE_VERSION"; then
  print_error "[ERROR] Failed to install mcp-remote@$MCP_REMOTE_VERSION"
  exit 1
fi

echo
echo "Verifying mcp-remote installation..."
MCP_VERSION="$("$NODE_BIN/npm" list -g mcp-remote 2>/dev/null | grep mcp-remote@ | sed 's/.*mcp-remote@//' | sed 's/ .*//' || echo "unknown")"
echo "mcp-remote version: $MCP_VERSION"
if [[ "$MCP_VERSION" != "$MCP_REMOTE_VERSION" ]]; then
  print_warning "[WARNING] mcp-remote version might not match exactly. Expected: $MCP_REMOTE_VERSION, Got: $MCP_VERSION"
fi

print_success "[SUCCESS] mcp-remote installed!"
echo

NPX_CMD="$NODE_BIN/npx"
NPM_CMD="$NODE_BIN/npm"

echo "========================================"
echo "Configuring Claude Code MCP servers"
echo "========================================"
echo

CLAUDE_BIN="$NODE_BIN/claude"
CLAUDE_CMD=()

if [ ! -x "$NPM_CMD" ]; then
  print_error "[ERROR] npm not found; cannot configure Claude Code CLI."
  exit 1
fi

if ! command -v claude >/dev/null 2>&1 && [ ! -x "$CLAUDE_BIN" ]; then
  echo "Installing Claude Code CLI globally..."
  if "$NPM_CMD" install -g @anthropic-ai/claude-code >/dev/null 2>&1; then
    print_success "[SUCCESS] Claude Code CLI installed globally."
  else
    print_error "[ERROR] Failed to install Claude Code CLI globally."
    echo "You can retry manually with:"
    echo "  $NPM_CMD install -g @anthropic-ai/claude-code"
    exit 1
  fi
else
  print_info "Claude Code CLI already available."
fi

if command -v claude >/dev/null 2>&1; then
  CLAUDE_CMD=("claude")
elif [ -x "$CLAUDE_BIN" ]; then
  CLAUDE_CMD=("$CLAUDE_BIN")
else
  if [ ! -x "$NPX_CMD" ]; then
    print_error "[ERROR] npx command not available; cannot configure Claude Code CLI."
    exit 1
  fi
  CLAUDE_CMD=("$NPX_CMD" "-y" "@anthropic-ai/claude-code")
fi

existing="$("${CLAUDE_CMD[@]}" mcp list 2>/dev/null || true)"
for entry in "${MCP_SERVERS[@]}"; do
  name="${entry%%|*}"
  url="${entry#*|}"
  if [[ "$existing" == *"$url"* ]]; then
    echo "Claude Code already configured for $name ($url) - skipping"
    continue
  fi
  echo "Adding Claude Code MCP server: $name ($url)"
  if "${CLAUDE_CMD[@]}" mcp add "$name" --scope user -- "$NPX_CMD" "-y" "mcp-remote" "$url" >/dev/null 2>&1; then
    print_success "[SUCCESS] Added $name to Claude Code (user scope)"
    existing+=" $url"
  else
    print_error "[ERROR] Failed to add $name to Claude Code (user scope)"
    exit 1
  fi
done
echo

echo "Ensuring Claude Code CLI is available on PATH..."
CLAUDE_REAL_PATH="$(command -v claude 2>/dev/null || true)"
if [ -z "$CLAUDE_REAL_PATH" ] && [ -n "${CLAUDE_BIN:-}" ] && [ -x "$CLAUDE_BIN" ]; then
  CLAUDE_REAL_PATH="$CLAUDE_BIN"
fi

if [ -n "$CLAUDE_REAL_PATH" ]; then
  mkdir -p "$LOCAL_BIN_DIR"
  CLAUDE_WRAPPER="$LOCAL_BIN_DIR/claude"
  cat >"$CLAUDE_WRAPPER" <<EOF
#!/bin/bash
export NVM_DIR="$HOME/.nvm"
if [ -s "\$NVM_DIR/nvm.sh" ]; then
  . "\$NVM_DIR/nvm.sh"
fi
nvm use $NODE_VERSION >/dev/null 2>&1 || true
exec "$CLAUDE_REAL_PATH" "\$@"
EOF
  chmod +x "$CLAUDE_WRAPPER"
  print_success "[SUCCESS] Created Claude Code wrapper at $CLAUDE_WRAPPER"

  for profile_file in "${PATH_PROFILE_FILES[@]}"; do
    ensure_path_entry "$profile_file" "$LOCAL_BIN_DIR"
  done
else
  print_warning "[WARNING] Unable to determine Claude Code CLI path for wrapper creation."
fi
echo

echo "========================================"
echo "Configuring Claude Desktop MCP servers"
echo "========================================"
echo

CONFIG_DIR="$HOME/Library/Application Support/Claude"
CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

if [ ! -d "$CONFIG_DIR" ]; then
  echo "Creating configuration directory: $CONFIG_DIR"
  mkdir -p "$CONFIG_DIR"
  if [ $? -ne 0 ]; then
    print_error "[ERROR] Failed to create directory $CONFIG_DIR"
    exit 1
  fi
fi

if [ -f "$CONFIG_FILE" ]; then
  echo "Existing configuration found at $CONFIG_FILE"
  echo "Creating backup..."
  cp "$CONFIG_FILE" "$CONFIG_FILE.backup.$(date +%Y%m%d_%H%M%S)"
  print_info "Backup created successfully"
fi

if write_claude_desktop_config "$CONFIG_FILE"; then
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

export NVM_DIR="$HOME/.nvm"
# shellcheck source=/dev/null
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm use "$NODE_VERSION" >/dev/null 2>&1

echo "Installed Software:"
echo "-------------------"
echo "nvm version: $(nvm --version)"
echo "Node.js version: $("$NODE_EXEC" --version)"
echo "NPM version: $("$NODE_BIN/npm" --version)"
echo "NPX version: $("$NODE_BIN/npx" --version)"
echo "mcp-remote version: $MCP_VERSION"
CLAUDE_STATUS="not available"
if command -v claude >/dev/null 2>&1; then
  CLAUDE_STATUS="$(command -v claude)"
elif [ -n "${CLAUDE_BIN:-}" ] && [ -x "$CLAUDE_BIN" ]; then
  CLAUDE_STATUS="$CLAUDE_BIN"
else
  CLAUDE_STATUS="npx fallback"
fi
echo "Claude Code CLI: $CLAUDE_STATUS"
echo
echo "MCP Configuration:"
echo "------------------"
echo "Config file: $CONFIG_FILE"
echo "Configured servers:"
for entry in "${MCP_SERVERS[@]}"; do
  server_name="${entry%%|*}"
  server_url="${entry#*|}"
  echo "  - $server_name: $server_url"
done
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
echo

print_warning "To use Node.js in this terminal, run:"
echo "  export NVM_DIR=\"$HOME/.nvm\""
echo "  . \"\$NVM_DIR/nvm.sh\""
echo "  nvm use $NODE_VERSION"
echo
print_info "Future terminals will load Node.js automatically via your shell profile."
