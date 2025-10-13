// index.js
const express = require('express');
const app = express();
const PORT = process.env.PORT || 3000;

app.get('/', (req, res) => {
  res.send('Aotumaction Deployment using Bitbucketv + Docker Hub in Ubuntu Server');
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
