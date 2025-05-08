import express from 'express';
import { pool } from '../config/db';

const app = express();

app.get('/users', async (req, res) => {
  const result = await pool.query('SELECT * FROM users');
  res.json(result.rows);
});