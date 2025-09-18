#!/bin/bash

# Build and push script for the demo application
# Usage: ./build-and-push.sh [TAG]

set -e

# Default values
REGISTRY="ghcr.io"
IMAGE_NAME="demo-app-go"
TAG="${1:-latest}"

# Get GitHub username from git config or environment
GITHUB_USERNAME="${GITHUB_USERNAME:-$(git config user.name | tr '[:upper:]' '[:lower:]' | tr ' ' '-')}"

if [ -z "$GITHUB_USERNAME" ]; then
    echo "Error: GitHub username not found. Set GITHUB_USERNAME environment variable or configure git user.name"
    exit 1
fi

FULL_IMAGE_NAME="${REGISTRY}/${GITHUB_USERNAME}/${IMAGE_NAME}:${TAG}"

echo "Building Docker image: $FULL_IMAGE_NAME"

# Build the Docker image
docker build -t "$FULL_IMAGE_NAME" .

echo "Image built successfully: $FULL_IMAGE_NAME"

# Ask for confirmation before pushing
read -p "Do you want to push to GitHub Container Registry? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Logging in to GitHub Container Registry..."
    echo "Please ensure you have a GitHub Personal Access Token with 'write:packages' scope"
    echo "You can create one at: https://github.com/settings/tokens"
    
    # Login to GitHub Container Registry
    docker login ghcr.io
    
    echo "Pushing image to GitHub Container Registry..."
    docker push "$FULL_IMAGE_NAME"
    
    echo "Image pushed successfully!"
    echo "You can now use this image in your Kubernetes deployments:"
    echo "  image: $FULL_IMAGE_NAME"
else
    echo "Image not pushed. You can push it later with:"
    echo "  docker push $FULL_IMAGE_NAME"
fi