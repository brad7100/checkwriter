#!/bin/bash

# Navigate to the printmechecks directory
cd printmechecks

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo "Installing dependencies..."
    npm install
fi

# Build the application
echo "Building application..."
npm run build

# Start the preview server
echo "Starting server on port ${PORT:-3000}..."
npm run preview -- --host 0.0.0.0 --port ${PORT:-3000}
