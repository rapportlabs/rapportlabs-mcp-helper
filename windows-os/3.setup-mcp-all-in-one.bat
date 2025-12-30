@echo off
setlocal EnableDelayedExpansion
chcp 65001 >nul 2>&1

echo ============================================================
echo        [MCP All-in-One Setup] Running...
echo ============================================================
echo.

:: Create temp PS1 file (avoids Korean path issues)
set "TEMP_PS1=%TEMP%\mcp_setup_%RANDOM%.ps1"

:: Extract PowerShell section to temp file
set "extracting="
(for /f "usebackq delims=" %%L in ("%~f0") do (
    if defined extracting (
        echo(%%L
    ) else (
        echo(%%L | findstr /C:"###PS_START###" >nul && set "extracting=1"
    )
)) > "%TEMP_PS1%" 2>nul

:: Run PowerShell script from temp location
powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP_PS1%"
set "EXITCODE=%errorlevel%"

:: Cleanup
del /f /q "%TEMP_PS1%" >nul 2>&1

if %EXITCODE% neq 0 (
    echo.
    echo [Error] Script execution failed. (Code: %EXITCODE%)
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
$OutputEncoding = [System.Text.Encoding]::UTF8

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Host "[Error] PowerShell 3.0+ required. Current: $($PSVersionTable.PSVersion)" -ForegroundColor Red
    exit 1
}

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
  
  Cyan "--- Setting: $(Split-Path $Path -Leaf) ---"
  
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { 
    try { New-Item -ItemType Directory $dir -Force | Out-Null } 
    catch { Red "  Cannot create folder: $dir"; return }
  }
  
  $obj = $null
  if (Test-Path $Path) {
    try { 
        $backup = "$Path.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
        Copy-Item $Path $backup -ErrorAction Stop
        Yellow "  Backup: $(Split-Path $backup -Leaf)"
        
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
        Red "  Read error (init): $_"
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
    Green "  [+] Added: $final"
    $added++
  }

  if ($added -gt 0) {
    # Check if file is locked
    try {
      $fs = [System.IO.File]::Open($Path, 'OpenOrCreate', 'ReadWrite', 'None')
      $fs.Close()
    } catch {
      Red "  File is locked! Close the app using this config first."
      return
    }
    
    $json = $obj | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding $false))
    Green "  -> Updated!"
  } else {
    Yellow "  No changes (already configured)."
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
    Cyan "Checking Node.js for Claude Code..."
    $nodePath = $null
    $npmPath = $null
    
    # Try to find node in common locations
    $searchPaths = @(
        (Get-Command node -ErrorAction SilentlyContinue).Source,
        "$env:ProgramFiles\nodejs\node.exe",
        "${env:ProgramFiles(x86)}\nodejs\node.exe",
        "$env:LOCALAPPDATA\Programs\nodejs\node.exe"
    ) | Where-Object { $_ -and (Test-Path $_) }
    
    if ($searchPaths) {
        $nodePath = $searchPaths[0]
        $npmPath = Join-Path (Split-Path $nodePath) 'npm.cmd'
        if (-not (Test-Path $npmPath)) { $npmPath = $null }
    }
    
    if ($nodePath -and $npmPath) {
      try { 
        Write-Host "  Installing mcp-remote..." -NoNewline
        & $npmPath i -g "mcp-remote@$McpRemoteVersion" 2>$null | Out-Null
        Green " [Done]"
        
        Write-Host "  Installing claude-code..." -NoNewline
        & $npmPath i -g @anthropic-ai/claude-code 2>$null | Out-Null
        Green " [Done]"
        
        $claudeCmd = Get-Command claude -ErrorAction SilentlyContinue
        if ($claudeCmd) {
            $c = $claudeCmd.Source
        } else {
            Yellow " (claude not in PATH, skipping mcp add)"
            throw "skip"
        }
        
        $list = & $c mcp list 2>$null
        
        $codeAdded = 0
        foreach ($s in $servers) {
          if ($list -and ($list -like "*$($s.url)*")) { continue }
          & $c mcp add $s.name --scope user -- npx -y mcp-remote $s.url 2>$null | Out-Null
          $codeAdded++
        }
        if ($codeAdded -gt 0) { Green "-> Claude Code configured ($codeAdded added)" }
        else { Yellow "-> Claude Code already configured" }
      } catch { 
        if ($_.Exception.Message -ne "skip") {
            Yellow "  Claude Code setup had issues (can be ignored)"
        }
      }
    } else {
      Yellow "  Node.js not found. Skipping Claude Code setup."
    }
    
    Write-Host ""
    Green "=== All done! ==="
} catch {
    Red "`n[!!] Error: $($_.Exception.Message)"
    exit 1
}
