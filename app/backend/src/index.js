const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { initDB } = require('./db');
const authRoutes = require('./routes/auth');
const taskRoutes = require('./routes/tasks');

const app = express();
app.use(cors());
app.use(express.json());

app.use('/api/auth', authRoutes);
app.use('/api', taskRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

const PORT = process.env.PORT || 5000;

// ✅ Start server first — health probe works immediately
app.listen(PORT, () => {
  console.log(`🚀 API running on port ${PORT}`);

  // Init DB after server is already listening
  initDB()
    .then(() => console.log('✅ Database ready'))
    .catch(err => {
      console.error('❌ DB init failed:', err.message);
      // Don't crash — server stays up, liveness probe stays green
      // DB errors will surface per-request
    });
});
