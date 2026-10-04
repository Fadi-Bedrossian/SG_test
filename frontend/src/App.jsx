import { useEffect, useState } from 'react';
import { api } from './api.js';

export default function App() {
  const [items, setItems] = useState([]);
  const [title, setTitle] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api
      .list()
      .then(setItems)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  async function handleAdd(e) {
    e.preventDefault();
    if (!title.trim()) return;
    try {
      const item = await api.create(title.trim());
      setItems((prev) => [item, ...prev]);
      setTitle('');
      setError('');
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleToggle(item) {
    try {
      const updated = await api.toggle(item.id, !item.done);
      setItems((prev) => prev.map((i) => (i.id === item.id ? updated : i)));
    } catch (err) {
      setError(err.message);
    }
  }

  async function handleDelete(id) {
    try {
      await api.remove(id);
      setItems((prev) => prev.filter((i) => i.id !== id));
    } catch (err) {
      setError(err.message);
    }
  }

  return (
    <main className="container">
      <h1>Items</h1>
      <form onSubmit={handleAdd} className="add-form">
        <label htmlFor="title" className="sr-only">New item</label>
        <input
          id="title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          placeholder="What needs doing?"
          maxLength={200}
        />
        <button type="submit">Add</button>
      </form>

      {error && <p role="alert" className="error">{error}</p>}
      {loading ? (
        <p>Loading…</p>
      ) : items.length === 0 ? (
        <p className="empty">Nothing here yet.</p>
      ) : (
        <ul className="items">
          {items.map((item) => (
            <li key={item.id} className={item.done ? 'done' : ''}>
              <label>
                <input type="checkbox" checked={item.done} onChange={() => handleToggle(item)} />
                <span>{item.title}</span>
              </label>
              <button aria-label={`Delete ${item.title}`} onClick={() => handleDelete(item.id)}>
                ×
              </button>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}
