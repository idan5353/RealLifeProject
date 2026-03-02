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

const client = require('prom-client');

// Collect default Node.js metrics (CPU, memory, event loop)
const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ prefix: 'task_platform_' });

// Custom HTTP request counter
const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

// Request duration histogram
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.3, 0.5, 1, 2, 5],
});

// Middleware to track all requests
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    httpRequestsTotal.inc({
      method: req.method,
      route: req.route?.path || req.path,
      status_code: res.statusCode,
    });
    end({ method: req.method, route: req.route?.path || req.path });
  });
  next();
});

// Metrics endpoint for Prometheus scraping
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
