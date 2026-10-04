const pino = require('pino');
const config = require('./config');
const db = require('./db');
const { createApp } = require('./app');

const logger = pino({ level: config.logLevel });
const app = createApp({ db, logger });

const server = app.listen(config.port, () => {
  logger.info({ port: config.port }, 'api listening');
});

// Graceful shutdown so Kubernetes rolling updates don't drop requests.
function shutdown(signal) {
  logger.info({ signal }, 'shutting down');
  server.close(async () => {
    await db.close();
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
