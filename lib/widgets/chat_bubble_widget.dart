import 'package:flutter/material.dart';

// Chat Message Types
enum ChatMessageType { user, assistant }

// Chat Message Model
class ChatMessage {
  final ChatMessageType type;
  final String text;

  ChatMessage({
    required this.type,
    required this.text,
  });
}

// Chat Bubble Widget
class ChatBubbleWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatBubbleWidget({
    required this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == ChatMessageType.user;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 16)),
              ),
            ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? const Color(0xFFE0E7FF) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: Colors.grey[900],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
          if (isUser)
            Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF6B5B95),
              ),
              child: const Center(
                child: Text('👤', style: TextStyle(fontSize: 16)),
              ),
            ),
        ],
      ),
    );
  }
}
