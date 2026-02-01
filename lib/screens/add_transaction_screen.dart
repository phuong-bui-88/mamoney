import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

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

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final text = newValue.text.replaceAll(',', '');

    if (text.isEmpty) {
      return newValue;
    }

    final formatter = NumberFormat('#,##0', 'en_US');
    try {
      final value = double.parse(text);
      final formatted = formatter.format(value);

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    } catch (e) {
      return oldValue;
    }
  }
}

class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _aiMessageController = TextEditingController();
  final _scrollController = ScrollController();

  final TransactionType _selectedType = TransactionType.expense;
  String _selectedCategory = 'Food';
  final DateTime _selectedDate = DateTime.now();
  bool _isParsingAI = false;
  bool _isSavingTransaction = false; // Prevent duplicate submissions

  // Chat messages state
  List<ChatMessage> _chatMessages = [];

  // Completed transactions state
  final List<TransactionRecord> _completedTransactions = [];

  // Speech to text
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _speechText = '';
  String _speechLocale = 'en_US'; // Add support for different locales

  final List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Investment',
    'Gift',
    'Other'
  ];
  final List<String> expenseCategories = [
    'Food',
    'Transport',
    'Entertainment',
    'Utilities',
    'Healthcare',
    'Shopping',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    // Initialize with greeting message
    _chatMessages = [
      ChatMessage(
        type: ChatMessageType.assistant,
        text: "Hello! 👋 Let's start adding your transaction here!",
      ),
    ];
    _loadRecentTransactions();
    _scrollToBottom();

    // Initialize speech to text
    _speech = stt.SpeechToText();
  }

  Future<void> _loadRecentTransactions() async {
    try {
      final provider = context.read<TransactionProvider>();
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 48));

      // Get transactions from the last 48 hours
      final recentTransactions = provider.transactions
          .where((t) => t.date.isAfter(yesterday) && t.date.isBefore(now))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending

      if (recentTransactions.isNotEmpty) {
        // Add a separator message
        _addChatMessage(
          'Conversation last 48 hours',
          ChatMessageType.assistant,
        );

        // Add recent transactions to the completed transactions list
        setState(() {
          for (final transaction in recentTransactions.reversed) {
            final formattedAmt = formatCurrency(transaction.amount);
            _completedTransactions.add(
              TransactionRecord(
                description: transaction.description,
                amount: transaction.amount,
                category: transaction.category,
                date: transaction.date,
                type: transaction.type,
                userMessage: transaction.description,
              ),
            );
          }
        });
      }
    } catch (e) {
      print('Error loading recent transactions: $e');
    }
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

  // Speech to text methods
  void _listen() async {
    if (!_isListening) {
      // Request microphone permission
      var status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _addChatMessage('Microphone permission is required for voice input',
            ChatMessageType.assistant);
        return;
      }

      bool available = await _speech.initialize(
        onStatus: (val) {
          print('onStatus: $val');
          if (val == 'done') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          print('onError: $val');
          setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() {
          _isListening = true;
          _speechText = ''; // Clear previous speech text
        });
        
        // Convert locale format for iOS compatibility
        String localeId = _speechLocale;
        if (Platform.isIOS) {
          // iOS uses locale format like 'en-US' not 'en_US'
          localeId = _speechLocale.replaceAll('_', '-');
        }
        
        _speech.listen(
          onResult: (val) => setState(() {
            _speechText = val.recognizedWords;
            _aiMessageController.text = _speechText;
          }),
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          localeId: localeId,
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
          ),
        );
      } else {
        _addChatMessage('Speech recognition is not available on this device',
            ChatMessageType.assistant);
      }
    }
  }

  Future<void> _handleAddTransaction() async {
    final description = _descriptionController.text.trim();
    final amountStr = _amountController.text.trim();

    if (description.isEmpty || amountStr.isEmpty) {
      _addChatMessage('Please fill in all fields', ChatMessageType.assistant);
      return;
    }

    // Remove commas from the amount string before parsing
    final cleanAmountStr = amountStr.replaceAll(',', '');
    final amount = double.tryParse(cleanAmountStr);
    if (amount == null || amount <= 0) {
      _addChatMessage('Please enter a valid amount', ChatMessageType.assistant);
      return;
    }

    // Ensure user is signed in
    final uid = FirebaseService().currentUser?.uid;
    if (uid == null) {
      _addChatMessage(
        'You must be signed in to add a transaction',
        ChatMessageType.assistant,
      );
      return;
    }

    final transaction = Transaction(
      id: '',
      userId: uid,
      description: description,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      date: _selectedDate,
      createdAt: DateTime.now(),
    );

    final provider = context.read<TransactionProvider>();
    await provider.addTransaction(transaction);

    if (provider.error != null) {
      _addChatMessage(
        'Failed to add transaction: ${provider.error}',
        ChatMessageType.assistant,
      );
      return;
    }

    if (!mounted) return;

    // Show success message with transaction details
    final emoji = _selectedType == TransactionType.expense ? '🛒' : '💰';
    final action =
        _selectedType == TransactionType.expense ? 'spent' : 'earned';
    final formattedAmount = formatCurrency(amount);

    _addChatMessage(
      '$emoji Got it! You\'ve $action $formattedAmount on $description. Great job keeping track! 😊',
      ChatMessageType.assistant,
    );

    // Clear form fields
    _descriptionController.clear();
    _amountController.clear();
    _aiMessageController.clear();
  }

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

      if (!mounted) return;

      if (result.containsKey('error')) {
        _addChatMessage(
          'Error: ${result['error']}',
          ChatMessageType.assistant,
        );
      } else {
        final description = result['description'] ?? '';
        final amount = result['amount'] ?? '';

        if (description.isNotEmpty && amount.isNotEmpty) {
          // Parse amount for database storage
          final cleanAmount = amount.replaceAll(',', '');
          final parsedAmount = double.tryParse(cleanAmount) ?? 0;

          // Ensure user is signed in
          final uid = FirebaseService().currentUser?.uid;
          if (uid == null) {
            _addChatMessage(
              'You must be signed in to add a transaction',
              ChatMessageType.assistant,
            );
            return;
          }

          // Create transaction object for database
          final transaction = Transaction(
            id: '',
            userId: uid,
            description: description,
            amount: parsedAmount,
            type: _selectedType,
            category: _selectedCategory,
            date: _selectedDate,
            createdAt: DateTime.now(),
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
                category: _selectedCategory,
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
                top: BorderSide(color: Colors.grey[200]!),
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
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _aiMessageController,
                          decoration: InputDecoration(
                            hintText: _isListening
                                ? 'Listening... Speak now'
                                : 'e.g., "va xe 30k"',
                            hintStyle: TextStyle(
                              color:
                                  _isListening ? Colors.red : Colors.grey[400],
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
                          onSubmitted:
                              _isParsingAI ? null : (_) => _parseAIMessage(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Voice and camera buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.red : Colors.black,
                      ),
                      child: IconButton(
                        onPressed: _listen,
                        icon: Icon(
                          _isListening ? Icons.mic_off : Icons.mic,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black,
                      ),
                      child: IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Language selector for speech
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.grey[300]!,
                      width: 1,
                    ),
                  ),
                  child: DropdownButton<String>(
                    value: _speechLocale,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: 'en_US',
                        child: Text('English (US)'),
                      ),
                      DropdownMenuItem(
                        value: 'vi_VN',
                        child: Text('Tiếng Việt (Vietnamese)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _speechLocale = value;
                          if (_isListening) {
                            _speech.stop();
                          }
                        });
                        _addChatMessage(
                          'Speech language changed to ${value == 'vi_VN' ? 'Vietnamese' : 'English'}',
                          ChatMessageType.assistant,
                        );
                      }
                    },
                  ),
                ),
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
    // Select emoji based on description
    String getEmoji() {
      final description = record.description.toLowerCase();
      if (description.contains('car') || description.contains('xe'))
        return '🚗';
      if (description.contains('food') || description.contains('eat'))
        return '🍽️';
      if (description.contains('shop')) return '🛍️';
      if (description.contains('movie') ||
          description.contains('entertainment')) return '🎬';
      if (description.contains('game')) return '🎮';
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
          border: Border.all(color: Colors.grey[200]!),
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
                      const SizedBox(height: 4),
                      Text(
                        record.category,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
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

    // Select emoji based on category
    String getEmoji() {
      final description = _descriptionController.text.toLowerCase();
      if (description.contains('car') || description.contains('xe'))
        return '🚗';
      if (description.contains('food') || description.contains('eat'))
        return '🍽️';
      if (description.contains('shop')) return '🛍️';
      if (description.contains('movie') ||
          description.contains('entertainment')) return '🎬';
      if (description.contains('game')) return '🎮';
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
          border: Border.all(color: Colors.grey[200]!),
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
}
