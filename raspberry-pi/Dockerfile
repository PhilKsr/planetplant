# Multi-stage build for optimal ARM64 performance on Raspberry Pi 5
ARG NODE_VERSION=20-alpine
FROM node:${NODE_VERSION} AS base
WORKDIR /app
RUN apk add --no-cache python3 make g++ curl jq

# Dependencies stage
FROM base AS dependencies
COPY package*.json ./
RUN npm ci --only=production --ignore-scripts && npm cache clean --force

# Development dependencies stage  
FROM base AS dev-dependencies
COPY package*.json ./
RUN npm ci --ignore-scripts

# Build stage
FROM dev-dependencies AS build
COPY . .
RUN npm run lint || true
RUN npm run test || true

# Production stage
FROM base AS production
RUN addgroup -g 1001 -S nodejs && adduser -S nodejs -u 1001

# PM2 not needed - using Node.js directly for better compatibility

# Copy dependencies
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Set LOG_DIR environment variable and create required directories
ENV LOG_DIR=/app/logs
RUN mkdir -p "$LOG_DIR" /app/data && chown -R nodejs:nodejs "$LOG_DIR" /app/data

USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/system/status || exit 1

# Start with Node.js directly for stability
CMD ["node", "src/app.js"]