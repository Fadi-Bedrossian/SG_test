// Minimal forward-only migration runner.
// Runs every *.sql file in ../migrations in lexical order, once, tracked in schema_migrations.
// Used by the Kubernetes migration Job and by docker-compose.
const fs = require('fs');
const path = require('path');
const db = require('./db');

// Arbitrary constant: every replica's init container takes the same advisory lock,
// so only one runs migrations at a time during a rollout.
const LOCK_ID = 727274;

async function migrate() {
  const dir = path.join(__dirname, '..', 'migrations');
  const client = await db.getPool().connect();
  try {
    await client.query('SELECT pg_advisory_lock($1)', [LOCK_ID]);
    await client.query(
      'CREATE TABLE IF NOT EXISTS schema_migrations (name TEXT PRIMARY KEY, applied_at TIMESTAMPTZ NOT NULL DEFAULT now())'
    );
    const { rows } = await client.query('SELECT name FROM schema_migrations');
    const applied = new Set(rows.map((r) => r.name));
    const files = fs.readdirSync(dir).filter((f) => f.endsWith('.sql')).sort();

    for (const file of files) {
      if (applied.has(file)) continue;
      const sql = fs.readFileSync(path.join(dir, file), 'utf8');
      try {
        await client.query('BEGIN');
        await client.query(sql);
        await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [file]);
        await client.query('COMMIT');
        console.log(`applied ${file}`);
      } catch (err) {
        await client.query('ROLLBACK');
        throw err;
      }
    }
  } finally {
    await client.query('SELECT pg_advisory_unlock($1)', [LOCK_ID]).catch(() => {});
    client.release();
  }
}

if (require.main === module) {
  migrate()
    .then(() => db.close())
    .catch(async (err) => {
      console.error(err);
      await db.close();
      process.exit(1);
    });
}

module.exports = { migrate };
