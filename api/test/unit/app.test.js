const request = require('supertest');
const { createApp } = require('../../src/app');

function fakeDb(impl) {
  return { query: jest.fn(impl) };
}

describe('health endpoints', () => {
  it('GET /healthz returns ok', async () => {
    const app = createApp({ db: fakeDb() });
    const res = await request(app).get('/healthz');
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ status: 'ok' });
  });

  it('GET /readyz returns 200 when db reachable', async () => {
    const app = createApp({ db: fakeDb(async () => ({ rows: [{ '?column?': 1 }] })) });
    const res = await request(app).get('/readyz');
    expect(res.status).toBe(200);
  });

  it('GET /readyz returns 503 when db down', async () => {
    const app = createApp({ db: fakeDb(async () => { throw new Error('ECONNREFUSED'); }) });
    const res = await request(app).get('/readyz');
    expect(res.status).toBe(503);
  });

  it('GET /metrics exposes prometheus metrics', async () => {
    const app = createApp({ db: fakeDb() });
    const res = await request(app).get('/metrics');
    expect(res.status).toBe(200);
    expect(res.text).toContain('http_requests_total');
  });
});

describe('/api/items', () => {
  const item = { id: 1, title: 'ship it', done: false, created_at: '2026-01-01T00:00:00Z' };

  it('lists items', async () => {
    const db = fakeDb(async () => ({ rows: [item] }));
    const res = await request(createApp({ db })).get('/api/items');
    expect(res.status).toBe(200);
    expect(res.body).toEqual([item]);
  });

  it('creates an item', async () => {
    const db = fakeDb(async () => ({ rows: [item] }));
    const res = await request(createApp({ db })).post('/api/items').send({ title: '  ship it  ' });
    expect(res.status).toBe(201);
    expect(db.query).toHaveBeenCalledWith(expect.stringContaining('INSERT'), ['ship it']);
  });

  it('rejects empty title', async () => {
    const db = fakeDb();
    const res = await request(createApp({ db })).post('/api/items').send({ title: '' });
    expect(res.status).toBe(400);
    expect(db.query).not.toHaveBeenCalled();
  });

  it('updates done flag', async () => {
    const db = fakeDb(async () => ({ rows: [{ ...item, done: true }] }));
    const res = await request(createApp({ db })).patch('/api/items/1').send({ done: true });
    expect(res.status).toBe(200);
    expect(res.body.done).toBe(true);
  });

  it('returns 404 on unknown item update', async () => {
    const db = fakeDb(async () => ({ rows: [] }));
    const res = await request(createApp({ db })).patch('/api/items/99').send({ done: true });
    expect(res.status).toBe(404);
  });

  it('rejects invalid id', async () => {
    const res = await request(createApp({ db: fakeDb() })).delete('/api/items/abc');
    expect(res.status).toBe(400);
  });

  it('deletes an item', async () => {
    const db = fakeDb(async () => ({ rowCount: 1 }));
    const res = await request(createApp({ db })).delete('/api/items/1');
    expect(res.status).toBe(204);
  });

  it('returns 500 on db error', async () => {
    const db = fakeDb(async () => { throw new Error('boom'); });
    const res = await request(createApp({ db })).get('/api/items');
    expect(res.status).toBe(500);
  });
});
