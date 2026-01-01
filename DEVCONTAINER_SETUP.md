# MaMoney Development Setup Guide

This guide will help you set up and run the MaMoney app in a Docker container with VS Code DevContainer support.

## What is DevContainer?

DevContainer allows you to define a development environment in a container, ensuring consistency across all developers and machines. Everything needed for development is encapsulated in the container.

## Prerequisites

### System Requirements
- **Docker**: [Install Docker Desktop](https://www.docker.com/products/docker-desktop)
- **VS Code**: [Install VS Code](https://code.visualstudio.com/)
- **VS Code Extension**: Dev Containers (ms-vscode-remote.remote-containers)

### Install Dev Containers Extension

1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X / Cmd+Shift+X)
3. Search for "Dev Containers"
4. Install the extension by Microsoft

## Getting Started with DevContainer

### Step 1: Open Project in DevContainer

1. Open the `/mamoney` folder in VS Code
2. Press `F1` to open Command Palette
3. Type "Dev Containers: Reopen in Container"
4. Select the option and wait for the container to build and start

This will:
- Build the Flutter Docker image
- Start the development container
- Install all dependencies
- Set up VS Code with Flutter extensions

### Step 2: Initial Setup

Once the container is running, open the integrated terminal and run:

```bash
flutter doctor
```

This will verify that Flutter is properly installed in the container.

### Step 3: Set Up Firebase

Follow the instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md) to:
1. Create a Firebase project
2. Set up authentication and Firestore
3. Get your Firebase credentials
4. Update `lib/services/firebase_config.dart`

### Step 4: Run the App

```bash
# Get latest dependencies
flutter pub get

# Run on web (easiest way to test in container)
flutter run -d web
```

The app will be available at `http://localhost:8080`

## Using Docker Compose Directly

If you prefer not to use DevContainer or want to understand the setup better:

### Build the Container

```bash
docker-compose build
```

### Start the Container

```bash
docker-compose up -d
```

### Access the Container

```bash
docker-compose exec flutter-dev bash
```

### Inside the Container

```bash
flutter pub get
flutter run -d web
```

## DevContainer Configuration

The DevContainer is configured in `.devcontainer/devcontainer.json`:

- **Image**: Uses the Dockerfile in the project root
- **Service**: Uses the `flutter-dev` service from docker-compose.yml
- **Extensions**: Automatically installs Flutter, Dart, and other extensions
- **Ports**: Forwards port 8080 for Flutter web
- **Post-create Command**: Runs `flutter pub get` after container starts

## File Structure

```
mamoney/
├── .devcontainer/
│   └── devcontainer.json        # DevContainer configuration
├── Dockerfile                   # Container image definition
├── docker-compose.yml           # Container orchestration
├── DEVCONTAINER_SETUP.md       # This file
├── FIREBASE_SETUP.md           # Firebase configuration guide
└── README.md                   # Main documentation
```

## Workflow

### Daily Development

1. Open project in VS Code
2. Container automatically starts
3. Make changes in the editor
4. Run `flutter run` in terminal
5. Hot reload works automatically (press `r` in terminal)

### Installing New Packages

```bash
flutter pub add package_name
```

### Running Tests

```bash
flutter test
```

### Building

```bash
# Web
flutter build web

# Android (requires Android setup)
flutter build apk
```

## Troubleshooting

### Container won't start

1. Check Docker is running
2. Try rebuilding: `Dev Containers: Rebuild Container` (F1)
3. Check Docker logs: `docker-compose logs flutter-dev`

### Flutter commands not found

```bash
# Verify Flutter is in PATH
which flutter

# If not found, try:
flutter doctor
```

### Can't access app on localhost:8080

1. Check if port 8080 is already in use
2. Verify container is running: `docker-compose ps`
3. Check container logs: `docker-compose logs flutter-dev`

### Extensions not installing

1. Rebuild container: `Dev Containers: Rebuild Container`
2. Wait for all extensions to install (check VS Code Extensions tab)
3. Restart VS Code if needed

### Hot reload not working

1. Press `R` (capital) to perform a full restart
2. Try: `flutter run --verbose` for more information
3. Rebuild the app: `flutter clean && flutter pub get`

## Tips and Best Practices

### Use Web for Testing in Container
- Android/iOS require additional setup in the container
- Web platform is easiest to test during development
- Use physical device or emulator on host machine if needed

### Hot Reload
- Press `r` in terminal for hot reload
- Press `R` for full restart
- Makes development faster

### Keep Container Updated
- Rebuild container after pulling latest changes: `docker-compose down && docker-compose build`
- This ensures all dependencies are up to date

### Volume Mounts
- Your workspace is mounted at `/workspace` in container
- Changes you make are immediately visible in container
- Container data persists in Docker volumes (pub-cache, android-sdk)

## Performance

The container setup is optimized for:
- Fast build times (with caching)
- Hot reload capability
- Persistent caches for faster rebuilds
- Shared volumes for development

First build may take 10-15 minutes, subsequent builds are much faster.

## Additional Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Dev Containers Documentation](https://containers.dev/)
- [Docker Documentation](https://docs.docker.com/)

---

**Happy coding! 🚀**
