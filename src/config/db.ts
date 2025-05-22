import { Pool } from 'pg';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const caCertPath = process.env.SSL_CA_PATH || './certs/ca.pem';

const caCert = fs.readFileSync(path.resolve(caCertPath)).toString();

const pool = new Pool({
  user: process.env.DB_USER,
  password: process.env.DB_PASS,
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT),
  database: process.env.DB_NAME,
  ssl: {
    rejectUnauthorized: true,
    ca: caCert,
  },
});

pool.connect()
  .then(client => {
    console.log('DB connected successfully');
    client.release();
  })
  .catch(err => {
    console.error('DB connection error on startup:', err);
  });

export default pool;
