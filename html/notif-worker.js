// NeonChat Background Notification Worker
// Rulează în fundal, neafectat de throttling-ul Chrome

let lastCount = -1;

async function checkUnread() {
  try {
    const r = await fetch('/api.php?a=unread', { credentials: 'include' });
    if (!r.ok) return;
    const d = await r.json();
    const n = d.n || 0;
    if (lastCount >= 0 && n > lastCount) {
      self.postMessage({ type: 'notify', diff: n - lastCount, total: n });
    }
    lastCount = n;
  } catch (e) {
    // silent
  }
}

// Verifică la fiecare 5 secunde
setInterval(checkUnread, 5000);
checkUnread();
