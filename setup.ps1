# Microwave node agent — Windows setup (PowerShell 5.1+).
# Tolerant of iex/irm, npm.cmd, and Ollama as external exes.

$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
} catch { }

$RepoRaw = if ($env:MICROWAVE_NODE_REPO_RAW) { $env:MICROWAVE_NODE_REPO_RAW.TrimEnd('/') } else { '' }
if (-not $RepoRaw) {
  $RepoRaw = 'https://raw.githubusercontent.com/robot-time/microwave-node-testing/main'
}

$PresetModels = @(
  'gemma3:4b',
  'phi3:mini',
  'llama3.2:3b',
  'llama3.1:8b',
  'qwen2.5:7b',
  'phi4-mini'
)

function Write-Banner {
  Write-Host ''
  Write-Host '  +------------------------------------------+'
  Write-Host '  |   Microwave - node agent setup           |'
  Write-Host '  +------------------------------------------+'
  Write-Host ''
}

function Get-CmdPath {
  param([string]$Name)
  try {
    $g = Get-Command $Name -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $g) { return $null }
    if ($g.Path) { return [string]$g.Path }
    if ($g.Source) { return [string]$g.Source }
    if ($g.Definition) { return [string]$g.Definition }
  } catch { }
  return $null
}

function Invoke-DownloadFile {
  param([string]$Uri, [string]$OutFile)
  try {
    Invoke-WebRequest -Uri $Uri -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
    return $true
  } catch {
    $curl = Get-CmdPath 'curl.exe'
    if ($curl) {
      & $curl -fsSL $Uri -o $OutFile
      return ($LASTEXITCODE -eq 0)
    }
    Write-Host "Download failed: $($_.Exception.Message)" -ForegroundColor Red
    return $false
  }
}

function Test-OllamaAvailable {
  return $null -ne (Get-CmdPath 'ollama')
}

function Run-Ollama {
  param([string[]]$Args)
  $exe = Get-CmdPath 'ollama'
  if (-not $exe) { return 1 }
  try {
    $p = Start-Process -FilePath $exe -ArgumentList $Args -Wait -PassThru -NoNewWindow
    if ($p -and $null -ne $p.ExitCode) { return [int]$p.ExitCode }
  } catch {
    Write-Host "  (ollama: $($_.Exception.Message))" -ForegroundColor Yellow
  }
  return 1
}

Write-Banner

if (-not (Get-CmdPath 'node') -or -not (Get-CmdPath 'npm')) {
  Write-Host 'Install Node.js 18+ from https://nodejs.org/ (includes npm), then run this again.' -ForegroundColor Red
  exit 1
}

try {
  if ($env:MICROWAVE_NODE_DIR) {
    $null = New-Item -ItemType Directory -Force -Path $env:MICROWAVE_NODE_DIR -ErrorAction Stop
    $Root = (Resolve-Path -LiteralPath $env:MICROWAVE_NODE_DIR).Path
  } elseif ($MyInvocation.MyCommand.Path) {
    $Root = Split-Path -Parent $MyInvocation.MyCommand.Path
  } elseif ($PSScriptRoot) {
    $Root = $PSScriptRoot
  } else {
    $d = Join-Path -Path (Get-Location).Path -ChildPath 'microwave-node'
    $null = New-Item -ItemType Directory -Force -Path $d -ErrorAction Stop
    $Root = (Resolve-Path -LiteralPath $d).Path
  }
} catch {
  Write-Host "Could not resolve install folder: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

Set-Location -LiteralPath $Root
Write-Host "-> install dir: $Root"

if (-not (Test-Path -LiteralPath 'microwave-node.js')) {
  Write-Host '-> download microwave-node.js'
  if (-not (Invoke-DownloadFile -Uri "$RepoRaw/microwave-node.js" -OutFile 'microwave-node.js')) {
    exit 1
  }
}

if (-not (Test-Path -LiteralPath 'package.json')) {
  Write-Host '-> write package.json'
  @'
{
  "name": "microwave-node",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node microwave-node.js",
    "register": "node microwave-node.js register",
    "heartbeat": "node microwave-node.js heartbeat"
  },
  "engines": { "node": ">=18" },
  "dependencies": {
    "dotenv": "^16.4.5",
    "express": "^4.21.2"
  }
}
'@ | Set-Content -LiteralPath 'package.json' -Encoding ascii
}

