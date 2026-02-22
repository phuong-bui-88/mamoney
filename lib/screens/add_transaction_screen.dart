import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/utils/currency_utils.dart';

enum ChatMessageType { user, assistant }

class ChatMessage {
  final ChatMessageType type;
  final String text;

  ChatMessage({required this.type, required this.text});
}

class TransactionRecord {
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final TransactionType type;
  final String userMessage;

  TransactionRecord({
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.type,
    required this.userMessage,
  });
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TextEditingController _aiMessageController;
  late ScrollController _scrollController;

  // Category definitions
  final List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Investment',
    'Gift',
    'Other'
  ];

  final List<String> expenseCategories = [
    '🏠 Housing',
    '🍚 Food',
    '🚗 Transportation',
    '💡 Utilities',
    '🏥 Healthcare'
  ];

  final List<ChatMessage> _chatMessages = [];
  final List<TransactionRecord> _completedTransactions = [];
  bool _isParsingAI = false;
  bool _isSavingTransaction = false;

  late TransactionType _selectedType;
  String _selectedCategory = '';
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
    _aiMessageController = TextEditingController();
    _scrollController = ScrollController();
    _selectedType = TransactionType.expense;
    _selectedCategory = expenseCategories[0];
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _aiMessageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addChatMessage(String text, ChatMessageType type) {
    setState(() {
      _chatMessages.add(ChatMessage(type: type, text: text));
    });
    _scrollToBottom();
  }

  // _handleAddTransaction was unused and has been removed.

  Future<void> _parseAIMessage() async {
    // Prevent duplicate submissions
    if (_isSavingTransaction) {
      return;
    }

    final aiMessage = _aiMessageController.text.trim();

    if (aiMessage.isEmpty) {
      _addChatMessage('Please enter a message', ChatMessageType.assistant);
      return;
    }

    // Store the message for later (don't add to chat yet)
    final userInputMessage = aiMessage;
    _aiMessageController.clear();

    setState(() {
      _isParsingAI = true;
      _isSavingTransaction = true;
    });

    try {
      final result = await AIService.parseTransactionMessage(userInputMessage);

      print('=== DEBUG: AI Result 123 ===');
      print('Result type: ${result.runtimeType}');
      print('Result keys: ${result.keys.toList()}');
      print('Full result: $result');

      if (result.containsKey('error')) {
        print('Error found: ${result['error']}');
      } else {
        print('Description: ${result['description']}');
        print('Amount: ${result['amount']}');
        print('Category: ${result['category'] ?? "NOT PROVIDED"}');
        print('Type: ${result['type'] ?? "NOT PROVIDED"}');
      }
      print('======================');

      if (!mounted) return;

      if (result.containsKey('error')) {
        _addChatMessage(
          'Error: ${result['error']}',
          ChatMessageType.assistant,
        );
      } else {
        final description = result['description'] ?? '';
        final amount = result['amount'] ?? '';
        final category = result['category'] ?? _selectedCategory;
        final type = result['type'] ?? 'expense';

        // Update selected type based on AI result
        if (type.toLowerCase() == 'income') {
          _selectedType = TransactionType.income;
        } else {
          _selectedType = TransactionType.expense;
        }

        print('Detected type from AI: $type -> $_selectedType');

        if (description.isNotEmpty && amount.isNotEmpty) {
          // Parse amount for database storage
          final cleanAmount = amount.replaceAll(',', '');
          var parsedAmount = double.tryParse(cleanAmount) ?? 0;

          // Ensure user is signed in
          final uid = FirebaseService().currentUser?.uid;
          if (uid == null) {
            _addChatMessage(
              'You must be signed in to add a transaction',
              ChatMessageType.assistant,
            );
            return;
          }

          // Validate category
          final categories = _selectedType == TransactionType.income
              ? incomeCategories
              : expenseCategories;
          final validCategory =
              categories.contains(category) ? category : _selectedCategory;

          // Create transaction object for database
          final transaction = Transaction(
            id: '',
            userId: uid,
            description: description,
            amount: parsedAmount,
            type: _selectedType,
            category: validCategory,
            date: _selectedDate,
            createdAt: DateTime.now(),
            userMessage: userInputMessage, // Preserve the original user input
          );

          // Save to database
          final provider = context.read<TransactionProvider>();
          await provider.addTransaction(transaction);

          if (provider.error != null) {
            _addChatMessage(
              'Failed to save transaction: ${provider.error}',
              ChatMessageType.assistant,
            );
            return;
          }

          // Save completed transaction with the user message
          setState(() {
            _completedTransactions.add(
              TransactionRecord(
                description: description,
                amount: parsedAmount,
                category: validCategory,
                date: _selectedDate,
                type: _selectedType,
                userMessage: userInputMessage,
              ),
            );
          });

          // Clear controllers for next transaction
          _descriptionController.clear();
          _amountController.clear();
          _scrollToBottom();
        } else {
          if (description.isNotEmpty) {
            _descriptionController.text = description;
          }
          if (amount.isNotEmpty) {
            // Format the amount with comma separators before setting it
            try {
              final numValue = double.parse(amount);
              final formatter = NumberFormat('#,##0', 'en_US');
              final formatted = formatter.format(numValue);
              _amountController.text = formatted;
            } catch (e) {
              _amountController.text = amount;
            }
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isParsingAI = false;
          _isSavingTransaction = false;
        });
      }
    }
  }

  Widget _buildChatBubble(ChatMessage message) {
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

  Widget _buildCompletedTransactionCard(TransactionRecord record) {
    // Select emoji from category (extract emoji before space)
    String getEmoji() {
      if (record.category.isNotEmpty) {
        // Category format: "🍚 Food", extract part before space
        final spaceIndex = record.category.indexOf(' ');
        if (spaceIndex > 0) {
          return record.category.substring(0, spaceIndex).trim();
        }
      }
      // Fallback to default
      if (record.type == TransactionType.expense) return '🛒';
      return '💰';
    }

    final formatted = formatCurrency(record.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200] ?? Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recorded: ${record.type == TransactionType.expense ? 'Expense' : 'Income'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM dd').format(record.date),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3E5FC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      getEmoji(),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.description,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatted,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: record.type == TransactionType.expense
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionCard() {
    final amountStr = _amountController.text.trim();
    final cleanAmountStr = amountStr.replaceAll(',', '');
    final amount = double.tryParse(cleanAmountStr) ?? 0;

    // Select emoji from category (extract emoji before space)
    String getEmoji() {
      if (_selectedCategory.isNotEmpty) {
        // Category format: "🍚 Food", extract part before space
        final spaceIndex = _selectedCategory.indexOf(' ');
        if (spaceIndex > 0) {
          return _selectedCategory.substring(0, spaceIndex).trim();
        }
      }
      // Fallback to default
      if (_selectedType == TransactionType.expense) return '🛒';
      return '💰';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[200] ?? Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recorded: ${_selectedType == TransactionType.expense ? 'Expense' : 'Income'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM dd').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Content
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFB3E5FC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      getEmoji(),
                      style: const TextStyle(fontSize: 32),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _descriptionController.text.isNotEmpty
                            ? _descriptionController.text
                            : 'No description',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedCategory,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  formatCurrency(amount),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _selectedType == TransactionType.expense
                        ? Colors.red
                        : Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = _selectedType == TransactionType.income
        ? incomeCategories
        : expenseCategories;

    if (!categories.contains(_selectedCategory)) {
      _selectedCategory = categories.first;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Transaction',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Chat Messages Area with Completed Transactions
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount:
                  _chatMessages.length + (_completedTransactions.length * 2),
              itemBuilder: (context, index) {
                // All chat messages first
                if (index < _chatMessages.length) {
                  return _buildChatBubble(_chatMessages[index]);
                }

                // All completed transactions (each has user message + transaction card)
                int remaining = index - _chatMessages.length;
                int transNum = remaining ~/ 2;
                // Order so newest transactions appear at the bottom

                if (remaining % 2 == 0) {
                  // Show user message for this transaction
                  return _buildChatBubble(
                    ChatMessage(
                      type: ChatMessageType.user,
                      text: _completedTransactions[transNum].userMessage,
                    ),
                  );
                } else {
                  // Show transaction card for this transaction
                  return _buildCompletedTransactionCard(
                      _completedTransactions[transNum]);
                }
              },
            ),
          ),
          // Current in-progress transaction (if exists)
          if (_descriptionController.text.isNotEmpty ||
              _amountController.text.isNotEmpty)
            SingleChildScrollView(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  children: [
                    _buildChatBubble(
                      ChatMessage(
                        type: ChatMessageType.user,
                        text: _aiMessageController.text.isNotEmpty
                            ? _aiMessageController.text
                            : '',
                      ),
                    ),
                    _buildTransactionCard(),
                  ],
                ),
              ),
            ),
          // Suggested Input Area
          if (_descriptionController.text.isNotEmpty ||
              _amountController.text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'dinner 50, shopping 200',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          // Input Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200] ?? Colors.grey),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick entry input
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100] ?? Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey[300] ?? Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _aiMessageController,
                          decoration: InputDecoration(
                            hintText: 'e.g., "va xe 30k"',
                            hintStyle: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: 1,
                          enabled: !_isParsingAI,
                          onSubmitted: _isParsingAI
                              ? null
                              : (_) {
                                  _parseAIMessage();
                                },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: IconButton(
                        onPressed: _isParsingAI
                            ? null
                            : () {
                                _parseAIMessage();
                              },
                        icon: const Icon(
                          Icons.send,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 12),
                // Set custom rules
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Set custom rules',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
