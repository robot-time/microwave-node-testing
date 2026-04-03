#!/usr/bin/env node
/**
 * Microwave node agent — single file: HTTP relay to Ollama + register + heartbeat.
 * Run: node microwave-node.js | node microwave-node.js register ... | node microwave-node.js heartbeat
 */
require('dotenv').config();

const fs = require('fs');
const path = require('path');
const os = require('os');
const express = require('express');

const PORT = Number(process.env.PORT) || 3847;
const OLLAMA_URL = String(process.env.OLLAMA_URL || 'http://127.0.0.1:11434').replace(/\/$/, '');
const OLLAMA_CHAT = `${OLLAMA_URL}/api/chat`;
const NODE_DEVICE_TOKEN = process.env.NODE_DEVICE_TOKEN || '';
const OLLAMA_NUM_PREDICT = Number.isFinite(Number(process.env.OLLAMA_NUM_PREDICT))
  ? Number(process.env.OLLAMA_NUM_PREDICT)
  : 1024;
const OLLAMA_KEEP_ALIVE = (() => {
  const raw = process.env.OLLAMA_KEEP_ALIVE;
  if (raw === undefined || raw === '') return '30m';
  const t = String(raw).trim();
  if (t === '-1') return -1;
  const n = Number(t);
  if (Number.isFinite(n) && t === String(n)) return n;
  return t;
})();

const ROOT = path.dirname(__filename);
const DATA_DIR = path.join(ROOT, 'data');
const CONFIG_PATH = path.join(DATA_DIR, 'node-config.json');

function arg(name, fallback = '') {
  const idx = process.argv.indexOf(`--${name}`);
  if (idx >= 0 && process.argv[idx + 1]) return process.argv[idx + 1];
  return fallback;
}

// ── register ───────────────────────────────────────────────────────────────

async function cmdRegister() {
  const mainServer = arg('main');
  const publicUrl = arg('url');
  const name = arg('name') || `node-${os.hostname()}`;
  const token = arg('token') || process.env.NODE_DEVICE_TOKEN || '';
  const modelsArg = arg('models', '');
  const models = modelsArg ? modelsArg.split(',').map((x) => x.trim()).filter(Boolean) : [];

  if (!mainServer || !publicUrl) {
    console.log(
      'Usage: node microwave-node.js register --main https://SERVER --url https://YOUR_PUBLIC:3847 [--name my-gpu] [--token SECRET] [--models gemma3:4b]'
    );
    process.exit(1);
  }

  fs.mkdirSync(DATA_DIR, { recursive: true });

  const cfg = {
    name,
    publicUrl: String(publicUrl).replace(/\/$/, ''),
    mainServer: String(mainServer).replace(/\/$/, ''),
    models,
    token,
    installedAt: new Date().toISOString(),
  };
  fs.writeFileSync(CONFIG_PATH, JSON.stringify(cfg, null, 2), 'utf8');

  const res = await fetch(`${cfg.mainServer}/api/nodes/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, url: cfg.publicUrl, models, token }),
  });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Register failed (${res.status}): ${text}`);
  }

  console.log('Registered with main server.');
  console.log(`Saved ${CONFIG_PATH}`);
  console.log('Run: npm start  (or: node microwave-node.js)');
  console.log('Optional: cron → node microwave-node.js heartbeat');
}

// ── heartbeat ─────────────────────────────────────────────────────────────────

async function cmdHeartbeat() {
  if (!fs.existsSync(CONFIG_PATH)) {
    throw new Error(`Missing ${CONFIG_PATH}. Run: node microwave-node.js register --main ... --url ...`);
  }
  const cfg = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
  const token = process.env.NODE_DEVICE_TOKEN || cfg.token || '';
  const res = await fetch(`${String(cfg.mainServer).replace(/\/$/, '')}/api/nodes/heartbeat`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ url: cfg.publicUrl, token }),
  });
  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`Heartbeat failed (${res.status}): ${text}`);
  }
  console.log('Heartbeat ok.');
}

// ── HTTP server (default) ─────────────────────────────────────────────────────

const startedAt = Date.now();

function requireNodeToken(req, res, next) {
  if (!NODE_DEVICE_TOKEN) return next();
  const h = req.headers['x-node-token'];
  if (h !== NODE_DEVICE_TOKEN) {
    return res.status(401).json({ ok: false, error: 'Invalid node token' });
  }
  next();
}

async function ollamaChat(body) {
  const res = await fetch(OLLAMA_CHAT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ keep_alive: OLLAMA_KEEP_ALIVE, ...body }),
  });
  return res;
}

