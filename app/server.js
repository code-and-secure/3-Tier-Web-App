const express = require('express');
const path = require('path');
const { listEntries, addEntry } = require('./db');

const app = express();
const port = process.env.PORT || 8080;

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validateEntry(body) {
  const name = String(body.name ?? '').trim();
  const email = String(body.email ?? '').trim();
  const message = String(body.message ?? '').trim();

  if (!name || name.length > 100) return null;
  if (!email || email.length > 200 || !EMAIL_RE.test(email)) return null;
  if (!message || message.length > 1000) return null;

  return { name, email, message };
}

app.get('/api/guestbook', async (req, res) => {
  try {
    const entries = await listEntries();
    res.json(entries);
  } catch (err) {
    console.error('Failed to list entries', err);
    res.status(500).json({ error: 'Failed to load entries' });
  }
});

app.post('/api/guestbook', async (req, res) => {
  const entry = validateEntry(req.body ?? {});
  if (!entry) {
    res.status(400).json({ error: 'Invalid name, email, or message' });
    return;
  }

  try {
    await addEntry(entry);
    res.status(201).json({ ok: true });
  } catch (err) {
    console.error('Failed to add entry', err);
    res.status(500).json({ error: 'Failed to save entry' });
  }
});

app.listen(port, () => {
  console.log(`Guestbook app listening on port ${port}`);
});
