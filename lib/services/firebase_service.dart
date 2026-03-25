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
      try {
        _firebaseAuth = auth.FirebaseAuth.instance;
        _firestore = FirebaseFirestore.instance;
        _storage = FirebaseStorage.instance;
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
      print('[DEBUG] No current user. Returning empty transaction stream.');
      return Stream.value([]);
    }

    print('[DEBUG] Fetching transactions for userId: \'${currentUser!.uid}\'');
    return _firestore
        .collection('transactions')
        .where('userId', isEqualTo: currentUser!.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
      final txs = snapshot.docs
          .map((doc) => models.Transaction.fromMap(doc.data()))
          .toList();
      print('[DEBUG] Fetched transactions count: \'${txs.length}\'');
      for (final tx in txs) {
        print('[DEBUG] Transaction: \'${tx.toString()}\'');
      }
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
      final doc = await _firestore.collection('transactions').doc(transactionId).get();
      if (doc.exists && doc.data() != null) {
        final transaction = models.Transaction.fromMap(doc.data()!);
        // Delete image from storage if it exists
        if (transaction.imageUrl != null && transaction.imageUrl!.isNotEmpty) {
          try {
            await deleteTransactionImage(transaction.imageUrl!);
          } catch (e) {
            print('Error deleting transaction image: $e');
            // Don't rethrow - still delete the transaction even if image cleanup fails
          }
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
      print('DEBUG uploadTransactionImage: Starting local upload for user: $userId, transactionId: $transactionId');
      print('DEBUG uploadTransactionImage: imageBytes provided: ${imageBytes != null}, imageFile type: ${imageFile.runtimeType}');
      
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
      
      print('DEBUG uploadTransactionImage: Image saved locally. Storage key: $storageKey, Size: ${bytesToStore.length} bytes');
      
      // Return a special marker to identify local storage images
      final imageUrl = 'local://$storageKey';
      print('DEBUG uploadTransactionImage: Returning local image URL: $imageUrl');
      
      return imageUrl;
    } catch (e) {
      print('ERROR uploadTransactionImage: Exception - $e');
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
        print('DEBUG deleteTransactionImage: Deleted local image with key: $storageKey');
        return;
      }
      
      // Otherwise try to delete from Firebase (backward compatibility)
      if (_isInitialized) {
        final ref = _storage.refFromURL(imageUrl);
        await ref.delete();
        print('DEBUG deleteTransactionImage: Deleted Firebase image');
      }
    } catch (e) {
      print('Error deleting transaction image: $e');
      // Don't rethrow - allow transaction deletion even if image cleanup fails
    }
  }

  // Get local image as bytes (NEW METHOD)
  Future<Uint8List?> getLocalImage(String imageUrl) async {
    try {
      if (!imageUrl.startsWith('local://')) {
        return null; // Not a local image
      }
      
      final storageKey = imageUrl.replaceFirst('local://', '');
      final prefs = await SharedPreferences.getInstance();
      final base64String = prefs.getString(storageKey);
      
      if (base64String == null) {
        print('DEBUG getLocalImage: Image not found for key: $storageKey');
        return null;
      }
      
      final imageBytes = base64Decode(base64String);
      print('DEBUG getLocalImage: Retrieved image bytes from local storage. Key: $storageKey, Size: ${imageBytes.length}');
      return imageBytes;
    } catch (e) {
      print('ERROR getLocalImage: Exception - $e');
      return null;
    }
  }
}
