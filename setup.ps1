# Microwave node agent — installs agent + optional Ollama + model pulls.
# Requires: Node.js 18+ (npm on PATH), PowerShell 5.1+.

$ErrorActionPreference = 'Stop'

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
  Write-Host '  ╔════════════════════════════════════════╗'
  Write-Host '  ║   Microwave — node agent setup         ║'
  Write-Host '  ╚════════════════════════════════════════╝'
  Write-Host ''
}

Write-Banner

if (-not (Get-Command node -ErrorAction SilentlyContinue) -or -not (Get-Command npm -ErrorAction SilentlyContinue)) {
  Write-Host 'Install Node.js 18+ from https://nodejs.org/ (includes npm), then run this again.' -ForegroundColor Red
  exit 1
}

if ($env:MICROWAVE_NODE_DIR) {
  $null = New-Item -ItemType Directory -Force -Path $env:MICROWAVE_NODE_DIR
  $Root = (Resolve-Path $env:MICROWAVE_NODE_DIR).Path
} elseif ($PSScriptRoot) {
  $Root = $PSScriptRoot
} else {
  $d = Join-Path (Get-Location).Path 'microwave-node'
  $null = New-Item -ItemType Directory -Force -Path $d
  $Root = (Resolve-Path $d).Path
}

Set-Location $Root
Write-Host "-> install dir: $Root"

if (-not (Test-Path -LiteralPath 'microwave-node.js')) {
  Write-Host '-> download microwave-node.js'
  Invoke-WebRequest -Uri "$RepoRaw/microwave-node.js" -OutFile 'microwave-node.js' -UseBasicParsing
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
'@ | Set-Content -Path 'package.json' -Encoding ascii
}

Write-Host '-> npm install'
& npm install
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if (-not (Test-Path -LiteralPath '.env')) {
  if (Test-Path -LiteralPath '.env.example') {
    Copy-Item '.env.example' '.env'
    Write-Host '-> created .env from .env.example'
  } else {
    @'
PORT=3847
OLLAMA_URL=http://127.0.0.1:11434
NODE_DEVICE_TOKEN=
OLLAMA_NUM_PREDICT=1024
OLLAMA_KEEP_ALIVE=30m
'@ | Set-Content -Path '.env' -Encoding ascii
    Write-Host '-> created .env (defaults)'
  }
}

function Refresh-PathEnv {
  $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $user = [Environment]::GetEnvironmentVariable('Path', 'User')
  if ($machine -or $user) {
    $env:Path = "$machine;$user" -replace ';+', ';'
  }
}

function Test-OllamaCmd {
  return [bool](Get-Command ollama -ErrorAction SilentlyContinue)
}

Write-Host ''
if (Test-OllamaCmd) {
  try {
    $ver = & ollama --version 2>$null
    Write-Host "-> Ollama on PATH: $ver"
  } catch {
    Write-Host '-> Ollama on PATH'
  }
} else {
  Write-Host 'Ollama not found on PATH.'
  $yn = Read-Host 'Install Ollama with winget (Ollama.Ollama)? [y/N]'
  if ($yn -match '^[Yy]') {
    $winget = Get-Command winget -ErrorAction SilentlyContinue
    if (-not $winget) {
      Write-Host 'winget not available. Install Ollama from https://ollama.com/download then re-run this script.' -ForegroundColor Yellow
    } else {
      & winget install -e --id Ollama.Ollama --accept-package-agreements --accept-source-agreements
      Refresh-PathEnv
    }
  }
  if (-not (Test-OllamaCmd)) {
    Write-Host '-> Ollama still not on PATH — install from https://ollama.com/download , reopen PowerShell, re-run to pull models.' -ForegroundColor Yellow
  } else {
    Write-Host "-> Ollama ready: $(& ollama --version 2>$null)"
  }
}

if (Test-OllamaCmd) {
  Write-Host ''
  Write-Host 'Which models should Ollama download? (large files — pick what you need)'
  $i = 1
  foreach ($m in $PresetModels) {
    Write-Host "  $i) $m"
    $i++
  }
  Write-Host '  a) All of the above'
  Write-Host '  c) Enter a custom Ollama model name'
  Write-Host '  0) Skip pulls for now'
  $choice = Read-Host '> '
  $choice = ($choice -replace ',', ' ').Trim()
  $toPull = [System.Collections.Generic.List[string]]::new()

  if ($choice -match '^[Aa]$') {
    foreach ($m in $PresetModels) { $null = $toPull.Add($m) }
  } elseif ($choice -eq '' -or $choice -eq '0') {
    # skip
  } elseif ($choice -eq 'c' -or $choice -eq 'C') {
    $custom = Read-Host 'Model name (e.g. gemma3:4b)'
    if ($custom.Trim()) { $null = $toPull.Add($custom.Trim()) }
  } else {
    foreach ($n in ($choice -split '\s+')) {
      if ($n -match '^\d+$') {
        $idx = [int]$n - 1
        if ($idx -ge 0 -and $idx -lt $PresetModels.Count) {
          $null = $toPull.Add($PresetModels[$idx])
        }
      }
    }
  }

  foreach ($m in $toPull) {
    Write-Host "-> ollama pull $m"
    $oldEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      & ollama pull $m
      if ($LASTEXITCODE -ne 0 -and $null -ne $LASTEXITCODE) {
        Write-Host "  (failed: $m)" -ForegroundColor Yellow
      }
    } catch {
      Write-Host "  (failed: $m — $($_.Exception.Message))" -ForegroundColor Yellow
    }
    $ErrorActionPreference = $oldEap
  }
}

Write-Host ''
Write-Host '  ╔════════════════════════════════════════╗'
Write-Host '  ║  Setup finished                        ║'
Write-Host '  ╚════════════════════════════════════════╝'
Write-Host '  In this folder: edit .env, then:'
Write-Host '    npm run register -- --main https://SERVER --url https://YOU:PORT --name gpu --token SECRET --models gemma3:4b'
Write-Host '    npm start'
