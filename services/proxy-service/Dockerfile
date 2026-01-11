FROM node:20-alpine

WORKDIR /app

# Copy package files (from services/proxy-service relative to build context root)
COPY services/proxy-service/package*.json ./
COPY services/proxy-service/tsconfig.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY services/proxy-service/src ./src

# Build TypeScript
RUN npm run build

# Expose port
EXPOSE 8080

# Start server
CMD ["node", "dist/index.js"]
