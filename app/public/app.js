const form = document.getElementById('guestbook-form');
const status = document.getElementById('form-status');
const list = document.getElementById('entries-list');

function formatDate(value) {
  return new Date(value).toLocaleString();
}

function renderEntries(entries) {
  list.innerHTML = '';

  if (entries.length === 0) {
    const empty = document.createElement('li');
    empty.className = 'empty';
    empty.textContent = 'No entries yet — be the first to sign!';
    list.appendChild(empty);
    return;
  }

  for (const entry of entries) {
    const item = document.createElement('li');
    item.className = 'entry';

    const header = document.createElement('div');
    header.className = 'entry-header';

    const name = document.createElement('strong');
    name.textContent = entry.Name;

    const date = document.createElement('span');
    date.textContent = formatDate(entry.CreatedAt);

    header.appendChild(name);
    header.appendChild(date);

    const message = document.createElement('p');
    message.className = 'entry-message';
    message.textContent = entry.Message;

    item.appendChild(header);
    item.appendChild(message);
    list.appendChild(item);
  }
}

async function loadEntries() {
  try {
    const res = await fetch('/api/guestbook');
    if (!res.ok) throw new Error('Failed to load entries');
    renderEntries(await res.json());
  } catch (err) {
    list.innerHTML = '';
    const errorItem = document.createElement('li');
    errorItem.className = 'empty';
    errorItem.textContent = 'Could not load entries right now.';
    list.appendChild(errorItem);
  }
}

form.addEventListener('submit', async (event) => {
  event.preventDefault();
  status.textContent = '';
  status.className = 'status';

  const payload = {
    name: form.name.value,
    email: form.email.value,
    message: form.message.value,
  };

  try {
    const res = await fetch('/api/guestbook', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new Error(body.error || 'Submission failed');
    }

    form.reset();
    status.textContent = 'Thanks — your entry was saved!';
    status.className = 'status ok';
    await loadEntries();
  } catch (err) {
    status.textContent = err.message;
    status.className = 'status error';
  }
});

loadEntries();
