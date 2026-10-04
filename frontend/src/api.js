// All calls are relative: nginx (in the container) or the Vite dev proxy forwards /api to the Node API.
async function request(path, options = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...options,
  });
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `Request failed (${res.status})`);
  }
  return res.status === 204 ? null : res.json();
}

export const api = {
  list: () => request('/items'),
  create: (title) => request('/items', { method: 'POST', body: JSON.stringify({ title }) }),
  toggle: (id, done) => request(`/items/${id}`, { method: 'PATCH', body: JSON.stringify({ done }) }),
  remove: (id) => request(`/items/${id}`, { method: 'DELETE' }),
};
