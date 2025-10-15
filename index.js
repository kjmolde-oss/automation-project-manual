// index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Automation Deployment using Bitbucket + Docker Hub + Kubernetes in Ubuntu Server successfully');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
