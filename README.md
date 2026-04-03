# Microwave node agent

**Mac / Linux**

```bash
curl -fsSL https://raw.githubusercontent.com/robot-time/microwave-node-testing/main/setup.sh | bash
```

**Windows** (PowerShell)

```powershell
irm https://raw.githubusercontent.com/robot-time/microwave-node-testing/main/setup.ps1 | iex
```

Then: `cd microwave-node` → edit `.env` → `npm run register -- --main https://SERVER --url https://YOUR_PUBLIC:3847 --name gpu --token SECRET --models gemma3:4b` → `npm start`. Needs Node.js 18+, npm, and Ollama.
