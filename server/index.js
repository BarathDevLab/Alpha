'use strict';

require('dotenv').config();

const express = require('express');
const rateLimit = require('express-rate-limit');
const { v4: uuidv4 } = require('uuid');
const fs = require('fs');
const path = require('path');

// ── Firebase Admin (FCM) ──────────────────────────────────────────────────────
let firebaseAdmin = null;
const SA_PATH = process.env.FCM_SERVICE_ACCOUNT_PATH;
if (SA_PATH && fs.existsSync(SA_PATH)) {
  try {
    const admin = require('firebase-admin');
    const serviceAccount = require(path.resolve(SA_PATH));
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
    firebaseAdmin = admin;
    console.log('Firebase Admin initialised ✓');
  } catch (e) {
    console.warn('Firebase Admin init failed (FCM push disabled):', e.message);
  }
} else {
  console.warn('FCM_SERVICE_ACCOUNT_PATH not set — push notifications disabled');
}

// ── In-memory stores (reset on restart; for a hackathon, this is fine) ────────
const events = [];           // AlertEvent objects, max 500
const pairCodes = new Map(); // code → { ownerToken, contactToken, ts }
const sseClients = new Set();// Set<Response>

// ── Express setup ─────────────────────────────────────────────────────────────
const app = express();
app.use(express.json());

// Allow dashboard (localhost:5173) during dev
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  next();
});

// Rate limit: 60 req/min per IP
app.use(rateLimit({ windowMs: 60_000, max: 60, standardHeaders: true }));

// ── POST /events ──────────────────────────────────────────────────────────────
// Accepts: { id, type, label, level, confidence, db?, geohash?, ts }
// Validates, stores, broadcasts SSE, sends FCM to contact if paired.
app.post('/events', (req, res) => {
  const { id, type, label, level, confidence, ts } = req.body;

  if (!id || !type || !label || level == null || confidence == null || !ts) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  if (!['sound', 'mind'].includes(type)) {
    return res.status(400).json({ error: 'type must be sound or mind' });
  }
  if (![1, 2, 3].includes(Number(level))) {
    return res.status(400).json({ error: 'level must be 1, 2 or 3' });
  }

  const event = {
    id,
    type,
    label,
    level: Number(level),
    confidence: Number(confidence),
    db: req.body.db ?? null,
    geohash: req.body.geohash ?? null,
    ts,
    receivedAt: new Date().toISOString(),
  };

  // No raw audio or text stored — only the structured metadata above.
  events.unshift(event);
  if (events.length > 500) events.pop();

  // Broadcast to all SSE clients
  const ssePayload = `data: ${JSON.stringify(event)}\n\n`;
  sseClients.forEach(client => {
    try { client.write(ssePayload); } catch (_) { sseClients.delete(client); }
  });

  // FCM push to contact(s) — level only
  if (firebaseAdmin && level >= 2) {
    sendFcmToContacts(level).catch(e => console.error('FCM send error:', e.message));
  }

  res.status(201).json({ ok: true, id: event.id });
});

// ── GET /events ───────────────────────────────────────────────────────────────
// Returns last 200 events as JSON array (newest first).
app.get('/events', (_req, res) => {
  res.json(events.slice(0, 200));
});

// ── GET /events/stream ────────────────────────────────────────────────────────
// Server-Sent Events. On connect: sends last 50 events, then stays open.
app.get('/events/stream', (req, res) => {
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  // Send recent history on connect
  const recent = events.slice(0, 50).reverse(); // oldest first
  for (const e of recent) {
    res.write(`data: ${JSON.stringify(e)}\n\n`);
  }

  sseClients.add(res);

  // Heartbeat every 20 s to keep connection alive through proxies
  const heartbeat = setInterval(() => {
    try { res.write(': heartbeat\n\n'); } catch (_) { clearInterval(heartbeat); }
  }, 20_000);

  req.on('close', () => {
    clearInterval(heartbeat);
    sseClients.delete(res);
  });
});

// ── POST /pair ────────────────────────────────────────────────────────────────
// Owner registers their FCM token, gets a 6-digit code to share.
app.post('/pair', (req, res) => {
  const { ownerToken } = req.body;
  if (!ownerToken) return res.status(400).json({ error: 'ownerToken required' });

  const code = Math.floor(100_000 + Math.random() * 900_000).toString();
  pairCodes.set(code, { ownerToken, contactToken: null, ts: new Date().toISOString() });

  // Expire code after 10 minutes
  setTimeout(() => pairCodes.delete(code), 10 * 60 * 1000);

  res.json({ code });
});

// ── POST /pair/confirm ────────────────────────────────────────────────────────
// Contact enters the code and registers their FCM token.
app.post('/pair/confirm', (req, res) => {
  const { code, contactToken } = req.body;
  if (!code || !contactToken) return res.status(400).json({ error: 'code and contactToken required' });

  const record = pairCodes.get(code);
  if (!record) return res.status(404).json({ error: 'Invalid or expired code' });

  record.contactToken = contactToken;
  res.json({ ok: true });
});

// ── DELETE /pair/:code ────────────────────────────────────────────────────────
// Owner revokes consent. Contact gets no more alerts.
app.delete('/pair/:code', (req, res) => {
  const deleted = pairCodes.delete(req.params.code);
  res.json({ ok: deleted });
});

// ── GET /pair ─────────────────────────────────────────────────────────────────
// Returns list of active pair codes (for the React Care tab).
app.get('/pair', (_req, res) => {
  const active = [];
  pairCodes.forEach((v, k) => active.push({ code: k, ts: v.ts, paired: !!v.contactToken }));
  res.json(active);
});

// ── Serve React dashboard build ───────────────────────────────────────────────
const DASHBOARD_DIST = path.join(__dirname, 'dashboard', 'dist');
if (fs.existsSync(DASHBOARD_DIST)) {
  app.use(express.static(DASHBOARD_DIST));
  app.get('/', (_req, res) => res.sendFile(path.join(DASHBOARD_DIST, 'index.html')));
}

// ── FCM helper ────────────────────────────────────────────────────────────────
async function sendFcmToContacts(level) {
  const contactTokens = [];
  pairCodes.forEach(record => {
    if (record.contactToken) contactTokens.push(record.contactToken);
  });
  if (contactTokens.length === 0) return;

  const messaging = firebaseAdmin.messaging();
  for (const token of contactTokens) {
    await messaging.send({
      token,
      notification: {
        title: 'SafeSense',
        body: level === 3 ? 'Check in on your contact — they may need support.' : 'Wellbeing check-in requested.',
      },
      data: { level: String(level) },   // level only — no text, no audio
      android: { priority: level === 3 ? 'high' : 'normal' },
    });
  }
  console.log(`FCM sent to ${contactTokens.length} contact(s) — level ${level}`);
}

// ── Start ─────────────────────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`SafeSense backend listening on :${PORT}`));
