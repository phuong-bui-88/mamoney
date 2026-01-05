#!/bin/bash
set -e

# Start socat to bridge Windows ADB through WSL2 host
# This allows the container to access Windows adb.exe running on Windows localhost:5037
# socat listens on 127.0.0.1:5037 inside container and forwards to host.docker.internal:5037 (WSL2 host)
echo "Starting ADB bridge to Windows adb.exe..."
socat TCP-LISTEN:5037,reuseaddr,fork TCP:host.docker.internal:5037 &
SOCAT_PID=$!
echo "ADB bridge started (PID: $SOCAT_PID)"

# Give socat a moment to start
sleep 1

# Export for child processes
export SOCAT_PID

# Execute the main command
exec "$@"
