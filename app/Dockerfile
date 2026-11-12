FROM node:22-alpine

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies from the tracked lockfile so builds are reproducible.
RUN npm ci --omit=dev

# Copy the application files
COPY server.js ./
COPY services/ ./services/
COPY public/ ./public/

# Ensure the public directory exists
RUN mkdir -p /app/public

# Expose the port
EXPOSE 3000

# Start the application
CMD ["node", "server.js"] 