FROM nginx:1.25-alpine

# Install curl for health checks
RUN apk add --no-cache curl

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf

# Create nginx user for security
RUN addgroup -g 1001 -S nginx-app && \
    adduser -S nginx-app -u 1001

# Create required directories and set permissions
RUN mkdir -p /var/cache/nginx && \
    mkdir -p /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx-app:nginx-app /var/cache/nginx && \
    chown -R nginx-app:nginx-app /var/log/nginx && \
    chown -R nginx-app:nginx-app /var/run/nginx.pid

# Expose ports
EXPOSE 80 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:80/health || exit 1

# Start nginx as non-root user
USER nginx-app
CMD ["nginx", "-g", "daemon off;"]