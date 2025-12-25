FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY services/connector-service/package*.json ./
COPY services/connector-service/tsconfig.json ./

# Copy shared dependencies
COPY shared ./shared

# Install dependencies for service and shared packages
RUN npm install
RUN cd shared/auth && npm install || true

# Build shared packages first (build from shared directory to handle cross-package imports)
WORKDIR /app/shared
RUN cd auth && npm run build || true
WORKDIR /app

# Reinstall to pick up built shared packages
RUN npm install

# Copy source code
COPY services/connector-service/src ./src

# Build service
RUN npm run build

# Copy compiled shared files back to shared directories for runtime resolution
RUN cp -r dist/shared/utils/*.js shared/utils/ 2>/dev/null || true
RUN cp -r dist/shared/utils/*.d.ts shared/utils/ 2>/dev/null || true
RUN cp -r dist/shared/types/*.js shared/types/ 2>/dev/null || true
RUN cp -r dist/shared/types/*.d.ts shared/types/ 2>/dev/null || true

# Production image
FROM node:20-alpine

WORKDIR /app

# Copy built application first (needed for copying compiled shared files)
COPY --from=builder /app/dist ./dist

# Copy shared packages (source structure)
COPY --from=builder /app/shared ./shared

# Copy compiled shared files to shared directories BEFORE npm install
# This ensures the .js files exist when npm creates symlinks
RUN if [ -d "dist/shared/utils" ]; then cp dist/shared/utils/*.js shared/utils/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/utils" ]; then cp dist/shared/utils/*.d.ts shared/utils/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/types" ]; then cp dist/shared/types/*.js shared/types/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/types" ]; then cp dist/shared/types/*.d.ts shared/types/ 2>/dev/null || true; fi

# Copy package files
COPY services/connector-service/package*.json ./

# Install production dependencies (this will also install shared package dependencies)
RUN npm install --omit=dev

# Install shared packages' production dependencies
RUN cd shared/auth && npm install --omit=dev || true

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080

CMD ["node", "dist/src/index.js"]

