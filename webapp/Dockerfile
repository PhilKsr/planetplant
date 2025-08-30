# Multi-stage build for optimal production image
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM nginx:1.25-alpine AS production

# Install curl for health checks
RUN apk add --no-cache curl

# Copy custom nginx configuration
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY docker/default.conf /etc/nginx/conf.d/default.conf

# Copy built application from builder stage
COPY --from=builder /app/dist /usr/share/nginx/html

# Copy PWA files to correct locations
COPY --from=builder /app/dist/sw.js /usr/share/nginx/html/
COPY --from=builder /app/dist/manifest.json /usr/share/nginx/html/

# Create nginx user for security
RUN addgroup -g 1001 -S nginx-app && \
    adduser -S nginx-app -u 1001

# Set ownership and permissions
RUN chown -R nginx-app:nginx-app /usr/share/nginx/html && \
    chmod -R 755 /usr/share/nginx/html

# Create directories for nginx
RUN mkdir -p /var/cache/nginx && \
    mkdir -p /var/log/nginx && \
    mkdir -p /etc/nginx/conf.d && \
    touch /var/run/nginx.pid && \
    chown -R nginx-app:nginx-app /var/cache/nginx && \
    chown -R nginx-app:nginx-app /var/log/nginx && \
    chown -R nginx-app:nginx-app /var/run/nginx.pid

# Switch to non-root user
USER nginx-app

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8080/health || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]