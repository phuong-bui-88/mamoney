import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction_sync_status.dart';

// Chat Message Types
enum ChatMessageType { user, assistant }

// Chat Message Model
class ChatMessage {
  final ChatMessageType type;
  final String text;
  final TransactionSyncStatus? syncStatus;

  ChatMessage({
    required this.type,
    required this.text,
    this.syncStatus,
  });
}

// Chat Bubble Widget
class ChatBubbleWidget extends StatelessWidget {
  final ChatMessage message;

  const ChatBubbleWidget({
    required this.message,
    super.key,
  });

  String _getSyncStatusText() {
    switch (message.syncStatus) {
      case TransactionSyncStatus.pending:
        return '❌ Not saved';
      case TransactionSyncStatus.syncing:
        return '⏳ Syncing...';
      case TransactionSyncStatus.failed:
        return '⚠️ Failed to save';
      case TransactionSyncStatus.synced:
      case null:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == ChatMessageType.user;
    final syncStatusText = _getSyncStatusText();
    final showSyncStatus = syncStatusText.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          // Show sync status below message if needed
          if (showSyncStatus)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 36),
              child: Text(
                syncStatusText,
                style: TextStyle(
                  color: message.syncStatus == TransactionSyncStatus.pending
                      ? Colors.orange[700]
                      : message.syncStatus == TransactionSyncStatus.syncing
                          ? Colors.blue[700]
                          : Colors.red[700],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
