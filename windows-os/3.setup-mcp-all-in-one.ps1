# ================== MCP All-in-One (Windows / paste-to-run) ==================
$ErrorActionPreference = 'Stop'

# --- 서버 목록(원하는 대로 수정 가능): 동일 URL이면 중복 등록 안 함 ---
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

# --- Node/npm 준비 ---
$hasNode = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
$hasNpm  = (Get-Command npm  -ErrorAction SilentlyContinue) -ne $null

Write-Host "========================================"
Write-Host "MCP Setup (Windows / paste-to-run)"
Write-Host "Node: " -NoNewline; if($hasNode){Write-Host (node -v)} else {Write-Host "없음"}
Write-Host "npm : " -NoNewline; if($hasNpm){ Write-Host (npm -v)} else {Write-Host "없음"}
Write-Host "========================================`n"

if(-not $hasNode -or -not $hasNpm){
  $winget = Get-Command winget -ErrorAction SilentlyContinue
  if($winget){
    Cyan "Node가 없어 winget으로 설치를 시도합니다…"
    try {
      winget install --id OpenJS.NodeJS -e --accept-source-agreements --accept-package-agreements | Out-Null
    } catch {
      try {
        winget install --id OpenJS.NodeJS.LTS -e --accept-source-agreements --accept-package-agreements | Out-Null
      } catch {
        Yellow "winget Node 설치 실패 (권한/정책 문제일 수 있음). Node 없이 계속 진행합니다."
      }
    }
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
    $hasNode = (Get-Command node -ErrorAction SilentlyContinue) -ne $null
    $hasNpm  = (Get-Command npm  -ErrorAction SilentlyContinue) -ne $null
  } else {
    Yellow "winget이 없어 Node 자동 설치는 생략합니다."
  }
}

# --- 올바른 JSON 포맷팅 함수 ---
function Format-JsonIndent {
  param([string]$json)
  
  $indent = 0
  $result = ""
  $inString = $false
  $escaped = $false
  
  for ($i = 0; $i -lt $json.Length; $i++) {
    $char = $json[$i]
    
    if ($escaped) {
      $result += $char
      $escaped = $false
      continue
    }
    
    if ($char -eq '\') {
      $escaped = $true
      $result += $char
      continue
    }
    
    if ($char -eq '"') {
      $inString = -not $inString
      $result += $char
      continue
    }
    
    if ($inString) {
      $result += $char
      continue
    }
    
    switch ($char) {
      '{' {
        $result += "{`n"
        $indent++
        $result += "  " * $indent
      }
      '}' {
        $result += "`n"
        $indent--
        $result += "  " * $indent + "}"
      }
      '[' {
        $result += "[`n"
        $indent++
        $result += "  " * $indent
      }
      ']' {
        $result += "`n"
        $indent--
        $result += "  " * $indent + "]"
      }
      ',' {
        $result += ",`n"
        $result += "  " * $indent
      }
      ':' {
        $result += ": "
      }
      default {
        if ($char -ne ' ' -and $char -ne "`t" -and $char -ne "`n" -and $char -ne "`r") {
          $result += $char
        }
      }
    }
  }
  
  return $result
}