function startServer() {
  const app = express();
  app.use(express.json({ limit: '2mb' }));

  app.get('/health', (_req, res) => {
    res.json({ ok: true, service: 'microwave-node-agent', uptimeSec: Math.floor((Date.now() - startedAt) / 1000) });
  });

  app.get('/api/node/health', requireNodeToken, async (_req, res) => {
    const t0 = Date.now();
    try {
      const ctrl = new AbortController();
      const to = setTimeout(() => ctrl.abort(), 8000);
      const r = await fetch(`${OLLAMA_URL}/api/tags`, { signal: ctrl.signal });
      clearTimeout(to);
      const latencyMs = Date.now() - t0;
      if (!r.ok) {
        return res.json({
          ok: true,
          agent: 'microwave-node-agent',
          ollama: { ok: false, latencyMs, error: `HTTP ${r.status}` },
          uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
        });
      }
      const j = await r.json();
      const models = (j.models || []).map((m) => m.name).filter(Boolean);
      return res.json({
        ok: true,
        agent: 'microwave-node-agent',
        ollama: { ok: true, latencyMs, modelCount: models.length, models: models.slice(0, 100) },
        uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
      });
    } catch (e) {
      return res.json({
        ok: true,
        agent: 'microwave-node-agent',
        ollama: {
          ok: false,
          error: e.name === 'AbortError' ? 'Ollama tags timeout' : e.message || String(e),
        },
        uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
      });
    }
  });

  app.post('/api/node/run', requireNodeToken, async (req, res) => {
    const { modelId, messages } = req.body || {};
    if (!modelId || !Array.isArray(messages)) {
      return res.status(400).json({ ok: false, error: 'modelId and messages are required' });
    }
    try {
      const ores = await ollamaChat({
        model: modelId,
        messages,
        stream: false,
        options: { num_predict: OLLAMA_NUM_PREDICT },
      });
      const json = await ores.json();
      const content = json?.message?.content;
      if (!ores.ok) {
        return res.status(502).json({ ok: false, error: json?.error || `Ollama HTTP ${ores.status}` });
      }
      if (typeof content !== 'string') {
        return res.status(502).json({ ok: false, error: 'Unexpected Ollama response' });
      }
      return res.json({ ok: true, text: content });
    } catch (err) {
      return res.status(500).json({ ok: false, error: err.message || String(err) });
    }
  });

  app.post('/api/node/stream', requireNodeToken, async (req, res) => {
    const { modelId, messages } = req.body || {};
    if (!modelId || !Array.isArray(messages)) {
      return res.status(400).json({ ok: false, error: 'modelId and messages are required' });
    }
    res.setHeader('Content-Type', 'text/event-stream; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-transform');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('X-Accel-Buffering', 'no');
    if (typeof res.flushHeaders === 'function') res.flushHeaders();

    const send = (event, data) => {
      if (res.writableEnded || res.finished) return;
      res.write(`event: ${event}\n`);
      res.write(`data: ${JSON.stringify(data)}\n\n`);
    };

    try {
      const ores = await ollamaChat({
        model: modelId,
        messages,
        stream: true,
        options: { num_predict: OLLAMA_NUM_PREDICT },
      });
      if (!ores.ok || !ores.body) {
        const t = await ores.text().catch(() => '');
        send('error', { error: `Ollama ${ores.status}: ${t.slice(0, 200)}` });
        res.end();
        return;
      }
      const reader = ores.body.getReader();
      const decoder = new TextDecoder();
      let buffer = '';
      outerLoop: while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buffer += decoder.decode(value, { stream: true });
        const lines = buffer.split('\n');
        buffer = lines.pop() || '';
        for (const rawLine of lines) {
          const line = rawLine.trim();
          if (!line) continue;
          try {
            const json = JSON.parse(line);
            const msg = json.message || {};
            const thinkChunk = typeof msg.thinking === 'string' ? msg.thinking : '';
            const contentChunk = typeof msg.content === 'string' ? msg.content : '';
            if (thinkChunk.length > 0) send('think-token', { delta: thinkChunk });
            if (contentChunk.length > 0) send('token', { delta: contentChunk });
            if (json.done) break outerLoop;
          } catch {
            /* partial line */
          }
        }
      }
      const tail = buffer.trim();
      if (tail) {
        try {
          const json = JSON.parse(tail);
          const msg = json.message || {};
          const thinkChunk = typeof msg.thinking === 'string' ? msg.thinking : '';
          const contentChunk = typeof msg.content === 'string' ? msg.content : '';
          if (thinkChunk.length > 0) send('think-token', { delta: thinkChunk });
          if (contentChunk.length > 0) send('token', { delta: contentChunk });
        } catch {
          /* ignore */
        }
      }
      send('done', { ok: true });
    } catch (err) {
      send('error', { error: err.message || String(err) });
    } finally {
      res.end();
    }
  });

  app.listen(PORT, () => {
    console.log(`[microwave-node-agent] listening on :${PORT} → Ollama ${OLLAMA_URL}`);
  });
}

// ── CLI ──────────────────────────────────────────────────────────────────────

const sub = process.argv[2];
if (sub === 'register') {
  cmdRegister().catch((err) => {
    console.error('[register]', err.message || String(err));
    process.exit(1);
  });
} else if (sub === 'heartbeat') {
  cmdHeartbeat().catch((err) => {
    console.error('[heartbeat]', err.message || String(err));
    process.exit(1);
  });
} else if (sub && sub !== 'start' && sub.startsWith('-')) {
  console.error('Unknown option. Use: node microwave-node.js [register|heartbeat]');
  process.exit(1);
} else {
  startServer();
}
