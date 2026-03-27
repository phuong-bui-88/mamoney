import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mamoney/models/transaction.dart' as models;
import 'package:mamoney/models/user.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  static bool _isInitialized = false;

  factory FirebaseService() {
    return _instance;
  }

  FirebaseService._internal();

  late final auth.FirebaseAuth _firebaseAuth;
  late final FirebaseFirestore _firestore;
  late final FirebaseStorage _storage;

  bool get isInitialized => _isInitialized;

  void initialize() {
    if (!_isInitialized) {
      _firebaseAuth = auth.FirebaseAuth.instance;
      _firestore = FirebaseFirestore.instance;
      _storage = FirebaseStorage.instance;
      _isInitialized = true;
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
      final transactionWithId = transaction.copyWith(id: id, userId: uid);

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
      final txs = snapshot.docs
          .map((doc) => models.Transaction.fromMap(doc.data()))
          .toList();
      return txs;
    });
  }

  // Delete transaction
  Future<void> deleteTransaction(String transactionId) async {
    if (!_isInitialized) {
      return;
    }
    try {
      // Fetch transaction to check for image
      final doc =
          await _firestore.collection('transactions').doc(transactionId).get();
      if (doc.exists && doc.data() != null) {
        final transaction = models.Transaction.fromMap(doc.data()!);
        // Delete image from storage if it exists
        if (transaction.imageUrl != null && transaction.imageUrl!.isNotEmpty) {
          await deleteTransactionImage(transaction.imageUrl!);
        }
      }
      // Delete the transaction document
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

  // Upload transaction image - SAVE LOCALLY
  Future<String> uploadTransactionImage(
    dynamic imageFile, // Can be File (mobile) or null
    String userId,
    String transactionId, {
    Uint8List? imageBytes, // Use this for web or when File not available
  }) async {
    if (currentUser == null) {
      throw Exception('User not authenticated');
    }
    try {
      // Get image bytes if not provided
      Uint8List bytesToStore = imageBytes ?? Uint8List(0);

      if (bytesToStore.isEmpty && imageFile != null && imageFile is File) {
        bytesToStore = await imageFile.readAsBytes();
      }

      if (bytesToStore.isEmpty) {
        throw Exception('No valid image data provided');
      }

      // Convert bytes to base64 for local storage
      final base64Image = base64Encode(bytesToStore);

      // Storage key: "invoice_image_<transactionId>"
      final storageKey = 'invoice_image_$transactionId';

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKey, base64Image);

      // Return a special marker to identify local storage images
      final imageUrl = 'local://$storageKey';

      return imageUrl;
    } catch (e) {
      rethrow;
    }
  }

  // Delete transaction image from storage
  Future<void> deleteTransactionImage(String imageUrl) async {
    try {
      // Check if it's a local image
      if (imageUrl.startsWith('local://')) {
        final storageKey = imageUrl.replaceFirst('local://', '');
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(storageKey);
        return;
      }

      // Otherwise try to delete from Firebase (backward compatibility)
      if (_isInitialized) {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
      }
    } catch (e) {
      // Don't rethrow - allow transaction deletion even if image cleanup fails
    }
  }

  // Get local image as bytes (NEW METHOD)
  Future<Uint8List?> getLocalImage(String imageUrl) async {
    if (!imageUrl.startsWith('local://')) {
      return null; // Not a local image
    }

    final storageKey = imageUrl.replaceFirst('local://', '');
    final prefs = await SharedPreferences.getInstance();
    final base64String = prefs.getString(storageKey);

    if (base64String == null) {
      return null;
    }

    return base64Decode(base64String);
  }
}
