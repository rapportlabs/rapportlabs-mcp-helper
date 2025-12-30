# === MCP 전역 설정 (Claude Desktop / Cursor / Claude Code / Codex) ===
RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BLUE=$'\033[0;34m'; NC=$'\033[0m'
ok(){ echo "${GREEN}$1${NC}"; }; warn(){ echo "${YELLOW}$1${NC}"; }; err(){ echo "${RED}$1${NC}"; }; info(){ echo "${BLUE}$1${NC}"; };

MCP_REMOTE_VERSION="0.1.18"

SERVERS=(
  "rpwiki|https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp"
  "bigquery|https://bigquery-mcp.damoa.rapportlabs.dance/mcp"
  "notion|https://mcp.notion.com/mcp"
  "slack|https://slack-mcp.damoa.rapportlabs.dance/sse"
)

HAS_NODE=0; command -v node >/dev/null 2>&1 && HAS_NODE=1
HAS_NPM=0;  command -v npm  >/dev/null 2>&1 && HAS_NPM=1
HAS_PY=0;   command -v python3 >/dev/null 2>&1 && HAS_PY=1

echo "========================================"
echo "MCP 설정 (no file save version)"
echo "Node: $([ $HAS_NODE -eq 1 ] && echo $(node -v) || echo 미설치)"
echo "npm : $([ $HAS_NPM -eq 1 ] && echo $(npm -v) || echo 미설치)"
echo "========================================"

merge_json() {
  local TARGET="$1" STRATEGY="$2"
  mkdir -p "$(dirname "$TARGET")"
  [[ -f "$TARGET" ]] && cp "$TARGET" "$TARGET.backup.$(date +%Y%m%d_%H%M%S)"

  local JSON=$(printf '['; for s in "${SERVERS[@]}"; do name="${s%%|*}"; url="${s#*|}"; printf '{"name":"%s","url":"%s"},' "$name" "$url"; done | sed 's/,$//'; printf ']')

  if [[ $HAS_NODE -eq 1 ]]; then
    TARGET="$TARGET" STRATEGY="$STRATEGY" SERVERS_JSON="$JSON" node -e '
      const fs=require("fs"); const t=process.env.TARGET,s=process.env.STRATEGY,a=JSON.parse(process.env.SERVERS_JSON);
      const r=f=>{try{return JSON.parse(fs.readFileSync(f,"utf8"))}catch{return{}}};
      const w=(f,o)=>fs.writeFileSync(f,JSON.stringify(o,null,2));
      const has=(m,u)=>Object.values(m||{}).some(v=>v&&typeof v=="object"&&(v.url==u||(v.args||[]).includes(u)));
      let o=r(t); o.mcpServers=o.mcpServers&&typeof o.mcpServers=="object"?o.mcpServers:{};
      for(const {name,url} of a){if(has(o.mcpServers,url))continue;let n=name,i=2;while(o.mcpServers[n]&&!has({[n]:o.mcpServers[n]},url))n=name+"-"+i++;
        o.mcpServers[n]=s=="npx-remote"?{command:"npx",args:["-y","mcp-remote",url]}:{url};}
      w(t,o);'
  elif [[ $HAS_PY -eq 1 ]]; then
    TARGET="$TARGET" STRATEGY="$STRATEGY" SERVERS_JSON="$JSON" python3 - <<'__PY__'
import os, json
t=os.environ['TARGET']; s=os.environ['STRATEGY']; arr=json.loads(os.environ['SERVERS_JSON'])
def read(p): 
  try: return json.load(open(p))
  except: return {}
def has(m,u):
  for v in (m or {}).values():
    if isinstance(v,dict) and (v.get('url')==u or (isinstance(v.get('args'),list) and u in v['args'])): return True
  return False
o=read(t); o['mcpServers']=o.get('mcpServers') if isinstance(o.get('mcpServers'),dict) else {}
for it in arr:
  n,u=it['name'],it['url']
  if has(o['mcpServers'],u): continue
  k=n; i=2
  while k in o['mcpServers'] and not has({k:o['mcpServers'][k]},u):
    k=f"{n}-{i}"; i+=1
  o['mcpServers'][k]={'command':'npx','args':['-y','mcp-remote',u]} if s=='npx-remote' else {'url':u}
json.dump(o,open(t,'w'),indent=2,ensure_ascii=False)
__PY__
  else
    err "❌ node나 python3 둘 중 하나는 필요합니다."
    return
  fi
  ok "→ $TARGET 업데이트 완료"
}

