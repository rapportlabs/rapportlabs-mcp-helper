@echo off
echo [MCP All-in-One Setup] 스크립트를 준비 중입니다...
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content -LiteralPath '%~f0') | Select-Object -Skip 6 | Out-String)"
pause
goto :eof

# ================== MCP All-in-One (PowerShell Part) ==================
$ErrorActionPreference = 'Stop'

# --- 서버 목록 ---
$servers = @(
  @{ name='rpwiki';  url='https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp' },
  @{ name='notion';  url='https://notion-mcp.damoa.rapportlabs.dance/mcp' },
  @{ name='bigquery';url='https://bigquery-mcp.damoa.rapportlabs.dance/mcp' },
  @{ name='slack';   url='https://slack-mcp.damoa.rapportlabs.dance/sse' },
)

$McpRemoteVersion = '0.1.18'

function Green($m){ Write-Host $m -ForegroundColor Green }
function Cyan($m){ Write-Host $m -ForegroundColor Cyan }
function Yellow($m){ Write-Host $m -ForegroundColor Yellow }
function Red($m){ Write-Host $m -ForegroundColor Red }

# --- JSON 포맷팅 함수 ---
function Format-JsonIndent {
  param([string]$json)
  $indent = 0; $result = ""; $inString = $false; $escaped = $false
  for ($i = 0; $i -lt $json.Length; $i++) {
    $char = $json[$i]
    if ($escaped) { $result += $char; $escaped = $false; continue }
    if ($char -eq '\') { $escaped = $true; $result += $char; continue }
    if ($char -eq '"') { $inString = -not $inString; $result += $char; continue }
    if ($inString) { $result += $char; continue }
    switch ($char) {
      '{' { $result += "{`n"; $indent++; $result += "  " * $indent }
      '}' { $result += "`n"; $indent--; $result += "  " * $indent + "}" }
      '[' { $result += "[`n"; $indent++; $result += "  " * $indent }
      ']' { $result += "`n"; $indent--; $result += "  " * $indent + "]" }
      ',' { $result += ",`n"; $result += "  " * $indent }
      ':' { $result += ": " }
      default { if ($char -ne ' ' -and $char -ne "`t" -and $char -ne "`n" -and $char -ne "`r") { $result += $char } }
    }
  }
  return $result
}

# --- JSON 설정파일 병합 유틸 ---
function Update-JsonConfig {
  param([string]$Path, [ValidateSet('npx-remote','url')][string]$Strategy)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { 
    try { New-Item -ItemType Directory $dir -Force | Out-Null } catch {}
  }
  
  if (Test-Path $Path) {
    try { Copy-Item $Path "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')" -ErrorAction SilentlyContinue } catch {}
    $json = Get-Content $Path -Raw -Encoding UTF8
    $obj = $json | ConvertFrom-Json
  } else {
    $obj = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
  }
  
  if (-not $obj.mcpServers) { $obj | Add-Member -Name mcpServers -Value ([PSCustomObject]@{}) -MemberType NoteProperty }

  foreach ($s in $servers) {
    $url = $s.url; $exists = $false
    foreach ($prop in $obj.mcpServers.PSObject.Properties) {
      $v = $prop.Value
      if ($v -and ($v.url -eq $url -or ($v.args -and ($v.args -contains $url)))) { $exists = $true; break }
    }
    if ($exists) { continue }
    $name = $s.name; $final = $name; $i = 2
    while ($obj.mcpServers.PSObject.Properties.Name -contains $final) { $final = "$name-$i"; $i++ }
    
    if ($Strategy -eq 'npx-remote') {
      $obj.mcpServers | Add-Member -Name $final -MemberType NoteProperty -Value ([PSCustomObject]@{
        command = 'npx'
        args = @('-y', 'mcp-remote', $url)
      })
    } else {
      $obj.mcpServers | Add-Member -Name $final -MemberType NoteProperty -Value ([PSCustomObject]@{ url = $url })
    }
  }

  $jsonRaw = $obj | ConvertTo-Json -Depth 10 -Compress
  $jsonFormatted = Format-JsonIndent $jsonRaw
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  try { [System.IO.File]::WriteAllText($Path, $jsonFormatted, $utf8NoBom) } catch { Red "관리자 권한이 필요할 수 있습니다: $Path" }
  Green "→ $Path 업데이트 완료"
}

Write-Host "========================================"
Write-Host "MCP All-in-One Setup (Windows)"
Write-Host "========================================`n"

# 1) Claude Desktop
$ClaudeCfg = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
Update-JsonConfig $ClaudeCfg 'npx-remote'

# 2) Cursor
$CursorCfg = Join-Path $env:USERPROFILE '.cursor\mcp.json'
Update-JsonConfig $CursorCfg 'url'

# 3) Antigravity
$AntigravityCfg = Join-Path $env:USERPROFILE '.gemini\antigravity\mcp_config.json'
Update-JsonConfig $AntigravityCfg 'npx-remote'

# 4) Kiro
$KiroCfg = Join-Path $env:USERPROFILE '.kiro\settings\mcp.json'
Update-JsonConfig $KiroCfg 'npx-remote'

# 5) Claude Code
$hasNode = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
$hasNpm  = (Get-Command npm  -ErrorAction SilentlyContinue) -ne $null
if ($hasNode -and $hasNpm) {
  Cyan "`nnpm 전역 패키지 및 Claude Code 등록 시도..."
  try { npm i -g "mcp-remote@$McpRemoteVersion" | Out-Null } catch {}
  try { npm i -g @anthropic-ai/claude-code | Out-Null } catch {}
  
  $claude = Get-Command claude -ErrorAction SilentlyContinue
  $CLAUDE_CMD = if ($claude) { "claude" } else { "npx -y @anthropic-ai/claude-code" }
  
  try { $existing = & $env:ComSpec /c "$CLAUDE_CMD mcp list" 2>$null } catch { $existing = "" }
  foreach ($s in $servers) {
    if ($existing -and ($existing -like "*$($s.url)*")) { continue }
    & $env:ComSpec /c "$CLAUDE_CMD mcp add $($s.name) --scope user -- npx -y mcp-remote $($s.url)" 1>$null 2>$null
  }
  Green "→ Claude Code 등록 완료"
} else {
  Yellow "`nNode.js/npm이 없어 Claude Code 자동 등록은 생략합니다."
}

Write-Host "`n작업이 모두 완료되었습니다."
