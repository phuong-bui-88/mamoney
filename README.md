# MaMoney - Money Management App

A Flutter-based money management application that helps you track your income and expenses using Firebase as the backend database.

## Features

- 🔐 **User Authentication**: Secure login and registration with Firebase Authentication
- 💰 **Income Tracking**: Record all sources of income
- 💸 **Expense Tracking**: Categorize and track all your expenses
- 📊 **Balance Dashboard**: View your total balance, income, and expenses at a glance
- 📱 **Beautiful UI**: Clean and intuitive Material Design interface
- ☁️ **Cloud Sync**: All data is synced with Firebase in real-time
- 📱 **Cross-Platform**: Works on Android, iOS, Web, and Desktop

## Project Structure

```
mamoney/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   ├── transaction.dart     # Transaction model
│   │   └── user.dart            # User model
│   ├── screens/
│   │   ├── login_screen.dart    # Authentication screen
│   │   ├── home_screen.dart     # Main dashboard
│   │   ├── add_transaction_screen.dart   # Add transaction form
│   │   └── transaction_list_screen.dart  # View all transactions
│   └── services/
│       ├── firebase_service.dart    # Firebase integration
│       ├── auth_provider.dart       # Authentication state management
│       ├── transaction_provider.dart # Transaction state management
│       └── firebase_config.dart     # Firebase configuration
├── pubspec.yaml                 # Flutter dependencies
├── Dockerfile                   # Docker configuration
├── docker-compose.yml           # Docker Compose setup
├── .devcontainer/
│   └── devcontainer.json       # VS Code DevContainer config
├── FIREBASE_SETUP.md           # Firebase setup instructions
└── README.md                   # This file
```

## Prerequisites

- **Docker & Docker Compose** - For containerized development
- **VS Code** - With DevContainer extension
- **Firebase Account** - For backend services
- **Git** - For version control

## Quick Start with DevContainer

### 1. Clone or Setup the Project

```bash
cd /path/to/mamoney
```

### 2. Open in VS Code with DevContainer

1. Install the "Dev Containers" extension in VS Code
2. Open the project in VS Code
3. Press `F1` and select "Dev Containers: Reopen in Container"
4. Wait for the container to build and start

### 3. Set Up Firebase

1. Follow the detailed instructions in [FIREBASE_SETUP.md](FIREBASE_SETUP.md)
2. Update `lib/services/firebase_config.dart` with your Firebase credentials

### 4. Initialize the App

In the DevContainer terminal:

```bash
# Get dependencies
flutter pub get

# Run on web (easiest for testing)
flutter run -d web
```

## Manual Setup (Without DevContainer)

### Prerequisites
- Flutter SDK (3.1.0 or later)
- Dart SDK (3.1.0 or later)
- Android Studio or Xcode (for mobile development)

### Installation

```bash
# Get dependencies
flutter pub get

# Run on your device/emulator
flutter run

# Or run on web
flutter run -d web
```

## Using Docker Compose Directly

### Build the Development Container

```bash
docker-compose build
```

### Start the Development Container

```bash
docker-compose up -d
```

### Access the Container

```bash
docker-compose exec flutter-dev bash
```

### Inside the Container

```bash
# Get dependencies
flutter pub get

# Run flutter doctor to verify setup
flutter doctor

# Run the app
flutter run -d web
```

## Available Platforms

The app can run on multiple platforms:

### Web
```bash
flutter run -d web
```
Access at `http://localhost:8080`

### Android
```bash
flutter run -d android
```

### iOS
```bash
flutter run -d ios
```

### Desktop (Linux/macOS/Windows)
```bash
flutter run -d linux
# or
flutter run -d macos
# or
flutter run -d windows
```

## How to Use the App

### 1. Sign Up / Login
- Enter your email and password
- Click "Sign Up" to create a new account or "Sign In" if you already have one

### 2. View Dashboard
- See your total balance at the top
- View income and expense summaries
- Check recent transactions

### 3. Add a Transaction
- Click the "+" button (FAB)
- Select transaction type (Income/Expense)
- Fill in description, amount, category, and date
- Click "Add Transaction"

### 4. View All Transactions
- Click "View All" on the dashboard
- Filter by transaction type (All/Income/Expense)
- Swipe left to delete a transaction

## Architecture

### State Management
The app uses **Provider** for state management:
- `AuthProvider`: Manages authentication state
- `TransactionProvider`: Manages transaction state

### Services
- `FirebaseService`: Core Firebase operations (auth, Firestore)
- `FirebaseConfig`: Firebase configuration (credentials)

### Models
- `Transaction`: Represents a single transaction
- `User`: Represents a user profile

## Configuration

### Firebase Configuration

Update `lib/services/firebase_config.dart` with your Firebase project credentials:

```dart
class FirebaseConfig {
  static const FirebaseOptions firebaseOptions = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'YOUR_AUTH_DOMAIN',
    databaseURL: 'YOUR_DATABASE_URL',
    storageBucket: 'YOUR_STORAGE_BUCKET',
  );
}
```

See [FIREBASE_SETUP.md](FIREBASE_SETUP.md) for detailed instructions.

## Development

### Adding Dependencies

```bash
flutter pub add package_name
```

### Code Formatting

```bash
dart format lib/
```

### Running Tests

```bash
flutter test
```

### Building for Production

```bash
# Web
flutter build web

# APK (Android)
flutter build apk

# App Bundle (Android Play Store)
flutter build appbundle

# iOS
flutter build ios

# Desktop
flutter build linux
flutter build macos
flutter build windows
```

## Common Issues and Solutions

### Issue: "Permission denied" when accessing Firestore
**Solution**: Check that Firestore rules are properly configured. See FIREBASE_SETUP.md

### Issue: App won't connect to Firebase
**Solution**: Verify your Firebase config in `firebase_config.dart` is correct

### Issue: Hot reload not working
**Solution**: Use `flutter run` with the `-v` flag for verbose output

### Issue: Docker build fails
**Solution**: Ensure you have enough disk space and internet connection, then rebuild:
```bash
docker-compose down
docker-compose build --no-cache
```

## Contributing

1. Create a new branch for your feature
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## Dependencies

- **firebase_core**: Firebase initialization
- **firebase_auth**: User authentication
- **cloud_firestore**: Cloud database
- **provider**: State management
- **intl**: Date/time formatting
- **uuid**: Unique ID generation

## License

This project is open source and available under the MIT License.

## Support

For issues or questions:
1. Check the [FIREBASE_SETUP.md](FIREBASE_SETUP.md) file
2. Review the code comments
3. Check Flutter documentation at https://flutter.dev

## Future Enhancements

- [ ] Budget tracking and alerts
- [ ] Data visualization and charts
- [ ] Export transactions (CSV/PDF)
- [ ] Recurring transactions
- [ ] Multiple currencies support
- [ ] Dark mode
- [ ] Monthly/yearly reports
- [ ] Transaction search and filtering
- [ ] Receipt photo attachments

---

**Happy tracking! 💰**
