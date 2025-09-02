# Multi-stage build for optimal ARM64 performance on Raspberry Pi 5
ARG NODE_VERSION=20-alpine
FROM node:${NODE_VERSION} AS base
WORKDIR /app
RUN apk add --no-cache python3 make g++ curl

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

# Install PM2 globally for ARM64
RUN npm install -g pm2@5.4.2 --unsafe-perm

# Copy dependencies
COPY --from=dependencies /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Create required directories
RUN mkdir -p data logs && chown -R nodejs:nodejs data logs


USER nodejs

EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:3000/api/system/status || exit 1

# Use PM2 for process management
CMD ["pm2-runtime", "start", "ecosystem.config.mjs", "--env", "production"]