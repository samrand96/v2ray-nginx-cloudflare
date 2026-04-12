#!/bin/bash

echo "⚠️  Stopping all containers..."
docker stop $(docker ps -aq) 2>/dev/null || echo "No containers to stop."

echo "🗑️  Removing all containers..."
docker rm -f $(docker ps -aq) 2>/dev/null || echo "No containers to remove."

echo "📦  Removing all volumes..."
docker volume rm $(docker volume ls -q) 2>/dev/null || echo "No volumes to remove."

echo "🌐  Removing all networks (except defaults)..."
docker network prune -f

echo "🧹  Removing all images..."
docker rmi -f $(docker images -aq) 2>/dev/null || echo "No images to remove."

echo "🔥  Running full system prune (catch-all)..."
docker system prune -af --volumes

echo ""
echo "✅  Docker is clean. Verify:"
docker ps -a
docker volume ls
docker images