import express from 'express';
import dotenv from 'dotenv';
import pool from './config/db'; 

dotenv.config();

const app = express();
const port = process.env.APP_PORT || 4000;

app.get('/test-db', async (req, res) => {
  try {
    const result = await pool.query('SELECT NOW()');
    res.json({ time: result.rows[0] });
  } catch (err) {
    console.error('DB error:', err);
    res.status(500).send('Database connection failed');
  }
});

app.get('/test', (req, res) => {
  res.send('ok');
});

app.listen(port, () => {
  console.log(`Server is running on port ${port}`);
});
