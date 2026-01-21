#!/bin/bash

# Start socat to bridge Windows ADB through WSL2 host
# This allows the container to access Windows adb.exe running on Windows localhost:5037
# socat listens on 127.0.0.1:5037 inside container and forwards to host.docker.internal:5037 (WSL2 host)
echo "Starting ADB bridge to Windows adb.exe..."
socat TCP-LISTEN:5037,reuseaddr,fork TCP:host.docker.internal:5037 2>&1 | while read line; do echo "[socat] $line"; done &
SOCAT_PID=$!
echo "ADB bridge started (PID: $SOCAT_PID)"

# Give socat a moment to start
sleep 2

# Accept Android SDK licenses on startup
echo "Accepting Android SDK licenses..."
yes | /opt/android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses 2>&1 | tail -1

# Export for child processes
export SOCAT_PID

# Execute the main command
exec "$@"
