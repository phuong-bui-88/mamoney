#!/bin/bash

# Start socat to bridge Windows ADB through WSL2 host
# This allows the container to access Windows adb.exe running on Windows localhost:5037
# socat listens on 127.0.0.1:5037 inside container and forwards to host.docker.internal:5037 (WSL2 host)
# echo "Starting ADB bridge to Windows adb.exe..."
# socat TCP-LISTEN:5037,reuseaddr,fork TCP:host.docker.internal:5037 2>&1 | while read line; do echo "[socat] $line"; done &
# SOCAT_PID=$!
# echo "ADB bridge started (PID: $SOCAT_PID)"

# Give socat a moment to start
# sleep 2

# Set up environment variables
export ANDROID_HOME=/opt/android-sdk
export ANDROID_SDK_ROOT=/opt/android-sdk
export PATH=/opt/android-sdk/cmdline-tools/bin:/usr/local/bin:/usr/bin:$PATH

# Pre-accept Android SDK licenses on startup for flutteruser
echo "Pre-accepting Android SDK licenses..."
su flutteruser -c "export ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk PATH=/opt/android-sdk/cmdline-tools/bin:/usr/local/bin:/usr/bin:\$PATH && yes | flutter doctor --android-licenses >/dev/null 2>&1 || yes | /opt/android-sdk/cmdline-tools/bin/sdkmanager --sdk_root=/opt/android-sdk --licenses >/dev/null 2>&1" || true

# Start ADB server
echo "Starting ADB server..."
su flutteruser -c "export ANDROID_HOME=/opt/android-sdk ANDROID_SDK_ROOT=/opt/android-sdk PATH=/opt/android-sdk/platform-tools:/opt/android-sdk/cmdline-tools/bin:/usr/local/bin:/usr/bin:\$PATH && unset ADB_HOST ADB_PORT ADB_SERVER_SOCKET && adb start-server" || true

# Export for child processes
# export SOCAT_PID
export ANDROID_LICENSES=1

# Execute the main command
exec "$@"
