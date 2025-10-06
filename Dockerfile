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

# Expose port
EXPOSE 3000

# Start the application using serve
CMD ["sh", "-c", "serve -s dist -l ${PORT:-3000}"]
