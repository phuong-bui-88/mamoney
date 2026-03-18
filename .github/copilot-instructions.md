# Copilot Instructions for MaMoney

## Project Overview

**MaMoney** is a Flutter-based money management application with Firebase backend. It helps users track income and expenses with real-time cloud synchronization. The app supports Android, iOS, Web, and Desktop platforms.

## Build, Test, and Lint Commands

### Setup
```bash
# Get dependencies
flutter pub get

# Run Flutter doctor to verify environment
flutter doctor
```

### Running the App
```bash
# Run on web (easiest for testing)
flutter run -d web
# Access at http://localhost:8080

# Run on Android (requires Android device/emulator)
flutter run -d android

# Run on iOS (macOS only)
flutter run -d ios

# Run on desktop
flutter run -d linux    # or: macos, windows
```

### Testing
```bash
# Run all tests (unit + widget + regression)
flutter test

# Run specific test file
flutter test test/regression_test.dart
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Code Quality
```bash
# Lint analysis
flutter analyze

# Format code
dart format lib/ test/

# Fix linting issues (where possible)
dart fix --apply lib/
```

### Building for Production
```bash
# Web build
flutter build web

# Android APK
flutter build apk

# Android App Bundle (Play Store)
flutter build appbundle

# iOS
flutter build ios --release

# Desktop
flutter build linux
flutter build macos
flutter build windows
```

## Architecture

### State Management: Provider Pattern
The app uses **Provider** for reactive state management:
- **AuthProvider** (`lib/services/auth_provider.dart`): Manages user authentication state
- **TransactionProvider** (`lib/services/transaction_provider.dart`): Manages transaction CRUD and filtering

Both extend `ChangeNotifier` and are injected via `MultiProvider` in `main.dart`.

### Firebase Integration
**FirebaseService** (`lib/services/firebase_service.dart`) is a singleton that handles:
- User authentication (Firebase Auth)
- Transaction CRUD operations (Cloud Firestore)
- Real-time data streams and listeners

Services are platform-aware: Firebase fails gracefully on unsupported platforms (e.g., Linux desktop).

### Directory Structure
```
lib/
├── main.dart                    # App entry point, MultiProvider setup
├── firebase_options.dart        # Generated Firebase config
├── models/
│   ├── transaction.dart         # Transaction model with Firestore serialization
│   ├── transaction_filter.dart  # Filter criteria for queries
│   └── user.dart               # User profile model
├── screens/
│   ├── login_screen.dart       # Auth UI
│   ├── main_navigation_screen.dart  # Root navigation (scaffold with bottom nav)
│   ├── home_screen.dart        # Dashboard view
│   ├── add_transaction_screen.dart  # New/edit transaction form
│   ├── transaction_list_screen.dart # Filterable transaction list
│   └── settings_screen.dart    # User settings
├── services/
│   ├── firebase_service.dart   # Firebase auth, Firestore operations
│   ├── firebase_config.dart    # Firebase credentials (DO NOT COMMIT)
│   ├── auth_provider.dart      # Auth state + UI logic
│   ├── transaction_provider.dart # Transaction state + Firestore sync
│   ├── ai_service.dart         # AI API integration
│   ├── ai_config.dart          # AI service configuration
│   └── logging_service.dart    # Centralized logging setup
└── utils/
    ├── category_constants.dart # Income/expense categories
    ├── input_formatters.dart   # TextField formatters (thousands separator)
    └── currency_utils.dart     # Currency formatting
