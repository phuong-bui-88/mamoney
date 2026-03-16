import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

/// Represents a single message in the chat conversation.
class ChatMessage {
  final String id;
  final String content;
  final String sender; // 'user' or 'assistant'
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.timestamp,
  });

  /// Convert ChatMessage to a JSON map for storage (Firestore or SharedPreferences)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'sender': sender,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Create ChatMessage from a JSON map
  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    // Consider logging if critical fields are missing
    if (map['id'] == null || map['content'] == null) {
      // Log a warning about missing fields (optional)
      Logger('ChatMessage')
          .warning('Missing critical fields in chat message map: $map');
    }

    return ChatMessage(
      id: map['id'] ?? '',
      content: map['content'] ?? '',
      sender: map['sender'] ?? 'user',
      timestamp: (map['timestamp'] is Timestamp)
          ? (map['timestamp'] as Timestamp).toDate()
          : DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }

  /// Check if this message is from the user
  bool get isUserMessage => sender == 'user';

  /// Check if this message is from the assistant (AI)
  bool get isAssistantMessage => sender == 'assistant';

  @override
  String toString() =>
      'ChatMessage(id: $id, sender: $sender, content: $content)';
}
