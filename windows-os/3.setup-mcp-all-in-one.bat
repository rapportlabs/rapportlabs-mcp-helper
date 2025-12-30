@echo off
setlocal
chcp 65001 >nul
echo [MCP All-in-One Setup] 스크립트를 준비 중입니다...

:: PowerShell 파트 추출 및 실행
powershell -NoProfile -ExecutionPolicy Bypass -Command "$script = (Get-Content -LiteralPath '%~f0' -Raw -Encoding UTF8); $start = $script.IndexOf('<# POWERSHELL_START #>'); if ($start -ge 0) { iex $script.Substring($start) } else { Write-Error '스크립트 시작 표식을 찾을 수 없습니다.' }"

if %errorlevel% neq 0 (
    echo.
    echo [오류] 스크립트 실행 중 문제가 발생했습니다.
)

pause
goto :eof

<# POWERSHELL_START #>
$ErrorActionPreference = 'Stop'

# --- 서버 목록 ---
$servers = @(
  @{ name='rpwiki';   url='https://rapportwiki-mcp.damoa.rapportlabs.dance/mcp' },
  @{ name='notion';   url='https://notion-mcp.damoa.rapportlabs.dance/mcp' },
  @{ name='bigquery'; url='https://bigquery-mcp.damoa.rapportlabs.dance/mcp' },
  @{ name='slack';    url='https://slack-mcp.damoa.rapportlabs.dance/sse' }
)

$McpRemoteVersion = '0.1.18'

function Green($m){ Write-Host $m -ForegroundColor Green }
function Cyan($m){ Write-Host $m -ForegroundColor Cyan }
function Yellow($m){ Write-Host $m -ForegroundColor Yellow }
function Red($m){ Write-Host $m -ForegroundColor Red }

# --- JSON 설정파일 병합 유틸 ---
function Update-JsonConfig {
  param([string]$Path, [ValidateSet('npx-remote','url')][string]$Strategy)
  
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { 
    try { New-Item -ItemType Directory $dir -Force | Out-Null } catch { Red "폴더를 생성할 수 없습니다: $dir"; return }
  }
  
  if (Test-Path $Path) {
    try { Copy-Item $Path "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')" -ErrorAction SilentlyContinue } catch {}
    $obj = Get-Content $Path -Raw -Encoding UTF8 | ConvertFrom-Json
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

  # 표준 JSON 변환 (들여쓰기 포함)
  $jsonFormatted = $obj | ConvertTo-Json -Depth 10
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  try { 
    [System.IO.File]::WriteAllText($Path, $jsonFormatted, $utf8NoBom)
    Green "→ $Path 업데이트 완료"
  } catch { 
    Red "파일을 저장할 수 없습니다 (권한 필요): $Path" 
  }
}

Write-Host "`n========================================"
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
$hasNpm  = (Get-Command npm -ErrorAction SilentlyContinue) -ne $null
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
