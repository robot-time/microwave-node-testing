# Microwave node agent — Windows setup (same idea as setup.sh).
# Requires: Node.js 18+ (npm on PATH), PowerShell 5.1+.
#
# Remote one-liner (downloads into .\microwave-node under current directory):
#   $env:MICROWAVE_NODE_REPO_RAW='https://raw.githubusercontent.com/robot-time/microwave-node-testing/main'
#   irm "$($env:MICROWAVE_NODE_REPO_RAW)/setup.ps1" | iex
#
# From a clone:  .\setup.ps1

$ErrorActionPreference = 'Stop'

$RepoRaw = if ($env:MICROWAVE_NODE_REPO_RAW) { $env:MICROWAVE_NODE_REPO_RAW.TrimEnd('/') } else { '' }

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
  if (-not $RepoRaw) {
    Write-Error @"
Missing microwave-node.js. Either:
  Set `$env:MICROWAVE_NODE_REPO_RAW to the GitHub raw base, then re-run, or
  Save microwave-node.js into this folder from the repo (raw file), then re-run.
"@
  }
  Write-Host '-> download microwave-node.js'
  $uri = "$RepoRaw/microwave-node.js"
  Invoke-WebRequest -Uri $uri -OutFile 'microwave-node.js' -UseBasicParsing
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
  Write-Host '  Edit .env — set NODE_DEVICE_TOKEN from the server admin.'
}

Write-Host ''
Write-Host 'Done.'
Write-Host '  1. Edit .env'
Write-Host '  2. npm run register -- --main https://SERVER --url https://YOU:3847 --name my-gpu --token SECRET --models gemma3:4b'
Write-Host '  3. npm start'
