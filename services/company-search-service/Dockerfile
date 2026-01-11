FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY services/company-search-service/package*.json ./
COPY services/company-search-service/tsconfig.json ./

# Copy shared dependencies
COPY shared ./shared

# Install dependencies for service and shared packages
RUN npm install
RUN cd shared/auth && npm install || true

# Build shared packages first
WORKDIR /app/shared
RUN cd types && npm install && npm run build && echo "shared/types build successful" || (echo "shared/types build FAILED" && exit 1)
RUN cd auth && npm install && npm run build && echo "shared/auth build successful" || (echo "shared/auth build FAILED" && exit 1)
WORKDIR /app
RUN echo "=== Verifying shared packages were built ===" && \
    ls -la shared/types/dist/ || (echo "ERROR: shared/types/dist does not exist!" && exit 1) && \
    ls -la shared/auth/dist/ || (echo "ERROR: shared/auth/dist does not exist!" && exit 1)

# Reinstall to pick up built shared packages
RUN npm install

# Copy source code
COPY services/company-search-service/src ./src

# Build service
RUN echo "=== Starting TypeScript build ===" && \
    npm run build && \
    echo "=== Build completed ===" && \
    echo "=== Checking dist structure ===" && \
    ls -la dist/ || true && \
    ls -la dist/src/ || true && \
    ls -la dist/shared/ || true

# Copy compiled shared files back to shared directories for runtime resolution
RUN if [ -d "dist/shared/types" ]; then cp -r dist/shared/types/*.js shared/types/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/types" ]; then cp -r dist/shared/types/*.d.ts shared/types/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/utils" ]; then cp -r dist/shared/utils/*.js shared/utils/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/utils" ]; then cp -r dist/shared/utils/*.d.ts shared/utils/ 2>/dev/null || true; fi

# Production image
FROM node:20-alpine

WORKDIR /app

# Copy built application
COPY --from=builder /app/dist ./dist

# Copy shared packages
COPY --from=builder /app/shared ./shared

# Copy compiled shared files to shared directories
RUN if [ -d "dist/shared/utils" ]; then cp dist/shared/utils/*.js shared/utils/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/utils" ]; then cp dist/shared/utils/*.d.ts shared/utils/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/types" ]; then cp dist/shared/types/*.js shared/types/ 2>/dev/null || true; fi
RUN if [ -d "dist/shared/types" ]; then cp dist/shared/types/*.d.ts shared/types/ 2>/dev/null || true; fi

# Copy package files
COPY services/company-search-service/package*.json ./

# Fix file: paths in package.json
RUN sed -i 's|file:../../shared/|file:./shared/|g' package.json

# Install production dependencies
RUN npm install --omit=dev

# Verify symlinks
RUN echo "=== Verifying node_modules symlinks ===" && \
    ls -la node_modules/@credovo/ || true && \
    readlink node_modules/@credovo/shared-auth || true

# Install shared packages' production dependencies
RUN cd shared/types && npm install --omit=dev || true
RUN cd shared/auth && npm install --omit=dev || true

# Create non-root user
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080

CMD ["node", "dist/src/index.js"]
