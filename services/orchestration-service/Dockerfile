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

COPY services/orchestration-service/src ./src
RUN npm run build

FROM node:20-alpine

WORKDIR /app

# Copy package files (build context is repo root)
COPY services/orchestration-service/package*.json ./
RUN npm install --omit=dev

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/shared ./shared

RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

USER nodejs

EXPOSE 8080

ENV NODE_ENV=production
ENV PORT=8080

CMD ["node", "dist/index.js"]

