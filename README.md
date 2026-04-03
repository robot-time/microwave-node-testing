# Microwave node agent

One JavaScript file (`microwave-node.js`) + `setup.sh`: relay local **Ollama** to a main Microwave server.

**This repo should contain:** `microwave-node.js`, `setup.sh`, `setup.ps1` (Windows), `package.json`, `package-lock.json`, `.env.example`, `.gitignore`, and this `README.md`.  
If GitHub only shows a README, the code was never pushed — run **Push the full repo** below on your machine.

---

## Push the full repo (maintainer)

From the folder that has `microwave-node.js` (your local `node-agent` copy):

```bash
cd /path/to/your/node-agent

git pull origin main --rebase   # if GitHub already has a commit (e.g. README only)
git add microwave-node.js setup.sh setup.ps1 package.json package-lock.json README.md .env.example .gitignore
git status   # should NOT list .env or node_modules
git commit -m "Add microwave-node agent code and setup"
git push origin main
```

If `git pull` reports a conflict in `README.md`, open it, keep the sections you want, then `git add README.md && git rebase --continue`.

---

## Publishing to GitHub (new repo, for reference)

1. On [github.com/new](https://github.com/new), create a repository. Skip the “add README” option if you will push an existing folder.

2. First push:

```bash
cd /path/to/node-agent
git init
git add microwave-node.js setup.sh setup.ps1 package.json package-lock.json README.md .env.example .gitignore
git commit -m "Initial microwave node agent"
git branch -M main
git remote add origin https://github.com/robot-time/microwave-node-testing.git
git push -u origin main
```

3. **Never commit** `.env` or `data/` (they are in `.gitignore`).

---

## Setup (pick one)

### macOS / Linux — no Git (`curl` + `bash`)

Needs **Node.js 18+**, **npm**, **bash**, and **curl**.

From any directory, one line:

```bash
MICROWAVE_NODE_REPO_RAW='https://raw.githubusercontent.com/robot-time/microwave-node-testing/main' \
  curl -fsSL "$MICROWAVE_NODE_REPO_RAW/setup.sh" | bash
```

That downloads `microwave-node.js`, creates `./microwave-node/` under your **current** folder, runs `npm install`, and writes `.env`.

- **Custom folder:** set `MICROWAVE_NODE_DIR` before the same command, e.g.  
  `MICROWAVE_NODE_DIR="$HOME/microwave-node" MICROWAVE_NODE_REPO_RAW='https://raw.githubusercontent.com/robot-time/microwave-node-testing/main' curl -fsSL "$MICROWAVE_NODE_REPO_RAW/setup.sh" | bash`

- **No curl:** open  
  [microwave-node.js (raw)](https://raw.githubusercontent.com/robot-time/microwave-node-testing/main/microwave-node.js)  
  and [setup.sh (raw)](https://raw.githubusercontent.com/robot-time/microwave-node-testing/main/setup.sh)  
  in a browser → Save As → put both in the same folder → `chmod +x setup.sh` → `./setup.sh` (with `MICROWAVE_NODE_REPO_RAW` **unset** so it does not re-download).

### Windows — no Git (PowerShell)

Install **[Node.js LTS](https://nodejs.org/)** (includes **npm**). Then open **PowerShell** (not required to install Git).

**One-liner** (installs into `.\microwave-node` under your current folder):

```powershell
$env:MICROWAVE_NODE_REPO_RAW = 'https://raw.githubusercontent.com/robot-time/microwave-node-testing/main'
irm "$($env:MICROWAVE_NODE_REPO_RAW)/setup.ps1" | iex
```

(`irm` = `Invoke-WebRequest`, `iex` = `Invoke-Expression`.)

- **Custom folder:** first set `$env:MICROWAVE_NODE_DIR = 'C:\path\to\microwave-node'`, then run the two lines above.
- **Execution policy** errors: run once (current user only):  
  `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`
- **Manual download:** save [microwave-node.js](https://raw.githubusercontent.com/robot-time/microwave-node-testing/main/microwave-node.js) and [setup.ps1](https://raw.githubusercontent.com/robot-time/microwave-node-testing/main/setup.ps1) into the same folder → in that folder run `.\setup.ps1` with **`MICROWAVE_NODE_REPO_RAW` unset** (so it does not re-download).
- **WSL** or **Git Bash** on Windows: you can use the **macOS/Linux** `curl | bash` method instead.

After setup, use **Command Prompt**, **PowerShell**, or **Git Bash** in that folder — `npm run register` and `npm start` work the same.

### With Git

```bash
git clone https://github.com/robot-time/microwave-node-testing.git && cd microwave-node-testing && chmod +x setup.sh && ./setup.sh
```

On **Windows** (clone in PowerShell): `cd microwave-node-testing` then `.\setup.ps1` (or use Git Bash and `./setup.sh`).

(`npm run setup` runs `./setup.sh`; on Windows without bash, use `.\setup.ps1` instead.)

Raw base (for scripts): `https://raw.githubusercontent.com/robot-time/microwave-node-testing/main`

## After setup

If you used **curl** / **PowerShell remote setup** into the default path: `cd microwave-node` (or your `MICROWAVE_NODE_DIR`) before the steps below.

1. Edit **`.env`** — `NODE_DEVICE_TOKEN` from the admin.
2. Register once:

```bash
npm run register -- \
  --main https://their-server.example.com \
  --url https://your-public-host:3847 \
  --name your-gpu \
  --token YOUR_SHARED_SECRET \
  --models gemma3:4b
```

3. Run: **`npm start`**

## Commands

| Command | Purpose |
|--------|---------|
| `node microwave-node.js` | Start HTTP relay |
| `node microwave-node.js register --main … --url …` | Register with main server |
| `node microwave-node.js heartbeat` | Keep node alive (cron every ~5m) |

## Requirements

- Node.js 18+
- Ollama on this machine
- Public URL to this agent’s port

## API

- `GET /health`
- `GET /api/node/health` (optional `x-node-token`)
- `POST /api/node/run` — `{ modelId, messages }`
- `POST /api/node/stream` — SSE tokens
