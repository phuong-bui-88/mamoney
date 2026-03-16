import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';

/// Manages chat conversation state and persistence.
/// Handles loading, saving, and updating chat history across sessions.
class ChatProvider extends ChangeNotifier {
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String _error = '';

  // Firebase references
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _userId;

  // SharedPreferences for local-only fallback
  SharedPreferences? _prefs;

  /// List of chat messages in chronological order (oldest first)
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  /// Whether messages are currently being loaded
  bool get isLoading => _isLoading;

  /// Error message if any operation failed
  String get error => _error;

  /// Initialize the provider with a user ID (for Firestore storage)
  Future<void> init(String? userId) async {
    _userId = userId;
    _prefs = await SharedPreferences.getInstance();
    await loadChatHistory();
  }

  /// Load chat history from persistence (Firestore or local)
  Future<void> loadChatHistory() async {
    _isLoading = true;
    _error = '';
    notifyListeners();

    try {
      if (_userId != null) {
        // Try loading from Firestore
        final snapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('chat_messages')
            .orderBy('timestamp', descending: false)
            .get();

        _messages = snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data()))
            .toList();
      } else {
        // Fallback to SharedPreferences (local-only)
        _messages = _loadFromSharedPreferences();
      }
    } catch (e) {
      _error = 'Failed to load chat history: $e';
      // Try SharedPreferences as fallback
      _messages = _loadFromSharedPreferences();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load chat messages from SharedPreferences
  List<ChatMessage> _loadFromSharedPreferences() {
    try {
      final messagesJson = _prefs?.getStringList('chat_messages') ?? [];
      return messagesJson
          .map((jsonStr) {
            try {
              final jsonData = _parseJson(jsonStr);
              return ChatMessage.fromMap(jsonData);
            } catch (_) {
              return null;
            }
          })
          .whereType<ChatMessage>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Add a new message to the chat (both locally and to persistence)
  Future<void> addMessage(String content, String sender) async {
    try {
      _error = '';

      final message = ChatMessage(
        id: const Uuid().v4(),
        content: content,
        sender: sender,
        timestamp: DateTime.now(),
      );

      _messages.add(message);

      // Save to Firestore if user is authenticated
      if (_userId != null) {
        await _firestore
            .collection('users')
            .doc(_userId)
            .collection('chat_messages')
            .doc(message.id)
            .set(message.toMap());
      } else {
        // Save to SharedPreferences as fallback
        await _saveToSharedPreferences();
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to save message: $e';
      notifyListeners();
    }
  }

  /// Save messages to SharedPreferences
  Future<void> _saveToSharedPreferences() async {
    try {
      final messagesJson =
          _messages.map((msg) => _jsonEncode(msg.toMap())).toList();
      await _prefs?.setStringList('chat_messages', messagesJson);
    } catch (e) {
      _error = 'Failed to save to local storage: $e';
    }
  }

  /// Clear all chat history
  Future<void> clearHistory() async {
    try {
      _error = '';
      _messages.clear();

      if (_userId != null) {
        // Clear from Firestore
        final snapshot = await _firestore
            .collection('users')
            .doc(_userId)
            .collection('chat_messages')
            .get();

        for (final doc in snapshot.docs) {
          await doc.reference.delete();
        }
      } else {
        // Clear from SharedPreferences
        await _prefs?.remove('chat_messages');
      }

      notifyListeners();
    } catch (e) {
      _error = 'Failed to clear history: $e';
      notifyListeners();
    }
  }

  /// Simple JSON serialization helper (avoids jsonEncode dependency)
  static String _jsonEncode(Map<String, dynamic> map) {
    // For simple flat maps, convert to string representation
    final pairs = map.entries.map((e) {
      final key = _escapeString(e.key);
      final value = _escapeString(e.value.toString());
      return '"$key":"$value"';
    }).join(',');
    return '{$pairs}';
  }

  /// Simple JSON parsing helper
  static Map<String, dynamic> _parseJson(String jsonStr) {
    final map = <String, dynamic>{};
    // Remove outer braces
    final content = jsonStr.substring(1, jsonStr.length - 1);
    if (content.isEmpty) return map;

    final pairs = content.split(',');
    for (final pair in pairs) {
      final colonIdx = pair.lastIndexOf(':');
      if (colonIdx > 0) {
        final key = _unescapeString(
            pair.substring(0, colonIdx).trim().replaceAll('"', ''));
        final value = _unescapeString(
            pair.substring(colonIdx + 1).trim().replaceAll('"', ''));
        map[key] = value;
      }
    }
    return map;
  }

  static String _escapeString(String str) {
    return str.replaceAll('\\', '\\\\').replaceAll('"', '\\"');
  }

  static String _unescapeString(String str) {
    return str.replaceAll('\\"', '"').replaceAll('\\\\', '\\');
  }
}