Write-Host '-> npm install'
if (-not (Get-CmdPath 'npm')) { exit 1 }
try {
  # npm on Windows is usually a .cmd shim; cmd /c avoids PowerShell native-command quirks.
  $npmProc = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'npm', 'install') -WorkingDirectory $Root -Wait -PassThru -NoNewWindow
  if (-not $npmProc -or $npmProc.ExitCode -ne 0) {
    $c = if ($npmProc) { $npmProc.ExitCode } else { -1 }
    Write-Host "npm install exited with code $c" -ForegroundColor Red
    exit $c
  }
} catch {
  Write-Host "npm install failed: $($_.Exception.Message)" -ForegroundColor Red
  exit 1
}

if (-not (Test-Path -LiteralPath '.env')) {
  if (Test-Path -LiteralPath '.env.example') {
    Copy-Item -LiteralPath '.env.example' -Destination '.env'
    Write-Host '-> created .env from .env.example'
  } else {
    @'
PORT=3847
OLLAMA_URL=http://127.0.0.1:11434
NODE_DEVICE_TOKEN=
OLLAMA_NUM_PREDICT=1024
OLLAMA_KEEP_ALIVE=30m
'@ | Set-Content -LiteralPath '.env' -Encoding ascii
    Write-Host '-> created .env (defaults)'
  }
}

function Refresh-PathEnv {
  try {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($machine -and $user) {
      $env:Path = "$machine;$user"
    } elseif ($machine) { $env:Path = $machine }
    elseif ($user) { $env:Path = $user }
  } catch { }
}

Write-Host ''
if (Test-OllamaAvailable) {
  Write-Host '-> Ollama found on PATH'
} else {
  Write-Host 'Ollama not found on PATH.'
  try {
    $yn = Read-Host 'Install Ollama with winget (Ollama.Ollama)? [y/N]'
  } catch {
    $yn = ''
  }
  if ($yn -match '^[Yy]') {
    $winget = Get-CmdPath 'winget'
    if (-not $winget) {
      Write-Host 'winget not found. Install Ollama from https://ollama.com/download' -ForegroundColor Yellow
    } else {
      try {
        $wg = Start-Process -FilePath $winget -ArgumentList @('install', '-e', '--id', 'Ollama.Ollama', '--accept-package-agreements', '--accept-source-agreements') -Wait -PassThru -NoNewWindow
        if ($wg.ExitCode -ne 0) {
          Write-Host "winget exited $($wg.ExitCode). Try https://ollama.com/download" -ForegroundColor Yellow
        }
      } catch {
        Write-Host "winget failed: $($_.Exception.Message)" -ForegroundColor Yellow
      }
      Refresh-PathEnv
    }
  }
  if (-not (Test-OllamaAvailable)) {
    Write-Host '-> Ollama still not on PATH. Install from https://ollama.com/download , reopen PowerShell, re-run to pull models.' -ForegroundColor Yellow
  } else {
    Write-Host '-> Ollama is now on PATH'
  }
}

if (Test-OllamaAvailable) {
  Write-Host ''
  Write-Host 'Which models should Ollama download? (large files)'
  $i = 1
  foreach ($m in $PresetModels) {
    Write-Host "  $i) $m"
    $i++
  }
  Write-Host '  a) All of the above'
  Write-Host '  c) Enter a custom Ollama model name'
  Write-Host '  0) Skip pulls for now'
  try {
    $choice = Read-Host '> '
  } catch {
    $choice = '0'
  }
  $choice = ($choice -replace ',', ' ').Trim()
  [string[]]$toPull = @()

  if ($choice -match '^[Aa]$') {
    $toPull = @($PresetModels)
  } elseif ($choice -eq '' -or $choice -eq '0') {
    $toPull = @()
  } elseif ($choice -eq 'c' -or $choice -eq 'C') {
    try {
      $custom = Read-Host 'Model name (e.g. gemma3:4b)'
    } catch {
      $custom = ''
    }
    if ($custom -and $custom.Trim()) {
      $toPull = @($custom.Trim())
    }
  } else {
    foreach ($n in ($choice -split '\s+')) {
      if ($n -match '^\d+$') {
        $idx = [int]$n - 1
        if ($idx -ge 0 -and $idx -lt $PresetModels.Length) {
          $toPull += $PresetModels[$idx]
        }
      }
    }
  }

  foreach ($m in $toPull) {
    Write-Host "-> ollama pull $m"
    $code = Run-Ollama -Args @('pull', $m)
    if ($code -ne 0) {
      Write-Host "  (pull failed or incomplete: $m)" -ForegroundColor Yellow
    }
  }
}

Write-Host ''
Write-Host '  +------------------------------------------+'
Write-Host '  |  Setup finished                          |'
Write-Host '  +------------------------------------------+'
Write-Host '  In this folder: edit .env, then:'
Write-Host '    npm run register -- --main https://SERVER --url https://YOU:PORT --name gpu --token SECRET --models gemma3:4b'
Write-Host '    npm start'
