#!/bin/bash

# build documentation
echo "Building documentation..."
zig build docs

# Exit on any error
set -e

# Configuration
BUCKET="s3://proxz.lukeharwood.dev"
BUILD_DIR="zig-out/docs"

# Check if build directory exists
if [ ! -d "$BUILD_DIR" ]; then
  echo "Error: Build directory not found!"
  exit 1
fi

echo "Deploying to $BUCKET..."

# Upload HTML files and service worker with no-cache
aws s3 sync $BUILD_DIR $BUCKET \
  --cache-control "no-cache"

echo "Deployment complete!"