└── widgets/                    # Reusable UI components
```

### Key Models & Enums
- **Transaction**: Immutable data class with Firebase serialization (`toMap()`, `fromMap()`)
  - `TransactionType`: `income | expense`
  - `FilterType`: `month | year`
- **TransactionFilter**: Criteria object for querying (userId, type, month, year, category)

### Data Flow Pattern
1. **Screens** call `Provider.of<Provider>()` or `context.watch()` to access state
2. **Providers** expose methods like `addTransaction()`, `loadTransactions()`, `setFilter()`
3. **Methods** call **FirebaseService** for database operations
4. **FirebaseService** streams data back via `StreamProvider` or listener callbacks
5. **Providers** notify listeners via `notifyListeners()`, triggering rebuilds

Example:
```dart
// In widget
Consumer<TransactionProvider>(
  builder: (context, provider, _) {
    return ListView(
      children: provider.transactions.map((t) => TransactionTile(t)).toList(),
    );
  },
)
```

## Key Conventions

### Dart/Flutter Style
- Use `const` for widget constructors and compile-time constants
- Favor `StreamProvider` over `FutureBuilder` for reactive data
- Always dispose listeners and subscriptions in `dispose()` method
- Use `late` final for lazy-initialized dependencies (see FirebaseService)

### Firebase Patterns
- **Singleton pattern** for FirebaseService: Ensures only one instance exists
- **Platform-aware initialization**: Firebase calls wrapped in try-catch for graceful degradation
- **Timestamp conversion**: Use `Timestamp.fromDate()` when writing, `toDate()` when reading
- **Document IDs**: Transactions use `uuid` package (`Uuid().v4()`) for IDs
- **Real-time streams**: AuthProvider observes `authStateChanges` stream; TransactionProvider listens to Firestore snapshots

### Testing
- **Regression tests** in `test/regression_test.dart`: Verify bug fixes and edge cases (e.g., rapid input handling, currency formatting)
- **Widget tests** in `test/widget_test.dart`: UI component verification
- Tests use `group()` for organization and `setUp()` for shared initialization

### Categories System
Categories are defined in `lib/utils/category_constants.dart`:
- Income categories: `salary`, `bonus`, `freelance`, `investment`, `other`
- Expense categories: `food`, `transport`, `utilities`, `entertainment`, `health`, `shopping`, `other`

Use these constants consistently—don't hardcode category strings.

### Input Validation
- The `ThousandsSeparatorInputFormatter` in `lib/utils/input_formatters.dart` formats currency input
- Must handle rapid consecutive inputs without crashing (verified by regression tests)

### Environment & Configuration
- **DevContainer**: Docker setup in `.devcontainer/devcontainer.json` with pre-installed Flutter and extensions
- **Firebase config**: Store credentials in `lib/services/firebase_config.dart` (generated, not committed)
- **AI service**: API configuration in `lib/services/ai_config.dart`
- **Logging**: Use `logging` package via `LoggingService.setupLogging()` in main

### Git Workflow
- GitHub Actions workflow in `.github/workflows/dart.yml` builds iOS releases
- Supports flutter builds for all platforms via `flutter build <target>`

## Common Tasks

### Adding a New Service
1. Create `lib/services/new_service.dart`
2. Implement singleton pattern (private constructor, static instance)
3. Initialize in `main.dart` if it needs app-level setup
4. Consider whether it needs a corresponding Provider for UI state

### Adding a New Screen
1. Create `lib/screens/new_screen.dart` extending `StatefulWidget` or `StatelessWidget`
2. Use `Consumer<ProviderName>` to access state
3. Add route in `main_navigation_screen.dart` if it's a top-level screen
4. Create a tile/card in home_screen.dart if applicable

### Adding Tests
1. Place unit tests in `test/` with `_test.dart` suffix
2. Use `group()` to organize tests logically
3. For regression tests, add to `test/regression_test.dart`
4. Run `flutter test` to verify

### Modifying Transaction Logic
1. Update `Transaction` model in `lib/models/transaction.dart` if schema changes
2. Update serialization methods: `toMap()` and `fromMap()`
3. Update `FirebaseService` methods if Firestore operations change
4. Update `TransactionProvider` to notify listeners
5. Add regression test if fixing a bug

### Handling Firebase Credential Updates
1. Update `lib/services/firebase_config.dart` with new credentials
2. **Do not commit credentials to git** (use `.gitignore`)
3. In CI/CD: Pass credentials via environment variables or secrets
4. For local development: Create a local `firebase_config.dart` file

## Debugging Tips

### Hot Reload Issues
- Use `flutter run -v` for verbose output
- Full restart: Press `R` instead of `r`
- If app crashes on reload, restart with `flutter run`

### Firebase Connection Issues
- Verify `firebase_config.dart` has correct credentials
- Check Firestore rules in `firestore.rules`
- Use Firebase console to verify database state
- Check logs: `flutter logs` for runtime errors

### Platform-Specific Issues
- **Linux desktop**: Firebase not supported; app runs with limited functionality
- **Web**: Use DevTools in browser console for debugging
- **Mobile**: Use Android Studio/Xcode debuggers for platform-specific issues

### Testing Locally
- Use `flutter run -d web` for fastest iteration
- Use emulator/simulator for platform-specific UI testing
- Use `flutter test --coverage` to identify untested code paths

## Dependencies Overview

| Package | Purpose |
|---------|---------|
| `firebase_core` | Firebase initialization |
| `firebase_auth` | User authentication |
| `cloud_firestore` | Cloud database |
| `firebase_database` | Real-time database (if needed) |
| `provider` | State management |
| `intl` | Date/time + number formatting |
| `fl_chart` | Charts/graphs for analytics |
| `speech_to_text` | Voice input for transactions |
| `permission_handler` | Request OS permissions |
| `uuid` | Generate unique IDs |
| `shared_preferences` | Local device storage |
| `logging` | Structured logging |
| `http` | HTTP requests (for AI service) |
