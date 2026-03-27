#!/bin/bash

# Script to run Flutter commands inside the mamoney-dev container
# Usage: ./flutter-in-container.sh <flutter command>

if [ $# -eq 0 ]; then
    echo "Usage: $0 <flutter command>"
    echo "Example: $0 doctor"
    echo "Example: $0 pub get"
    echo "Example: $0 run -d web"
    exit 1
fi

# Check if container is running
if ! docker ps | grep -q mamoney-dev; then
    echo "Container mamoney-dev is not running. Starting it..."
    docker-compose up -d
    sleep 5
fi

# Run the flutter command in the container
docker exec -it mamoney-dev flutter "$@"