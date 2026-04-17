import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../services/ai_service.dart';
import '../services/chat_provider.dart';
import '../services/transaction_embeddings.dart';
import '../services/transaction_provider.dart';

/// AskScreen - Chat interface for asking financial questions
/// Users can ask about their transactions or get general financial advice
/// The AI has access to their transaction history via RAG (Retrieval-Augmented Generation)
class AskScreen extends StatefulWidget {
  const AskScreen({super.key});

  @override
  State<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends State<AskScreen> {
  late TextEditingController _messageController;
  late ScrollController _scrollController;
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Scroll to the bottom of the chat when new messages arrive
  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Send a message and get AI response
  Future<void> _sendMessage(String message) async {
    if (message.trim().isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final transactionProvider = context.read<TransactionProvider>();

    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      // Add user message to chat
      await chatProvider.addMessage(message, 'user');
      if (!mounted) return;

      _messageController.clear();
      _scrollToBottom();

      // Get transaction context using embeddings
      final embeddings = TransactionEmbeddings();
      final transactionContext = await embeddings.getRelevantTransactionContext(
        message,
        transactionProvider.transactions,
      );
      if (!mounted) return;

      // Ask AI with RAG context
      final aiResponse = await AIService.askFinancialQuestion(
        message,
        transactionContext,
      );
      if (!mounted) return;

      // Add AI response to chat
      await chatProvider.addMessage(aiResponse, 'assistant');
      if (!mounted) return;

      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error getting response: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Ask Financial AI'),
        actions: [
          Consumer<TransactionProvider>(
            builder: (context, transactionProvider, _) {
              return IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () {
                  if (transactionProvider.filterType == FilterType.month) {
                    _selectMonthYear(context, transactionProvider);
                  } else {
                    _selectYear(context, transactionProvider);
                  }
                },
                tooltip: 'Select date',
              );
            },
          ),
          // Clear history button
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear chat history',
            onPressed: () => _showClearConfirmation(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                final messages = chatProvider.messages;

                if (messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No messages yet',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Ask me about your finances!',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey[400],
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Show only the 10 most recent messages include ask and answer
                final displayMessages = messages.length > 10
                    ? messages.sublist(messages.length - 10)
                    : messages;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: displayMessages.length,
                  itemBuilder: (context, index) {
                    final message = displayMessages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),

          // Error message
          if (_error.isNotEmpty)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                border: Border.all(color: Colors.red[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _error,
                      style: TextStyle(color: Colors.red[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

          // Loading indicator
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AI is thinking...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

          // Input field
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      hintText: 'Ask about your finances...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (value) => _sendMessage(value),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton(
                  mini: true,
                  onPressed: _isLoading
                      ? null
                      : () => _sendMessage(_messageController.text),
                  child: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build a single message bubble
  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUserMessage;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: isUser ? Theme.of(context).primaryColor : Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.content,
              style: TextStyle(
                color: isUser ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              _formatTime(message.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format timestamp for display
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${dateTime.month}/${dateTime.day}';
    }
  }

  /// Show confirmation dialog for clearing chat history
  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat History'),
        content: const Text(
            'Are you sure you want to delete all messages? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final chatProvider = context.read<ChatProvider>();

              navigator.pop();
              await chatProvider.clearHistory();

              if (mounted) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Chat history cleared')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _selectMonthYear(BuildContext context, TransactionProvider provider) {
    final currentDate = provider.selectedDate;
    int selectedMonth = currentDate.month;
    int selectedYear = currentDate.year;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with selected month and year
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_getMonthName(selectedMonth)} $selectedYear',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Year with controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.expand_less,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  selectedYear--;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            Text(
                              selectedYear.toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.expand_more,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  selectedYear++;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content area with month selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Month grid
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 4,
                          childAspectRatio: 1.0,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: List.generate(12, (index) {
                            final month = index + 1;
                            final isSelected = selectedMonth == month;
                            return GestureDetector(
                              onTap: () {
                                provider.setSelectedDate(
                                  DateTime(selectedYear, month),
                                );
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _getMonthName(month).substring(0, 3),
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons (Cancel only - selection auto-submits)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectYear(BuildContext context, TransactionProvider provider) {
    final currentDate = provider.selectedDate;
    int selectedYear = currentDate.year;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with selected year
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          selectedYear.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Navigation buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.expand_less,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  selectedYear--;
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            const Text(
                              'Year',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.expand_more,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  selectedYear++;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Display year with selection button
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                selectedYear.toString(),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  provider.setSelectedDate(
                                    DateTime(selectedYear),
                                  );
                                  Navigator.pop(context);
                                },
                                child: const Text('Select'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _getFormattedDate(FilterType filterType, DateTime date) {
    if (filterType == FilterType.month) {
      return '${_getMonthName(date.month)} ${date.year}';
    } else {
      return date.year.toString();
    }
  }
}
