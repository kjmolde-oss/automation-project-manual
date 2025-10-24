# Use a lightweight Node.js base image
FROM node:20-alpine

# Set working directory
WORKDIR /usr/src/app

# Copy package files first for caching
COPY package*.json ./

# Install dependencies
RUN npm install --production
# Copy all source code
COPY . .

# Expose the app port
EXPOSE 3000

# Define the command to start the application
CMD ["npm", "index.js"]
