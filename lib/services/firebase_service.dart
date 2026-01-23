import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mamoney/models/transaction.dart' as models;
import 'package:mamoney/models/user.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  static bool _isInitialized = false;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  late final auth.FirebaseAuth _firebaseAuth;
  late final FirebaseFirestore _firestore;

  bool get isInitialized => _isInitialized;

  void initialize() {
    if (!_isInitialized) {
      try {
        _firebaseAuth = auth.FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
        _isInitialized = true;
      } catch (e) {
        print('Firebase initialization failed: $e');
      }
    }
  }

  // Auth Stream
  Stream<auth.User?> get authStateChanges {
    if (!_isInitialized) {
      return Stream.value(null);
    }
    return _firebaseAuth.authStateChanges();
  }

  // Get current user
  auth.User? get currentUser {
    if (!_isInitialized) {
      return null;
    }
    return _firebaseAuth.currentUser;
  }

  // Sign up with email and password
  Future<auth.User?> signUp(String email, String password) async {
    if (!_isInitialized) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set(
          User(
            id: userCredential.user!.uid,
            email: email,
            displayName: userCredential.user!.displayName,
            createdAt: DateTime.now(),
          ).toMap(),
        );
      }

      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign in with email and password
  Future<auth.User?> signIn(String email, String password) async {
    if (!_isInitialized) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    if (!_isInitialized) {
      return;
    }
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Add transaction
  Future<String> addTransaction(models.Transaction transaction) async {
    if (!_isInitialized) {
      throw Exception('Firebase is not initialized');
    }
    try {
      final id = const Uuid().v4();
      final uid = _firebaseAuth.currentUser?.uid;
      if (uid == null) {
        throw Exception('User not authenticated');
      }
      final transactionWithId =
          transaction.copyWith(id: id, userId: uid);
      
      await _firestore
          .collection('transactions')
          .doc(id)
          .set(transactionWithId.toMap());
      
      return id;
    } catch (e) {
      rethrow;
    }
  }

  // Get transactions for current user
  Stream<List<models.Transaction>> getTransactionsStream() {
    if (currentUser == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => models.Transaction.fromMap(doc.data()))
          .toList();
    });
  }

  // Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    if (!_isInitialized) {
      return;
    }
    try {
      await _firestore.collection('transactions').doc(transactionId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Update transaction
  Future<void> updateTransaction(models.Transaction transaction) async {
    if (!_isInitialized) {
      return;
    }
    try {
      await _firestore
          .collection('transactions')
          .doc(transaction.id)
          .update(transaction.toMap());
    } catch (e) {
      rethrow;
    }
  }

  // Get user data
  Future<User?> getUserData(String userId) async {
    if (!_isInitialized) {
      return null;
    }
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return User.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
