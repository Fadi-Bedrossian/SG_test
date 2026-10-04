// Centralised configuration, read from environment variables.
// In AKS these come from a ConfigMap (non-secret) and a Secret synced from Azure Key Vault.
const config = {
  port: Number(process.env.PORT || 3000),
  logLevel: process.env.LOG_LEVEL || 'info',
  db: {
    host: process.env.PGHOST || 'localhost',
    port: Number(process.env.PGPORT || 5432),
    database: process.env.PGDATABASE || 'app',
    user: process.env.PGUSER || 'app',
    password: process.env.PGPASSWORD || 'app',
    ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: true } : false,
    max: Number(process.env.PGPOOL_MAX || 10),
  },
};

module.exports = config;
