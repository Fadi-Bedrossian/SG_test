// Runs against a real PostgreSQL (the CI job starts one as a service container).
const request = require('supertest');
const db = require('../../src/db');
const { migrate } = require('../../src/migrate');
const { createApp } = require('../../src/app');

const app = createApp({ db });

beforeAll(async () => {
  await migrate();
  await db.query('TRUNCATE items RESTART IDENTITY');
});

afterAll(async () => {
  await db.close();
});

test('full CRUD round-trip against PostgreSQL', async () => {
  const created = await request(app).post('/api/items').send({ title: 'integration' });
  expect(created.status).toBe(201);

  const list = await request(app).get('/api/items');
  expect(list.body.map((i) => i.title)).toContain('integration');

  const updated = await request(app).patch(`/api/items/${created.body.id}`).send({ done: true });
  expect(updated.body.done).toBe(true);

  const deleted = await request(app).delete(`/api/items/${created.body.id}`);
  expect(deleted.status).toBe(204);

  const ready = await request(app).get('/readyz');
  expect(ready.status).toBe(200);
});
