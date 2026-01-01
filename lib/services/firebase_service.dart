import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mamoney/models/transaction.dart' as models;
import 'package:mamoney/models/user.dart';
import 'package:uuid/uuid.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  final auth.FirebaseAuth _firebaseAuth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Auth Stream
  Stream<auth.User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  auth.User? get currentUser => _firebaseAuth.currentUser;

  // Sign up with email and password
  Future<auth.User?> signUp(String email, String password) async {
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
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  // Add transaction
  Future<String> addTransaction(models.Transaction transaction) async {
    try {
      final id = const Uuid().v4();
      final transactionWithId = transaction.copyWith(id: id);
      
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
    try {
      await _firestore.collection('transactions').doc(transactionId).delete();
    } catch (e) {
      rethrow;
    }
  }

  // Update transaction
  Future<void> updateTransaction(models.Transaction transaction) async {
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
