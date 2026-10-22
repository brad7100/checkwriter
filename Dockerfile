# Use Node.js 18 Alpine image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Copy package files
COPY printmechecks/package*.json ./

# Install dependencies (including dev dependencies for build)
RUN npm ci

# Copy source code
COPY printmechecks/ .

# Build the application
RUN npm run build

# Install serve for production
RUN npm install -g serve

# Remove dev dependencies to reduce image size
RUN npm prune --production

# Create non-root user for running the application
RUN addgroup -g 1001 -S nodejs && \
    adduser -S nodejs -u 1001

# Change ownership of app directory
RUN chown -R nodejs:nodejs /app

# Switch to non-root user
USER nodejs

# Expose port
EXPOSE 3000

# Start the application using serve with security headers config
CMD ["sh", "-c", "serve -s dist -l ${PORT:-3000} --no-clipboard"]