# 1) Claude Desktop
CLAUDE_CFG="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
merge_json "$CLAUDE_CFG" "npx-remote"

# 2) Cursor
CURSOR_CFG="$HOME/.cursor/mcp.json"
merge_json "$CURSOR_CFG" "url"

# 3) Codex
CODEX_CFG="$HOME/.codex/config.toml"
mkdir -p "$(dirname "$CODEX_CFG")"
[[ -f "$CODEX_CFG" ]] || : > "$CODEX_CFG"
cp "$CODEX_CFG" "$CODEX_CFG.backup.$(date +%Y%m%d_%H%M%S)"
for s in "${SERVERS[@]}"; do
  name="${s%%|*}"; url="${s#*|}"
  grep -qF "$url" "$CODEX_CFG" || printf '\n[mcp_servers.%s]\ncommand = "npx"\nargs = ["mcp-remote", "%s"]\n' "$name" "$url" >> "$CODEX_CFG"
done
ok "→ $CODEX_CFG 업데이트 완료"

# 4) Claude Code (user scope)
if [[ $HAS_NODE -eq 1 && $HAS_NPM -eq 1 ]]; then
  # 전역 설치는 베스트-effort로만 시도 (실패해도 npx로 진행)
  npm i -g "mcp-remote@$MCP_REMOTE_VERSION" >/dev/null 2>&1 || warn "mcp-remote 글로벌 설치 실패(무시하고 진행)"
  npm i -g @anthropic-ai/claude-code >/dev/null 2>&1 || warn "claude CLI 글로벌 설치 실패(무시하고 진행)"

  # claude 명령 경로가 없으면 npx로 대체 실행
  if command -v claude >/dev/null 2>&1; then
    CLAUDE_CMD="claude"
  else
    CLAUDE_CMD="npx -y @anthropic-ai/claude-code"
  fi

  # list / add 모두 CLAUDE_CMD로 실행 (공백 포함 커맨드라 eval 사용)
  EXISTING="$(eval "$CLAUDE_CMD mcp list" 2>/dev/null || true)"
  for s in "${SERVERS[@]}"; do
    name="${s%%|*}"; url="${s#*|}"
    echo "$EXISTING" | grep -qF "$url" && continue
    eval "$CLAUDE_CMD mcp add \"$name\" --scope user -- npx -y mcp-remote \"$url\"" >/dev/null 2>&1 || true
  done
  ok "→ Claude Code(user) 등록 완료"
else
  warn "⚠️ Node/npm 미설치 → CLI 등록은 생략, 설정파일만 업데이트됨"
fi

# 5) Antigravity
ANTIGRAVITY_CFG="$HOME/.gemini/antigravity/mcp_config.json"
if [[ -d "$(dirname "$ANTIGRAVITY_CFG")" ]]; then
  merge_json "$ANTIGRAVITY_CFG" "npx-remote"
  ok "→ Antigravity 업데이트 완료"
fi

# 6) Kiro
KIRO_CFG="$HOME/.kiro/settings/mcp.json"
if [[ -d "$(dirname "$KIRO_CFG")" ]]; then
  merge_json "$KIRO_CFG" "npx-remote"
  ok "→ Kiro 업데이트 완료"
fi

echo
ok "완료 🎉"
echo "• Claude Desktop: $CLAUDE_CFG"
echo "• Cursor:         $CURSOR_CFG"
echo "• Codex:          $CODEX_CFG"
[[ -f "$ANTIGRAVITY_CFG" ]] && echo "• Antigravity:    $ANTIGRAVITY_CFG"
[[ -f "$KIRO_CFG" ]] && echo "• Kiro:           $KIRO_CFG"
echo "각 앱을 재시작하세요."
