#!/usr/bin/env bash
# Microwave node agent — installs agent + optional Ollama + model pulls.
set -uo pipefail

DEFAULT_REPO_RAW='https://raw.githubusercontent.com/robot-time/microwave-node-testing/main'
REPO_RAW="${MICROWAVE_NODE_REPO_RAW:-$DEFAULT_REPO_RAW}"
REPO_RAW="${REPO_RAW%/}"

# Models offered in the menu (Ollama library names)
PRESET_MODELS=(
  gemma3:4b
  phi3:mini
  llama3.2:3b
  llama3.1:8b
  qwen2.5:7b
  phi4-mini
)

banner() {
  cat << 'BANNER' >&2

  ╔════════════════════════════════════════╗
  ║   Microwave — node agent setup         ║
  ╚════════════════════════════════════════╝

BANNER
}

read_tty() {
  if [[ -r /dev/tty ]]; then
    read -r "$@" < /dev/tty
  else
    read -r "$@"
  fi
}

banner

if ! command -v node >/dev/null 2>&1 || ! command -v npm >/dev/null 2>&1; then
  echo "Install Node.js 18+ (includes npm) from https://nodejs.org/ then run this again." >&2
  exit 1
fi

# Install directory
if [[ -n "${MICROWAVE_NODE_DIR:-}" ]]; then
  ROOT="$(mkdir -p "${MICROWAVE_NODE_DIR}" && cd "${MICROWAVE_NODE_DIR}" && pwd)"
else
  _src="${BASH_SOURCE[0]:-}"
  if [[ -n "${_src}" && "${_src}" != "-" && "${_src}" != "/dev/stdin" && "${_src}" != */fd/* ]]; then
    ROOT="$(cd "$(dirname "${_src}")" && pwd)"
  else
    ROOT="$(pwd)/microwave-node"
    mkdir -p "${ROOT}"
  fi
fi
cd "${ROOT}"
echo "→ install dir: ${ROOT}" >&2

if [[ ! -f microwave-node.js ]]; then
  echo "→ download microwave-node.js" >&2
  curl -fsSL "${REPO_RAW}/microwave-node.js" -o microwave-node.js || exit $?
fi

if [[ ! -f package.json ]]; then
  echo "→ write package.json" >&2
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

echo "→ npm install" >&2
npm install || exit $?

if [[ ! -f .env ]]; then
  if [[ -f .env.example ]]; then
    cp .env.example .env
    echo "→ created .env from .env.example" >&2
  else
    cat > .env << 'ENVEOF'
PORT=3847
OLLAMA_URL=http://127.0.0.1:11434
NODE_DEVICE_TOKEN=
OLLAMA_NUM_PREDICT=1024
OLLAMA_KEEP_ALIVE=30m
ENVEOF
    echo "→ created .env (defaults)" >&2
  fi
fi

# --- Ollama ---
echo "" >&2
if command -v ollama >/dev/null 2>&1; then
  echo "→ Ollama on PATH: $(ollama --version 2>/dev/null || echo ok)" >&2
else
  echo "Ollama not found on PATH." >&2
  read_tty -r -p "Install Ollama with the official script (https://ollama.com/install.sh)? [y/N] " yn
  if [[ "${yn:-}" =~ ^[Yy]$ ]]; then
    curl -fsSL https://ollama.com/install.sh | sh
    hash -r 2>/dev/null || true
  fi
  if ! command -v ollama >/dev/null 2>&1; then
    echo "→ Ollama still not on PATH — install from https://ollama.com/download , open a new terminal, re-run setup to pull models." >&2
  else
    echo "→ Ollama ready: $(ollama --version 2>/dev/null || true)" >&2
  fi
fi

# --- Model pulls ---
if command -v ollama >/dev/null 2>&1; then
  echo "" >&2
  echo "Which models should Ollama download? (large files — pick what you need)" >&2
  i=1
  for m in "${PRESET_MODELS[@]}"; do
    echo "  $i) $m" >&2
    i=$((i + 1))
  done
  echo "  a) All of the above" >&2
  echo "  c) Enter a custom Ollama model name" >&2
  echo "  0) Skip pulls for now" >&2
  read_tty -r -p "> " choice
  choice="${choice//,/ }"
  to_pull=()
  if [[ "${choice:-}" =~ ^[Aa]$ ]]; then
    to_pull=("${PRESET_MODELS[@]}")
  elif [[ -z "${choice// }" || "$choice" == "0" ]]; then
    :
  elif [[ "$choice" == "c" || "$choice" == "C" ]]; then
    read_tty -r -p "Model name (e.g. gemma3:4b): " custom
    [[ -n "${custom:-}" ]] && to_pull+=("$custom")
  else
    for n in $choice; do
      if [[ "$n" =~ ^[0-9]+$ ]]; then
        idx=$((n - 1))
        if (( idx >= 0 && idx < ${#PRESET_MODELS[@]} )); then
          to_pull+=("${PRESET_MODELS[$idx]}")
        fi
      fi
    done
  fi
  for m in "${to_pull[@]}"; do
    echo "→ ollama pull $m" >&2
    ollama pull "$m" || echo "  (failed: $m — check spelling / disk / network)" >&2
  done
fi

echo "" >&2
echo "╔════════════════════════════════════════╗" >&2
echo "║  Setup finished                        ║" >&2
echo "╚════════════════════════════════════════╝" >&2
echo "  In this folder: edit .env, then register and start the agent:" >&2
echo "    npm run register -- --main https://SERVER --url https://YOU:PORT --name gpu --token SECRET --models gemma3:4b" >&2
echo "    npm start" >&2
