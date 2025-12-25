FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files (build context is repo root)
COPY services/orchestration-service/package*.json ./
COPY services/orchestration-service/tsconfig.json ./
COPY shared ./shared

RUN npm install
RUN cd shared/auth && npm install || true

# Build shared packages first (build from shared directory to handle cross-package imports)
WORKDIR /app/shared
RUN cd auth && npm run build || true
WORKDIR /app

# Reinstall to pick up built shared packages
RUN npm install

COPY services/orchestration-service/src ./src
RUN npm run build

# Copy compiled shared files back to shared directories for runtime resolution
RUN cp -r dist/shared/utils/*.js shared/utils/ 2>/dev/null || true
RUN cp -r dist/shared/utils/*.d.ts shared/utils/ 2>/dev/null || true
RUN cp -r dist/shared/types/*.js shared/types/ 2>/dev/null || true
RUN cp -r dist/shared/types/*.d.ts shared/types/ 2>/dev/null || true

FROM node:20-alpine

WORKDIR /app

# Copy shared packages first (needed for npm install)
COPY --from=builder /app/shared ./shared

# Copy package files (build context is repo root)
COPY services/orchestration-service/package*.json ./
RUN npm install --omit=dev

# Install shared packages' production dependencies
RUN cd shared/auth && npm install --omit=dev || true

COPY --from=builder /app/dist ./dist

# Copy compiled shared files to shared directories for runtime resolution
RUN cp -r dist/shared/utils/*.js shared/utils/ 2>/dev/null || true
RUN cp -r dist/shared/utils/*.d.ts shared/utils/ 2>/dev/null || true
RUN cp -r dist/shared/types/*.js shared/types/ 2>/dev/null || true
RUN cp -r dist/shared/types/*.d.ts shared/types/ 2>/dev/null || true

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080

CMD ["node", "dist/src/index.js"]

