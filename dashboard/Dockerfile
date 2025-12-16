FROM node:20-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --production --no-optional

# Copy application files
COPY . .

# Expose port
EXPOSE 3000

# Run the app
CMD ["node", "server.js"]
