#!/usr/bin/env bash
# Microwave node agent — one-command setup (npm deps + .env).
# From a full clone: ./setup.sh
# Remote install: set MICROWAVE_NODE_REPO_RAW to your GitHub raw base, then:
#   curl -fsSL https://raw.githubusercontent.com/YOU/REPO/main/setup.sh | bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-.}")" && pwd)"
cd "$ROOT"

REPO_RAW="${MICROWAVE_NODE_REPO_RAW:-}"

if [[ ! -f microwave-node.js ]] && [[ -n "$REPO_RAW" ]]; then
  echo "→ curl microwave-node.js"
  curl -fsSL "${REPO_RAW%/}/microwave-node.js" -o microwave-node.js
fi

if [[ ! -f microwave-node.js ]]; then
  echo "Missing microwave-node.js." >&2
  echo "  Clone this repo and run ./setup.sh again, or:" >&2
  echo "  export MICROWAVE_NODE_REPO_RAW='https://raw.githubusercontent.com/YOU/REPO/main'" >&2
  echo "  curl -fsSL \"\$MICROWAVE_NODE_REPO_RAW/setup.sh\" | bash" >&2
  exit 1
fi

if [[ ! -f package.json ]]; then
  echo "→ write package.json"
  cat > package.json << 'PKGEOF'
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
PKGEOF
fi

echo "→ npm install"
npm install

if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    echo "→ created .env from .env.example"
  else
    cat > .env << 'ENVEOF'
PORT=3847
OLLAMA_URL=http://127.0.0.1:11434
NODE_DEVICE_TOKEN=
OLLAMA_NUM_PREDICT=1024
OLLAMA_KEEP_ALIVE=30m
ENVEOF
    echo "→ created .env (defaults)"
  fi
  echo "  Edit .env — set NODE_DEVICE_TOKEN from the server admin."
fi

echo ""
echo "Done."
echo "  1. Edit .env"
echo "  2. npm run register -- --main https://SERVER --url https://YOU:3847 --name my-gpu --token SECRET --models gemma3:4b"
echo "  3. npm start"
