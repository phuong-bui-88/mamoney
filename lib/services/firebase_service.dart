import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mamoney/models/transaction.dart' as models;
import 'package:mamoney/models/user.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal() {
    _initializeLocalStorage();
  }

  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Local storage for mock authentication
  SharedPreferences? _prefs;
  List<Map<String, dynamic>> _localUsers = [];
  List<Map<String, dynamic>> _localTransactions = [];
  String? _currentUserId;
  final StreamController<auth.User?> _authStateController =
      StreamController<auth.User?>.broadcast();

  Future<void> _initializeLocalStorage() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final usersJson = _prefs?.getString('local_users');
      final transactionsJson = _prefs?.getString('local_transactions');
      final currentUserId = _prefs?.getString('current_user_id');

      if (usersJson != null) {
        _localUsers = List<Map<String, dynamic>>.from(json.decode(usersJson));
      }
      if (transactionsJson != null) {
        _localTransactions =
            List<Map<String, dynamic>>.from(json.decode(transactionsJson));
      }
      _currentUserId = currentUserId;
    } catch (e) {
      // If SharedPreferences fails, use in-memory storage
      print('SharedPreferences not available, using in-memory storage: $e');
    }
  }

  Future<void> _saveToStorage() async {
    try {
      await _prefs?.setString('local_users', json.encode(_localUsers));
      await _prefs?.setString(
          'local_transactions', json.encode(_localTransactions));
      await _prefs?.setString('current_user_id', _currentUserId ?? '');
    } catch (e) {
      // Ignore storage errors
    }
  }

  // Check if Firebase is available and properly configured
  Future<bool> get isFirebaseAvailable async {
    try {
      // Try to access Firebase instance - if it fails, Firebase isn't initialized
      _firebaseAuth.app;
      return true;
    } catch (e) {
      // Firebase not initialized on this platform
      print('Firebase not available: $e');
      return false;
    }
  }

  // Auth Stream
  Stream<auth.User?> get authStateChanges async* {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      yield* _firebaseAuth.authStateChanges();
    } else {
      // For local storage, emit current state and listen to changes
      if (_currentUserId != null) {
        final user = _localUsers.firstWhere(
          (user) => user['id'] == _currentUserId,
          orElse: () => {},
        );
        if (user.isNotEmpty) {
          yield MockUser(
            uid: user['id'],
            email: user['email'],
            displayName: user['displayName'],
          );
        }
      } else {
        yield null;
      }

      yield* _authStateController.stream;
    }
  }

  // Get current user
  Future<auth.User?> get currentUser async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      return _firebaseAuth.currentUser;
    } else {
      if (_currentUserId != null) {
        final user = _localUsers.firstWhere(
          (user) => user['id'] == _currentUserId,
          orElse: () => {},
        );
        if (user.isNotEmpty) {
          return MockUser(
            uid: user['id'],
            email: user['email'],
            displayName: user['displayName'],
          );
        }
      }
      return null;
    }
  }

  // Sign up with email and password
  Future<auth.User?> signUp(String email, String password) async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        final userCredential =
            await _firebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Create user document in Firestore
        if (userCredential.user != null) {
          final userData = User(
            id: userCredential.user!.uid,
            email: email,
            displayName:
                userCredential.user!.displayName ?? email.split('@')[0],
            createdAt: DateTime.now(),
          ).toMap();

          try {
            await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .set(userData);
            print('User document created in Firestore');
          } catch (firestoreError) {
            print(
                'Failed to create user document in Firestore: $firestoreError');
            // Re-throw to trigger fallback
            rethrow;
          }
        }

        return userCredential.user;
      } catch (e) {
        // If Firebase fails, fall back to local storage
        print('Firebase signup failed, using local storage: $e');
        return await _signUpLocal(email, password);
      }
    } else {
      return await _signUpLocal(email, password);
    }
  }

  Future<auth.User?> _signUpLocal(String email, String password) async {
    // Check if user already exists
    final existingUser = _localUsers.firstWhere(
      (user) => user['email'] == email,
      orElse: () => {},
    );

    if (existingUser.isNotEmpty) {
      throw Exception('User already exists');
    }

    // Create new user
    final userId = const Uuid().v4();
    final newUser = {
      'id': userId,
      'email': email,
      'password': password, // In a real app, this should be hashed
      'displayName': email.split('@')[0],
      'createdAt': DateTime.now().toIso8601String(),
    };

    _localUsers.add(newUser);
    _currentUserId = userId;
    await _saveToStorage();

    // Create a mock Firebase User object
    final mockUser = MockUser(
      uid: userId,
      email: email,
      displayName: newUser['displayName'],
    );

    // Emit the mock user to the auth state stream
    _authStateController.add(mockUser);

    return mockUser;
  }

  // Sign in with email and password
  Future<auth.User?> signIn(String email, String password) async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        // Verify user document exists in Firestore
        if (userCredential.user != null) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .get();
            if (!userDoc.exists) {
              // User exists in Auth but not in Firestore, create it
              final userData = User(
                id: userCredential.user!.uid,
                email: email,
                displayName:
                    userCredential.user!.displayName ?? email.split('@')[0],
                createdAt: DateTime.now(),
              ).toMap();
              await _firestore
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .set(userData);
              print(
                  'User document created in Firestore (missing after signin)');
            }
          } catch (firestoreError) {
            print(
                'Failed to verify/create user document in Firestore: $firestoreError');
            // Continue anyway - user is authenticated
          }
        }

        return userCredential.user;
      } catch (e) {
        // If Firebase fails, fall back to local storage
        print('Firebase signin failed, using local storage: $e');
        return await _signInLocal(email, password);
      }
    } else {
      return await _signInLocal(email, password);
    }
  }

  Future<auth.User?> _signInLocal(String email, String password) async {
    // Find user by email and password
    final user = _localUsers.firstWhere(
      (user) => user['email'] == email && user['password'] == password,
      orElse: () => {},
    );

    if (user.isEmpty) {
      throw Exception('Invalid email or password');
    }

    _currentUserId = user['id'];
    await _saveToStorage();

    // Create a mock Firebase User object
    final mockUser = MockUser(
      uid: user['id'],
      email: user['email'],
      displayName: user['displayName'],
    );

    // Emit the mock user to the auth state stream
    _authStateController.add(mockUser);

    return mockUser;
  }

  // Sign out
  Future<void> signOut() async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        await _firebaseAuth.signOut();
      } catch (e) {
        // Continue with local sign out even if Firebase fails
      }
    }

    // Always clear local state
    _currentUserId = null;
    await _saveToStorage();
    _authStateController.add(null);
  }

  // Add transaction
  Future<String> addTransaction(models.Transaction transaction) async {
    final firebaseAvailable = await isFirebaseAvailable;
    final id = const Uuid().v4();
    final transactionWithId = transaction.copyWith(id: id);

    if (firebaseAvailable) {
      try {
        await _firestore
            .collection('transactions')
            .doc(id)
            .set(transactionWithId.toMap());
      } catch (e) {
        // Fall back to local storage
        print('Firebase transaction save failed, using local storage: $e');
        await _addTransactionLocal(transactionWithId);
      }
    } else {
      await _addTransactionLocal(transactionWithId);
    }

    return id;
  }

  Future<void> _addTransactionLocal(models.Transaction transaction) async {
    _localTransactions.add(transaction.toMap());
    await _saveToStorage();
  }

  // Get transactions for current user
  Stream<List<models.Transaction>> getTransactionsStream() async* {
    final firebaseAvailable = await isFirebaseAvailable;
    final currentUser = await this.currentUser;

    if (currentUser == null) {
      yield [];
      return;
    }

    if (firebaseAvailable) {
      try {
        yield* _firestore
            .collection('transactions')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('date', descending: true)
            .snapshots()
            .map((snapshot) {
          return snapshot.docs
              .map((doc) => models.Transaction.fromMap(doc.data()))
              .toList();
        });
      } catch (e) {
        // Fall back to local storage
        print('Firebase transaction stream failed, using local storage: $e');
        yield* _getTransactionsStreamLocal(currentUser.uid);
      }
    } else {
      yield* _getTransactionsStreamLocal(currentUser.uid);
    }
  }

  Stream<List<models.Transaction>> _getTransactionsStreamLocal(
      String userId) async* {
    // Filter transactions for current user and sort by date
    final userTransactions = _localTransactions
        .where((t) => t['userId'] == userId)
        .map((t) => models.Transaction.fromMap(t))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    yield userTransactions;

    // Listen for changes to local transactions
    yield* Stream.periodic(const Duration(milliseconds: 100)).map((_) {
      return _localTransactions
          .where((t) => t['userId'] == userId)
          .map((t) => models.Transaction.fromMap(t))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  // Delete transaction
  // Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        await _firestore.collection('transactions').doc(transactionId).delete();
      } catch (e) {
        // Fall back to local storage
        print('Firebase transaction delete failed, using local storage: $e');
        await _deleteTransactionLocal(transactionId);
      }
    } else {
      await _deleteTransactionLocal(transactionId);
    }
  }

  Future<void> _deleteTransactionLocal(String transactionId) async {
    _localTransactions.removeWhere((t) => t['id'] == transactionId);
    await _saveToStorage();
  }

  // Update transaction
  Future<void> updateTransaction(models.Transaction transaction) async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        await _firestore
            .collection('transactions')
            .doc(transaction.id)
            .update(transaction.toMap());
      } catch (e) {
        // Fall back to local storage
        print('Firebase transaction update failed, using local storage: $e');
        await _updateTransactionLocal(transaction);
      }
    } else {
      await _updateTransactionLocal(transaction);
    }
  }

  Future<void> _updateTransactionLocal(models.Transaction transaction) async {
    final index =
        _localTransactions.indexWhere((t) => t['id'] == transaction.id);
    if (index != -1) {
      _localTransactions[index] = transaction.toMap();
      await _saveToStorage();
    }
  }

  // Get user data
  Future<User?> getUserData(String userId) async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        final doc = await _firestore.collection('users').doc(userId).get();
        if (doc.exists) {
          return User.fromMap(doc.data()!);
        }
        return null;
      } catch (e) {
        print('Failed to get user data from Firestore: $e');
        // Fall back to local storage
        return _getUserDataLocal(userId);
      }
    } else {
      return _getUserDataLocal(userId);
    }
  }

  User? _getUserDataLocal(String userId) {
    try {
      final user = _localUsers.firstWhere(
        (user) => user['id'] == userId,
        orElse: () => {},
      );
      if (user.isNotEmpty) {
        return User.fromMap(user);
      }
      return null;
    } catch (e) {
      print('Failed to get user data from local storage: $e');
      return null;
    }
  }

  // Get user data stream for real-time updates
  Stream<User?> getUserDataStream(String userId) async* {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        yield* _firestore
            .collection('users')
            .doc(userId)
            .snapshots()
            .map((doc) {
          if (doc.exists) {
            return User.fromMap(doc.data()!);
          }
          return null;
        });
      } catch (e) {
        print('Failed to get user data stream from Firestore: $e');
        // Fall back to local storage
        yield* _getUserDataStreamLocal(userId);
      }
    } else {
      yield* _getUserDataStreamLocal(userId);
    }
  }

  Stream<User?> _getUserDataStreamLocal(String userId) async* {
    final user = _localUsers.firstWhere(
      (user) => user['id'] == userId,
      orElse: () => {},
    );

    if (user.isNotEmpty) {
      yield User.fromMap(user);
    } else {
      yield null;
    }

    // Listen for changes to local user data
    yield* Stream.periodic(const Duration(milliseconds: 100)).map((_) {
      final user = _localUsers.firstWhere(
        (user) => user['id'] == userId,
        orElse: () => {},
      );
      return user.isNotEmpty ? User.fromMap(user) : null;
    });
  }

  // Update user data
  Future<void> updateUserData(User user) async {
    final firebaseAvailable = await isFirebaseAvailable;

    if (firebaseAvailable) {
      try {
        await _firestore.collection('users').doc(user.id).update(user.toMap());
        print('User data updated in Firestore');
      } catch (e) {
        print('Failed to update user data in Firestore: $e');
        // Fall back to local storage
        await _updateUserDataLocal(user);
      }
    } else {
      await _updateUserDataLocal(user);
    }
  }

  Future<void> _updateUserDataLocal(User user) async {
    final index = _localUsers.indexWhere((u) => u['id'] == user.id);
    if (index != -1) {
      _localUsers[index] = user.toMap();
      await _saveToStorage();
    }
  }
}

// Mock Firebase User class for local storage
class MockUser implements auth.User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final String? displayName;

  MockUser({
    required this.uid,
    this.email,
    this.displayName,
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