# --- JSON 설정파일 병합 유틸 ---
function Update-JsonConfig {
  param([string]$Path, [ValidateSet('npx-remote','url')][string]$Strategy)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory $dir | Out-Null }
  
  # 기존 파일 읽기
  if (Test-Path $Path) {
    Copy-Item $Path "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $json = Get-Content $Path -Raw -Encoding UTF8
    $obj = $json | ConvertFrom-Json
  } else {
    $obj = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
  }
  
  if (-not $obj.mcpServers) { 
    $obj | Add-Member -Name mcpServers -Value ([PSCustomObject]@{}) -MemberType NoteProperty 
  }

  # 서버 추가
  foreach ($s in $servers) {
    $url = $s.url
    $exists = $false
    
    foreach ($prop in $obj.mcpServers.PSObject.Properties) {
      $v = $prop.Value
      if (($v.url -eq $url) -or ($v.args -and ($v.args -contains $url))) { 
        $exists = $true
        break 
      }
    }
    
    if ($exists) { continue }
    
    $name = $s.name
    $final = $name
    $i = 2
    while ($obj.mcpServers.PSObject.Properties.Name -contains $final) { 
      $final = "$name-$i"
      $i++ 
    }
    
    if ($Strategy -eq 'npx-remote') {
      $obj.mcpServers | Add-Member -Name $final -MemberType NoteProperty -Value ([PSCustomObject]@{
        command = 'npx'
        args = @('-y', 'mcp-remote', $url)
      })
    } else {
      $obj.mcpServers | Add-Member -Name $final -MemberType NoteProperty -Value ([PSCustomObject]@{
        url = $url
      })
    }
  }

  # JSON 변환 및 포맷팅
  $jsonRaw = $obj | ConvertTo-Json -Depth 10 -Compress
  $jsonFormatted = Format-JsonIndent $jsonRaw
  
  # UTF-8 without BOM으로 저장
  $utf8NoBom = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllText($Path, $jsonFormatted, $utf8NoBom)
  
  Green "→ $Path 업데이트 완료"
}

# --- 1) Claude Desktop ---
$ClaudeCfg = Join-Path $env:APPDATA 'Claude\claude_desktop_config.json'
Update-JsonConfig $ClaudeCfg 'npx-remote'

# --- 2) Cursor ---
$CursorCfg = Join-Path $env:USERPROFILE '.cursor\mcp.json'
Update-JsonConfig $CursorCfg 'url'

# --- 3) Antigravity ---
$AntigravityCfg = Join-Path $env:USERPROFILE '.gemini\antigravity\mcp_config.json'
Update-JsonConfig $AntigravityCfg 'npx-remote'

# --- 4) Kiro ---
$KiroCfg = Join-Path $env:USERPROFILE '.kiro\settings\mcp.json'
Update-JsonConfig $KiroCfg 'npx-remote'

# --- 5) Claude Code 설치 + 자동 등록 (user scope) ---
if ($hasNode -and $hasNpm) {
  Cyan "npm 전역에 mcp-remote@$McpRemoteVersion / Claude Code CLI 설치…"
  try { npm i -g "mcp-remote@$McpRemoteVersion" | Out-Null } catch { Yellow "mcp-remote 전역 설치 실패 (무시하고 진행)"; }
  try { npm i -g @anthropic-ai/claude-code | Out-Null } catch { Yellow "claude CLI 전역 설치 실패 (npx로 진행)"; }

  $claude = Get-Command claude -ErrorAction SilentlyContinue
  $CLAUDE_CMD = if ($claude) { "claude" } else { "npx -y @anthropic-ai/claude-code" }

  try {
    $existing = & $env:ComSpec /c "$CLAUDE_CMD mcp list" 2>$null
  } catch { $existing = "" }

  foreach ($s in $servers) {
    if ($existing -and ($existing -like "*$($s.url)*")) { continue }
    & $env:ComSpec /c "$CLAUDE_CMD mcp add $($s.name) --scope user -- npx -y mcp-remote $($s.url)" 1>$null 2>$null
  }
  Green "→ Claude Code(user) 등록 완료"
} else {
  Yellow "Node/npm이 없어 Claude Code 자동 등록은 생략(설정 파일들은 이미 반영됨)"
}

Write-Host ""
Green "완료 🎉"
Write-Host "• Claude Desktop: $ClaudeCfg"
Write-Host "• Cursor:         $CursorCfg"
Write-Host "• Antigravity:    $AntigravityCfg"
Write-Host "• Kiro:           $KiroCfg"
Yellow "각 앱을 재시작하세요."
# =========================================================================== #
