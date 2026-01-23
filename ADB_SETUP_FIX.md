# ADB Devices Connection Fix for Dev Container (Windows + WSL2)

## Problem
When running `adb devices` inside the dev container (running in WSL2), it shows no devices even though the Android emulator is running on Windows.

## Solution
The dev container needs to connect to the Windows ADB server through the WSL2 network bridge.

## Setup Steps

### Step 1: Find Your Windows IP Address

On **Windows PowerShell**, run:

```powershell
ipconfig
```

Look for your ethernet or WiFi adapter's IPv4 address (e.g., `192.168.1.100`)

Or use this one-liner to get just the IP:
```powershell
(Get-NetIPConfiguration | Where-Object {$_.IPv4DefaultGateway -ne $null}).IPv4Address.IPAddress
```

Save this IP address - you'll need it in the next step.

### Step 2: Set Environment Variable (Before Starting Container)

In your **WSL2 terminal** (or PowerShell), set the Windows IP:

```bash
# Replace with your actual Windows IP from Step 1
export ADB_HOST=192.168.1.100
export ADB_PORT=5037

# Then start/rebuild the container
docker-compose down
docker-compose up -d
```

**Or**, create a `.env` file in the mamoney root directory:

```bash
# .env file
ADB_HOST=192.168.1.100
ADB_PORT=5037
```

Then just run:
```bash
docker-compose up -d
```

### Step 3: Verify Host ADB Server is Accessible

Inside the dev container, test the connection to Windows:

```bash
# Check if port 5037 is reachable on Windows
nc -zv 192.168.1.100 5037
```

You should see: `Connection to 192.168.1.100 5037 port [tcp/*] succeeded!`

### Step 4: Connect to Windows ADB Server

Inside the dev container:

```bash
adb connect 192.168.1.100:5037
```

If you used the environment variable setup, you can also do:
```bash
adb connect $ADB_HOST:$ADB_PORT
```

### Step 5: Verify Devices

```bash
adb devices
```

You should now see:
```
List of devices attached
emulator-5554   device
```

## What Changed

### docker-compose.yml Updates
- Changed to use environment variables `ADB_HOST` and `ADB_PORT`
- Removed USB device mounting (not needed for Windows emulator access)
- Kept Android config directory mount for consistency

### Configuration Details
- Default `ADB_HOST` is `host.docker.internal` (for local dev)
- Default `ADB_PORT` is `5037` (standard ADB port)
- Override these by setting environment variables or creating a `.env` file

## Troubleshooting

### "Connection refused" error
1. **Verify ADB is running on Windows**:
   - Windows: Check Android Studio or run `adb devices`
   - If not running, start ADB: `adb start-server` (in Windows PowerShell)

2. **Check firewall**:
   - Windows Defender Firewall might block port 5037
   - Allow ADB through firewall or disable firewall temporarily for testing

3. **Restart ADB**:
   ```bash
   # On Windows (PowerShell)
   adb kill-server
   adb start-server
   ```

### "host.docker.internal not reachable"
- This means the Windows IP wasn't set correctly
- Go back to Step 1 and find the correct Windows IP
- Update and restart the container with `docker-compose down && docker-compose up -d`

### Verify Connection Settings
Inside the container:
```bash
echo "ADB_HOST=$ADB_HOST"
echo "ADB_PORT=$ADB_PORT"
adb connect $ADB_HOST:$ADB_PORT
adb devices
```

## Quick Reference

```bash
# 1. On Windows - Verify ADB is running
adb devices

# 2. In WSL2 - Get your Windows IP
ipconfig  # (or use PowerShell command from Step 1)

# 3. In WSL2 - Start container with Windows IP
export ADB_HOST=192.168.1.100  # Replace with your IP
docker-compose up -d

# 4. Inside container - Connect to Windows ADB
adb connect $ADB_HOST:$ADB_PORT

# 5. Verify
adb devices
flutter run
```

## Advanced: Dynamic IP Detection

If your Windows IP changes frequently, you can create a startup script. Contact support for this advanced setup.

