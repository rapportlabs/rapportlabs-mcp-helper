@echo off
setlocal
chcp 65001 >nul

echo ============================================================
echo        [MCP All-in-One Setup] Running...
echo ============================================================

:: Robustly extract and run the PowerShell section (starting after ###PS_START###)
powershell -NoProfile -ExecutionPolicy Bypass -Command "$f=$false; Get-Content -LiteralPath '%~f0' -Encoding UTF8 | ForEach-Object { if($f){ $_ } elseif($_ -eq '###PS_START###'){ $f=$true } } | Out-String | Invoke-Expression"

if %errorlevel% neq 0 (
    echo.
    echo [Error] Script execution failed. (Code: %errorlevel%)
) else (
    echo.
    echo [Success] Setup completed successfully.
)

echo.
echo Press any key to exit...
pause >nul
goto :eof

###PS_START###
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Servers to add
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

function Update-JsonConfig {
  param([string]$Path, [string]$Strategy)
  
  Write-Host "--- 설정 업데이트: $(Split-Path $Path -Leaf) ---" -Cyan
  
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { 
    try { New-Item -ItemType Directory $dir -Force | Out-Null } catch { Red "  폴더 생성 불가: $dir"; return }
  }
  
  $obj = $null
  if (Test-Path $Path) {
    try { 
        $backup = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $Path $backup -ErrorAction Stop
        Yellow "  백업 생성: $(Split-Path $backup -Leaf)"
        
        $content = [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
        if ([string]::IsNullOrWhiteSpace($content)) {
            $obj = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
        } else {
            $obj = $content | ConvertFrom-Json
            if (-not $obj.mcpServers) { 
                if ($obj.PSObject.Properties.Name -contains 'mcpServers') { $obj.mcpServers = [PSCustomObject]@{} }
                else { $obj | Add-Member -Name mcpServers -Value ([PSCustomObject]@{}) -MemberType NoteProperty }
            }
        }
    } catch { 
        Red "  파일 읽기 오류(초기화): $_"
        $obj = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
    }
  } else {
    $obj = [PSCustomObject]@{ mcpServers = [PSCustomObject]@{} }
  }
  
  $added = 0
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
        command = 'npx'; args = @('-y', 'mcp-remote', $url)
      })
    } else {
      $obj.mcpServers | Add-Member -Name $final -MemberType NoteProperty -Value ([PSCustomObject]@{ url = $url })
    }
    Green "  [+] 추가: $final"
    $added++
  }

  if ($added -gt 0) {
    $json = $obj | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding $false))
    Green "  → 업데이트 성공!"
  } else {
    Yellow "  변경 사항 없음 (이미 세팅됨)."
  }
  Write-Host ""
}

try {
    # 1) Claude Desktop
    Update-JsonConfig (Join-Path $env:APPDATA 'Claude\claude_desktop_config.json') 'npx-remote'
    # 2) Cursor
    Update-JsonConfig (Join-Path $env:USERPROFILE '.cursor\mcp.json') 'url'
    # 3) Antigravity
    Update-JsonConfig (Join-Path $env:USERPROFILE '.gemini\antigravity\mcp_config.json') 'npx-remote'
    # 4) Kiro
    Update-JsonConfig (Join-Path $env:USERPROFILE '.kiro\settings\mcp.json') 'npx-remote'

    # 5) Claude Code
    Cyan "Node.js 기반 Claude Code 체크 중..."
    if ((Get-Command node -ErrorAction SilentlyContinue) -and (Get-Command npm -ErrorAction SilentlyContinue)) {
      try { 
        Write-Host "  mcp-remote 설치..." -NoNewline
        npm i -g "mcp-remote@$McpRemoteVersion" 2>$null | Out-Null
        Green " [Done]"
        
        Write-Host "  claude-code 설치..." -NoNewline
        npm i -g @anthropic-ai/claude-code 2>$null | Out-Null
        Green " [Done]"
        
        $c = if (Get-Command claude -ErrorAction SilentlyContinue) { "claude" } else { "npx -y @anthropic-ai/claude-code" }
        $list = & $env:ComSpec /c "$c mcp list" 2>$null
        
        $codeAdded = 0
        foreach ($s in $servers) {
          if ($list -and ($list -like "*$($s.url)*")) { continue }
          & $env:ComSpec /c "$c mcp add $($s.name) --scope user -- npx -y mcp-remote $($s.url)" 1>$null 2>$null
          $codeAdded++
        }
        if ($codeAdded -gt 0) { Green "→ Claude Code 설정 완료 ($codeAdded 개 추가)" }
        else { Yellow "→ Claude Code 이미 설정됨" }
      } catch { Yellow "  Claude Code 설정 중 일부 오류 발생 (무시 가능)" }
    } else {
      Yellow "  Node.js를 찾을 수 없어 Claude Code 설정은 건너뜁니다."
    }
} catch {
    Red "`n[!!] 실행 중 오류 발생: $($_.Exception.Message)"
}
