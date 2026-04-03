# Microwave node agent

One JavaScript file (`microwave-node.js`) + `setup.sh`: relay local **Ollama** to a main Microwave server.

## Publishing to GitHub (you)

1. On [github.com/new](https://github.com/new), create a repository (e.g. `microwave-node`). **Do not** add a README if you will push an existing folder (avoids merge noise).

2. On your machine, from the folder that should become the repo root (the `node-agent` directory, or a copy of it):

```bash
cd /path/to/node-agent
git init
git add microwave-node.js setup.sh package.json package-lock.json README.md .env.example .gitignore
git commit -m "Initial microwave node agent"
git branch -M main
git remote add origin https://github.com/YOU/microwave-node.git
git push -u origin main
```

3. **Never commit** `.env` or `data/` (they are in `.gitignore`). Contributors create `.env` via `./setup.sh`.

4. Tell contributors your **raw base URL** (replace `YOU`, `microwave-node`, and `main` if your default branch differs):

`https://raw.githubusercontent.com/YOU/microwave-node/main`

5. In this README, search/replace placeholder `YOU/microwave-node` with your real `user/repo` so clone and curl examples work.

---

## Fastest: clone and setup

```bash
git clone https://github.com/YOU/microwave-node.git && cd microwave-node && chmod +x setup.sh && ./setup.sh
```

(`npm run setup` runs the same script.)

## Or: download only `setup.sh` + curl the agent file

1. Put `setup.sh` on GitHub (this repo).
2. Anyone can run (replace `YOU/REPO` and branch):

```bash
export MICROWAVE_NODE_REPO_RAW='https://raw.githubusercontent.com/YOU/REPO/main'
curl -fsSL "$MICROWAVE_NODE_REPO_RAW/setup.sh" | bash
```

That downloads `microwave-node.js`, writes `package.json`, runs `npm install`, creates `.env`.

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

## Commands (same as `npm run …`)

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
# microwave-node-testing
