# Microwave node agent

One JavaScript file (`microwave-node.js`) + `setup.sh`: relay local **Ollama** to a main Microwave server.

**This repo should contain:** `microwave-node.js`, `setup.sh`, `package.json`, `package-lock.json`, `.env.example`, `.gitignore`, and this `README.md`.  
If GitHub only shows a README, the code was never pushed — run **Push the full repo** below on your machine.

---

## Push the full repo (maintainer)

From the folder that has `microwave-node.js` (your local `node-agent` copy):

```bash
cd /path/to/your/node-agent

git pull origin main --rebase   # if GitHub already has a commit (e.g. README only)
git add microwave-node.js setup.sh package.json package-lock.json README.md .env.example .gitignore
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
git add microwave-node.js setup.sh package.json package-lock.json README.md .env.example .gitignore
git commit -m "Initial microwave node agent"
git branch -M main
git remote add origin https://github.com/robot-time/microwave-node-testing.git
git push -u origin main
```

3. **Never commit** `.env` or `data/` (they are in `.gitignore`).

---

## Fastest: clone and setup

```bash
git clone https://github.com/robot-time/microwave-node-testing.git && cd microwave-node-testing && chmod +x setup.sh && ./setup.sh
```

(`npm run setup` runs the same script.)

## Or: curl `setup.sh` only (downloads `microwave-node.js`)

```bash
export MICROWAVE_NODE_REPO_RAW='https://raw.githubusercontent.com/robot-time/microwave-node-testing/main'
curl -fsSL "$MICROWAVE_NODE_REPO_RAW/setup.sh" | bash
```

Raw base (for reference): `https://raw.githubusercontent.com/robot-time/microwave-node-testing/main`

## After setup

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
