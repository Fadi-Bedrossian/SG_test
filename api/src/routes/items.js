const express = require('express');

// Factory so tests can inject a fake db.
module.exports = function itemsRouter(db) {
  const router = express.Router();

  router.get('/', async (_req, res, next) => {
    try {
      const { rows } = await db.query(
        'SELECT id, title, done, created_at FROM items ORDER BY created_at DESC LIMIT 100'
      );
      res.json(rows);
    } catch (err) {
      next(err);
    }
  });

  router.post('/', async (req, res, next) => {
    const title = typeof req.body?.title === 'string' ? req.body.title.trim() : '';
    if (!title || title.length > 200) {
      return res.status(400).json({ error: 'title is required (1-200 chars)' });
    }
    try {
      const { rows } = await db.query(
        'INSERT INTO items (title) VALUES ($1) RETURNING id, title, done, created_at',
        [title]
      );
      res.status(201).json(rows[0]);
    } catch (err) {
      next(err);
    }
  });

  router.patch('/:id', async (req, res, next) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'invalid id' });
    }
    if (typeof req.body?.done !== 'boolean') {
      return res.status(400).json({ error: 'done must be a boolean' });
    }
    try {
      const { rows } = await db.query(
        'UPDATE items SET done = $1 WHERE id = $2 RETURNING id, title, done, created_at',
        [req.body.done, id]
      );
      if (rows.length === 0) return res.status(404).json({ error: 'not found' });
      res.json(rows[0]);
    } catch (err) {
      next(err);
    }
  });

  router.delete('/:id', async (req, res, next) => {
    const id = Number(req.params.id);
    if (!Number.isInteger(id) || id <= 0) {
      return res.status(400).json({ error: 'invalid id' });
    }
    try {
      const { rowCount } = await db.query('DELETE FROM items WHERE id = $1', [id]);
      if (rowCount === 0) return res.status(404).json({ error: 'not found' });
      res.status(204).end();
    } catch (err) {
      next(err);
    }
  });

  return router;
};
