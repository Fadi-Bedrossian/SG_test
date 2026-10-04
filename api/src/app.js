const express = require('express');
const helmet = require('helmet');
const pinoHttp = require('pino-http');
const client = require('prom-client');
const itemsRouter = require('./routes/items');

function createApp({ db, logger } = {}) {
  const app = express();
  const registry = new client.Registry();
  client.collectDefaultMetrics({ register: registry });
  const httpRequests = new client.Counter({
    name: 'http_requests_total',
    help: 'Total HTTP requests',
    labelNames: ['method', 'route', 'status'],
    registers: [registry],
  });

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(express.json({ limit: '100kb' }));
  if (logger) app.use(pinoHttp({ logger, autoLogging: { ignore: (req) => req.url.startsWith('/health') } }));

  app.use((req, res, next) => {
    res.on('finish', () => {
      httpRequests.inc({ method: req.method, route: req.route?.path || req.path, status: res.statusCode });
    });
    next();
  });

  // Liveness: the process is up.
  app.get('/healthz', (_req, res) => res.json({ status: 'ok' }));

  // Readiness: we can reach PostgreSQL.
  app.get('/readyz', async (_req, res) => {
    try {
      await db.query('SELECT 1');
      res.json({ status: 'ready' });
    } catch {
      res.status(503).json({ status: 'unavailable' });
    }
  });

  app.get('/metrics', async (_req, res) => {
    res.set('Content-Type', registry.contentType);
    res.end(await registry.metrics());
  });

  app.use('/api/items', itemsRouter(db));

  app.use((_req, res) => res.status(404).json({ error: 'not found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, _next) => {
    (req.log || console).error({ err }, 'unhandled error');
    res.status(500).json({ error: 'internal server error' });
  });

  return app;
}

module.exports = { createApp };
