import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mamoney/firebase_options.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/auth_provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/screens/login_screen.dart';
// ...existing code...
import 'package:logging/logging.dart';
import 'package:mamoney/services/logging_service.dart';
import 'package:mamoney/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase only on supported platforms

  // Set up logging using the reusable service
  setupLogging();
  final log = Logger('Main');

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize Firebase service after Firebase is set up
    FirebaseService().initialize();
  } catch (e) {
    // Firebase not supported on this platform (e.g., Linux desktop)
    // The app will run without Firebase functionality
    log.warning('Firebase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<TransactionProvider>(
          create: (_) => TransactionProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'MaMoney1',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isAuthenticated) {
          // Use MainNavigationScreen as the root after login
          return const MainNavigationScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
