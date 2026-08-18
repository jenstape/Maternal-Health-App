const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());

// Connect to PostgreSQL
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://localhost:5432/maternal_health_dev'
});

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', message: 'Maternal Health API is running' });
});

// Real hospital route — queries the actual database
app.get('/api/hospitals', async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM hospitals ORDER BY overall_rating DESC');
    res.json({ hospitals: result.rows, total: result.rows.length });
  } catch (error) {
    console.error(error);
    res.status(500).json({ message: 'Failed to fetch hospitals' });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
