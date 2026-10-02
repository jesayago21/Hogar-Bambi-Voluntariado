const path = require('path');
require('dotenv').config({ path: path.join(__dirname, '..', '.env') });
const { Pool } = require('pg');

const pool = new Pool({
  user: process.env.PGUSER || 'postgres',
  host: process.env.PGHOST || 'localhost',
  database: process.env.PGDATABASE || 'voluntariado_hogar_bambi',
  password: process.env.PGPASSWORD || '',
  port: Number(process.env.PGPORT) || 5432,
});

module.exports = pool;
