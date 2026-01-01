# 🚀 Quick Start Guide - MaMoney

Get your money management app running in 5 minutes!

## Prerequisites

✅ **Docker Desktop** installed  
✅ **VS Code** installed  
✅ **Dev Containers Extension** installed (ms-vscode-remote.remote-containers)  
✅ **Google Account** (for Firebase)

## Step 1: Open in DevContainer (1 minute)

1. Open `/mamoney` folder in VS Code
2. Press `F1`
3. Type "Dev Containers: Reopen in Container"
4. Click and wait for container to build (~5-10 min first time)

## Step 2: Set Up Firebase (2 minutes)

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Create new project
3. Enable Email/Password Authentication
4. Create Firestore Database
5. Get your config from Project Settings
6. Update `lib/services/firebase_config.dart` with your credentials

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for detailed steps.

## Step 3: Run the App (1 minute)

Open terminal in VS Code (container is already active):

```bash
flutter pub get
flutter run -d web
```

✨ **Done!** App will open at `http://localhost:8080`

## First Test

1. Click **Sign Up**
2. Enter test email: `test@example.com`
3. Password: anything (min 6 chars)
4. Click **Sign Up**
5. Click the **+** button to add a transaction
6. Fill in and click **Add Transaction**

## What You Got

✅ Full Flutter app with Firebase backend  
✅ User authentication  
✅ Income/expense tracking  
✅ Cloud data persistence  
✅ Docker development environment  
✅ Hot reload for fast development  

## Explore the App

| Feature | How to Use |
|---------|-----------|
| **Sign Up** | Create new account |
| **Dashboard** | View balance, income, expenses |
| **Add Transaction** | Click **+** button |
| **View All** | See complete transaction list |
| **Delete** | Swipe left on transaction |
| **Filter** | Use buttons on transaction list |

## Useful Commands

```bash
# Format code
dart format lib/

# Run tests
flutter test

# Build for web
flutter build web

# Full app restart
# Press R in terminal (instead of r for hot reload)

# Check flutter status
flutter doctor
```

## Need Help?

- 📖 [Full README](README.md)
- 🔥 [Firebase Setup Guide](FIREBASE_SETUP.md)
- 🐳 [DevContainer Guide](DEVCONTAINER_SETUP.md)
- 📝 [Implementation Summary](IMPLEMENTATION_SUMMARY.md)

## Project Structure

```
lib/
├── main.dart                      # App start
├── screens/                       # UI screens
├── models/                        # Data models
└── services/                      # Firebase & state management
```

## Architecture Overview

```
┌─────────────────────────────────┐
│     Flutter Screens (UI)        │
│  - LoginScreen                  │
│  - HomeScreen                   │
│  - TransactionScreens           │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│   Provider (State Management)   │
│  - AuthProvider                 │
│  - TransactionProvider          │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│   Firebase Services             │
│  - Authentication               │
│  - Firestore Database           │
└─────────────────────────────────┘
```

## Features Included

- 🔐 User Authentication (Email/Password)
- 💰 Income & Expense Tracking
- 📊 Balance Dashboard
- 💾 Cloud Data Storage
- 📱 Beautiful Material UI
- 🔄 Real-time Updates
- 🚀 Hot Reload Development
- 🐳 Docker Containerized

## Next Steps

1. ✅ Run the app
2. ✅ Add some test transactions
3. ✅ Check data in Firebase Console
4. ✅ Customize features as needed
5. ✅ Deploy when ready

## Pro Tips

- 💡 Press `r` in terminal for quick reload
- 💡 Press `R` for full app restart
- 💡 Use Chrome DevTools for web debugging
- 💡 Check Flutter documentation for more features
- 💡 Visit Firebase Console to see your data

---

**That's it! You're ready to manage money! 💸**

For more details, see the [full README](README.md).
