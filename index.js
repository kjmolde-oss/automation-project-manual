// index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Automation Deployment using Bitbucket + Docker Hub + Kubernetes + k3s + k3d in ubuntu server successfully');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
