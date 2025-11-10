// index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

// 1. Your Main Route
app.get('/', (req, res) => {
  res.send('Automation Deployment using Bitbucket + Docker Hub + Kubernetes + k3s + k3d + blue/green deployment in ubuntu server successfully');
});

// --- 2. ADDED ROUTES FOR THE SMOKE TEST ---

// A simple /login route
app.get('/login', (req, res) => {
  res.send('Login page OK');
});

// A standard /api/health route
app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', service: 'automation-project' });
});

// --- END OF NEW ROUTES ---

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});