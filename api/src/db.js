const { Pool } = require('pg');
const config = require('./config');

let pool;

function getPool() {
  if (!pool) {
    pool = new Pool(config.db);
  }
  return pool;
}

async function query(text, params) {
  return getPool().query(text, params);
}

async function close() {
  if (pool) {
    await pool.end();
    pool = undefined;
  }
}

module.exports = { query, close, getPool };
