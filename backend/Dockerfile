# Use Node.js 22 LTS (current 2025 LTS) with a specific Alpine version for stability
FROM node:22-alpine3.18 AS base

# Set working directory
WORKDIR /app

# Install dumb-init and build dependencies for better compatibility
RUN apk add --no-cache \
    dumb-init \
    python3 \
    make \
    g++ \
    && ln -sf python3 /usr/bin/python

# Create app user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy package files (use wildcard to handle optional files)
COPY package*.json ./

# Development stage
FROM base AS development
ENV NODE_ENV=development
RUN npm ci --include=dev
COPY . .
RUN chown -R nodejs:nodejs /app
USER nodejs
EXPOSE 3001
CMD ["dumb-init", "npm", "run", "dev"]

# Production dependencies stage
FROM base AS deps
ENV NODE_ENV=production

# Copy package files (use wildcard for better compatibility)
COPY package*.json ./

# Install production dependencies
RUN npm ci --omit=dev && npm cache clean --force

# Production stage
FROM node:22-alpine3.18 AS production
ENV NODE_ENV=production

# Set working directory
WORKDIR /app

# Install only runtime dependencies
RUN apk add --no-cache dumb-init

# Create app user for security
RUN addgroup -g 1001 -S nodejs
RUN adduser -S nodejs -u 1001

# Copy production dependencies
COPY --from=deps --chown=nodejs:nodejs /app/node_modules ./node_modules

# Copy application code
COPY --chown=nodejs:nodejs . .

# Create uploads directory
RUN mkdir -p uploads logs && chown -R nodejs:nodejs uploads logs

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3001

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3001/health', (res) => { process.exit(res.statusCode === 200 ? 0 : 1) })"

# Start the application
CMD ["dumb-init", "node", "src/server.js"]