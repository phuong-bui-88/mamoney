# MaMoney Dev Container Rebuild Guide

## Updates Made to Fix Android SDK

The following fixes have been applied to your Dockerfile to ensure complete Android development setup:

### 1. **Android SDK 36 Installation**
   - Updated `sdkmanager` command to install multiple Android API levels (33, 34, 35, 36)
   - Installed corresponding build-tools for each API level (33.0.2, 34.0.0, 35.0.0, 36.0.0)
   - Added NDK 27.0.12077973 for native code compilation

### 2. **Additional System Dependencies**
   - Added `netcat-openbsd` for network testing and troubleshooting

### 3. **Environment Configuration**
   - Fixed `ADB_SERVER_SOCKET` to connect to Windows ADB server: `tcp:172.30.176.1:5037`
   - Pre-configured ADB connection in `devcontainer.json` postCreateCommand

## Rebuild Instructions

### Option 1: Full Clean Rebuild (Recommended)

```bash
cd /home/admin1/projects/test/mamoney

# Stop and remove current container
docker-compose down

# Rebuild from scratch (no cache)
docker-compose build --no-cache

# Start the container
docker-compose up -d

# Verify setup
docker exec mamoney-dev flutter doctor
```

**Note:** This will take 5-10 minutes as it downloads and installs all dependencies.

### Option 2: Quick Rebuild (with cache)

```bash
cd /home/admin1/projects/test/mamoney

docker-compose build
docker-compose up -d
docker exec mamoney-dev flutter doctor
```

### Option 3: Using VS Code Dev Containers

1. **Press F1** to open Command Palette
2. Type: **"Dev Containers: Rebuild Container"**
3. Wait for build to complete
4. Open terminal and run:
   ```bash
   flutter doctor
   ```

## Verification

After rebuild, you should see in `flutter doctor`:

```
[✓] Android toolchain - develop for Android devices (Android SDK version 36.0.0)
[✓] Connected device (2 available)
    - emulator-5554 (Android)
    - linux (Linux)
```

## Build Process Details

The Dockerfile now:
1. Installs all system dependencies including build tools
2. Downloads and installs Android SDK command-line tools
3. Installs Android API levels 33-36
4. Installs corresponding build-tools for each API level
5. Installs Android NDK for native development
6. Configures Flutter environment
7. Sets up ADB connection to Windows

## Troubleshooting Build Issues

### If build times out:
```bash
# Kill the build
docker kill mamoney-dev

# Clean up
docker-compose down

# Try again
docker-compose build && docker-compose up -d
```

### If you get memory errors:
- Increase Docker memory limit in Docker Desktop settings
- Try building with cache: `docker-compose build` (instead of `--no-cache`)

### To check build progress:
```bash
docker ps -a | grep mamoney
docker logs mamoney-dev -f  # Follow logs
```

## Files Modified

- **Dockerfile**: Added Android SDK 36, build-tools, and NDK installation
- **docker-compose.yml**: Added ADB environment variables and port forwarding
- **.devcontainer/devcontainer.json**: Added ADB auto-connection on container creation

## After Rebuild

Once the container is running, you can:

```bash
# Enter container
docker exec -it mamoney-dev zsh

# Run Flutter commands
flutter pub get
flutter run                    # Run on connected emulator
flutter build apk             # Build APK
flutter build apk --release   # Build release APK
```

## Expected Build Time

- **First build (no cache)**: 5-10 minutes
  - Downloading system packages
  - Installing Android SDK (~1GB)
  - Installing Flutter and dependencies
  
- **Rebuild (with cache)**: 30 seconds - 2 minutes

## Support

If you encounter issues:
1. Check Docker is running: `docker ps`
2. Check container logs: `docker logs mamoney-dev`
3. Verify ADB connection: `docker exec mamoney-dev adb devices`
4. Run flutter doctor: `docker exec mamoney-dev flutter doctor -v`
