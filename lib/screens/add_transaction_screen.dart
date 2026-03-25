import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mamoney/widgets/invoice_import_loading_overlay.dart';

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
  final String? imageUrl; // Add image URL field

  TransactionRecord({
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.type,
    required this.userMessage,
    this.imageUrl,
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
  bool _isProcessingImage = false;
  bool _isUploadingImage = false;
  XFile? _selectedInvoiceImage; // Store the invoice image for upload

  late TransactionType _selectedType;
  String _selectedCategory = '';
  final DateTime _selectedDate = DateTime.now();
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
    _aiMessageController = TextEditingController();
    _scrollController = ScrollController();
    _selectedType = TransactionType.expense;
    _selectedCategory = expenseCategories[0];
    _loadOldTransactions();
  }

  /// Load transactions from the last 48 hours from Firebase
  void _loadOldTransactions() {
    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();
    final fortyEightHoursAgo = now.subtract(const Duration(hours: 48));

    // Filter transactions from the last 48 hours
    final oldTransactions = provider.transactions
        .where((tx) => tx.createdAt.isAfter(fortyEightHoursAgo))
        .toList();

    // Sort by createdAt ASCENDING (oldest first)
    oldTransactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    setState(() {
      _completedTransactions.clear();
      for (final tx in oldTransactions) {
        _completedTransactions.add(TransactionRecord(
          description: tx.description,
          amount: tx.amount,
          category: tx.category,
          date: tx.date,
          type: tx.type,
          userMessage: tx.userMessage ?? tx.description,
          imageUrl: tx.imageUrl,
        ));
      }
    });
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

  /// Show a bottom sheet to let user choose between camera and photo library
  void _showImageSourcePicker() {
    final provider = context.read<TransactionProvider>();
    provider.setImportStep(InvoiceImportStep.selecting);

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Select Image Source',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Camera option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _captureAndParseInvoice(ImageSource.camera);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.blue.shade100,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.blue,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Camera'),
                      ],
                    ),
                  ),
                  // Photo Library option
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _captureAndParseInvoice(ImageSource.gallery);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.green.shade100,
                          ),
                          child: const Icon(
                            Icons.photo_library,
                            color: Colors.green,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('Photo Library'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Capture invoice image from camera or photo library and parse it
  Future<void> _captureAndParseInvoice(ImageSource source) async {
    if (_isProcessingImage || _isSavingTransaction) {
      return;
    }

    final provider = context.read<TransactionProvider>();

    try {
      final XFile? imageFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (imageFile == null) {
        provider.clearImportStep();
        return; // User cancelled
      }

      // Store the image file for later upload
      _selectedInvoiceImage = imageFile;
      
      // Transition to processing step
      provider.setImportStep(InvoiceImportStep.processing);
      provider.setProcessingProgress(0.0);

      setState(() {
        _isProcessingImage = true;
      });

      _addChatMessage('📸 Processing invoice...', ChatMessageType.assistant);

      // Read image bytes - works on both web and mobile
      provider.setProcessingProgress(0.2);
      final imageBytes = await imageFile.readAsBytes();
      final mediaType = imageFile.mimeType ?? 'image/jpeg';

      provider.setProcessingProgress(0.5);
      final items = await AIService.parseInvoiceImage(
        null,
        imageBytes: imageBytes,
        mediaType: mediaType,
      );

      provider.setProcessingProgress(0.9);

      if (!mounted) return;

      // Check for errors
      if (items.isNotEmpty && items.first.containsKey('error')) {
        _addChatMessage(
          'Error parsing invoice: ${items.first['error']}',
          ChatMessageType.assistant,
        );
        setState(() {
          _isProcessingImage = false;
        });
        provider.clearImportStep();
        return;
      }

      // Process each extracted item
      if (items.isEmpty) {
        _addChatMessage(
          'Could not extract items from invoice. Please try another image.',
          ChatMessageType.assistant,
        );
        setState(() {
          _isProcessingImage = false;
        });
        provider.clearImportStep();
        return;
      }

      _addChatMessage(
        '✅ Found ${items.length} items in invoice. Creating transactions for all items...',
        ChatMessageType.assistant,
      );

      provider.setProcessingProgress(1.0);

      // Ensure user is signed in
      final uid = FirebaseService().currentUser?.uid;
      if (uid == null) {
        _addChatMessage(
          'You must be signed in to add a transaction',
          ChatMessageType.assistant,
        );
        setState(() {
          _isProcessingImage = false;
        });
        provider.clearImportStep();
        return;
      }

      // Transition to uploading step
      provider.setImportStep(InvoiceImportStep.uploading);
      provider.setUploadProgress(0.0);

      // Upload invoice image to Firebase and get URL
      String? invoiceImageUrl;
      if (_selectedInvoiceImage != null) {
        print('DEBUG: Starting image upload...');
        invoiceImageUrl = await _uploadInvoiceImage(_selectedInvoiceImage!);
        print('DEBUG: Image upload completed. URL: $invoiceImageUrl');
      } else {
        print('DEBUG: No image selected for upload');
      }

      // Transition to saving step
      provider.setImportStep(InvoiceImportStep.saving);

      // Process and save all items
      int successCount = 0;
      double totalAmount = 0;

      for (final item in items) {
        final description = item['description'] ?? '';
        final amount = item['amount'] ?? '';
        final category = item['category'] ?? 'Other';
        final type = item['type'] ?? 'expense';

        // Debug: log extracted data
        print(
            'DEBUG: Processing item - Description: "$description", Amount: "$amount", Category: "$category", ImageURL: $invoiceImageUrl');

        if (description.isEmpty || amount.isEmpty) {
          print('DEBUG: Skipping item with empty description or amount');
          continue;
        }

        // Determine transaction type
        TransactionType selectedType = TransactionType.expense;
        if (type.toLowerCase() == 'income') {
          selectedType = TransactionType.income;
        }

        // Parse amount for database storage
        final cleanAmount = amount.trim().replaceAll(RegExp(r'[^\d.]'), '');
        var parsedAmount = double.tryParse(cleanAmount) ?? 0;

        print(
            'DEBUG: Amount parsing - Original: "$amount" → Cleaned: "$cleanAmount" → Parsed: $parsedAmount');

        // Validate amount is reasonable (not 0 or too small)
        if (parsedAmount <= 0) {
          print('DEBUG: Skipping item with invalid amount: $parsedAmount');
          continue;
        }

        // Validate and map category
        final categories = selectedType == TransactionType.income
            ? incomeCategories
            : expenseCategories;

        String validCategory = category;

        // Try exact match first
        if (!categories.contains(category)) {
          // Try to find partial match (e.g., "Food" matches "🍚 Food")
          final partialMatch = categories.firstWhere(
            (cat) => cat.toLowerCase().contains(category.toLowerCase()),
            orElse: () => categories.first,
          );
          validCategory = partialMatch;
        }

        // Create transaction object for database with invoice image URL
        final transaction = Transaction(
          id: '',
          userId: uid,
          description: description,
          amount: parsedAmount,
          type: selectedType,
          category: validCategory,
          date: _selectedDate,
          createdAt: DateTime.now(),
          userMessage: 'Invoice: $description',
          imageUrl: invoiceImageUrl,
        );

        // Save to database
        await provider.addTransaction(transaction);

        if (provider.error != null) {
          _addChatMessage(
            '❌ Failed to save: $description - ${provider.error}',
            ChatMessageType.assistant,
          );
        } else {
          successCount++;
          totalAmount += parsedAmount;
        }
      }

      if (successCount == 0) {
        _addChatMessage(
          '⚠️ Could not save any items from the invoice. Please try again.',
          ChatMessageType.assistant,
        );
        setState(() {
          _isProcessingImage = false;
        });
        return;
      }

      _addChatMessage(
        '✅ Invoice saved: $successCount items - Total ${formatCurrency(totalAmount)}',
        ChatMessageType.assistant,
      );

      // Refresh transactions from Firebase
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        _loadOldTransactions();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        _addChatMessage(
          'Error: $e',
          ChatMessageType.assistant,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingImage = false;
        });
        provider.clearImportStep();
      }
    }
  }

  /// Upload invoice image to Firebase Storage
  Future<String?> _uploadInvoiceImage(XFile imageFile) async {
    try {
      if (_isUploadingImage) {
        print('DEBUG _uploadInvoiceImage: Already uploading, returning null');
        return null;
      }

      setState(() {
        _isUploadingImage = true;
      });

      final provider = context.read<TransactionProvider>();
      provider.setUploadProgress(0.0);

      final firebaseService = FirebaseService();
      final uid = firebaseService.currentUser?.uid;
      if (uid == null) {
        print('ERROR _uploadInvoiceImage: User not authenticated');
        _addChatMessage(
          'You must be signed in to upload an invoice image',
          ChatMessageType.assistant,
        );
        return null;
      }

      print('DEBUG _uploadInvoiceImage: User UID: $uid');
      _addChatMessage(
        '⬆️ Uploading invoice image...',
        ChatMessageType.assistant,
      );

      // Read image bytes - works on both web and mobile
      provider.setUploadProgress(0.1);
      final imageBytes = await imageFile.readAsBytes();
      print('DEBUG _uploadInvoiceImage: Image bytes read: ${imageBytes.length} bytes');
      
      provider.setUploadProgress(0.2);
      
      // Use current timestamp as transaction ID for now (will be replaced with actual ID if needed)
      final transactionId = '${DateTime.now().millisecondsSinceEpoch}';
      print('DEBUG _uploadInvoiceImage: Calling uploadTransactionImage with transactionId: $transactionId');
      
      provider.setUploadProgress(0.5);
      final imageUrl = await firebaseService.uploadTransactionImage(
        null,
        uid,
        transactionId,
        imageBytes: imageBytes,
      );

      provider.setUploadProgress(1.0);
      print('DEBUG _uploadInvoiceImage: Upload successful. URL: $imageUrl');
      _addChatMessage(
        '✅ Invoice image uploaded successfully',
        ChatMessageType.assistant,
      );

      return imageUrl;
    } catch (e) {
      print('ERROR _uploadInvoiceImage: Exception - $e');
      if (mounted) {
        _addChatMessage(
          'Warning: Failed to upload image - $e',
          ChatMessageType.assistant,
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
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
        final category = result['category'] ?? _selectedCategory;
        final type = result['type'] ?? 'expense';

        // Update selected type based on AI result
        if (type.toLowerCase() == 'income') {
          _selectedType = TransactionType.income;
        } else {
          _selectedType = TransactionType.expense;
        }

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

          // Clear controllers for next transaction immediately for UX
          _descriptionController.clear();
          _amountController.clear();

          // Refresh transactions from Firebase after a brief delay to ensure the transaction is synced
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            _loadOldTransactions();
            _scrollToBottom();
          }
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
            // Invoice Image Thumbnail (if exists)
            if (record.imageUrl != null && record.imageUrl!.isNotEmpty)
              _buildInvoiceImageWidget(record.imageUrl!),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceImageWidget(String imageUrl) {
    // Handle both local and network images
    if (imageUrl.startsWith('local://')) {
      // Local image - fetch from SharedPreferences
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: () => _showImagePreview(imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
              future: FirebaseService().getLocalImage(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                
                if (snapshot.hasError || snapshot.data == null) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  );
                }
                
                return Stack(
                  children: [
                    Image.memory(
                      snapshot.data!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } else {
      // Network image - use Image.network
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: () => _showImagePreview(imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withOpacity(0.9),
            child: Center(
              child: imageUrl.startsWith('local://')
                  ? FutureBuilder<Uint8List?>(
                      future: FirebaseService().getLocalImage(imageUrl),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return InteractiveViewer(
                            child: Image.memory(snapshot.data!),
                          );
                        }
                        return const SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(),
                        );
                      },
                    )
                  : InteractiveViewer(
                      child: Image.network(imageUrl),
                    ),
            ),
          ),
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
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          return Stack(
            children: [
              // Main content
              Column(
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
                                  enabled: !_isParsingAI && !provider.isImporting,
                                  onSubmitted: _isParsingAI || provider.isImporting
                                      ? null
                                      : (_) {
                                          _parseAIMessage();
                                        },
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Camera button for invoice
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue,
                              ),
                              child: IconButton(
                                onPressed: _isProcessingImage || _isSavingTransaction || provider.isImporting
                                    ? null
                                    : () {
                                        _showImageSourcePicker();
                                      },
                                icon: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Send button for text input
                            Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black,
                              ),
                              child: IconButton(
                                onPressed: _isParsingAI || provider.isImporting
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
                        const SizedBox(height: 16),
                        // Transaction Type Selector
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedType = TransactionType.income;
                                    _selectedCategory = incomeCategories.first;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedType == TransactionType.income
                                        ? Colors.green
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: _selectedType == TransactionType.income
                                        ? Border.all(
                                            color: Colors.green.shade700, width: 2)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_downward,
                                        color: _selectedType == TransactionType.income
                                            ? Colors.white
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Income',
                                        style: TextStyle(
                                          color: _selectedType == TransactionType.income
                                              ? Colors.white
                                              : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedType = TransactionType.expense;
                                    _selectedCategory = expenseCategories.first;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _selectedType == TransactionType.expense
                                        ? Colors.red
                                        : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: _selectedType == TransactionType.expense
                                        ? Border.all(
                                            color: Colors.red.shade700, width: 2)
                                        : null,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.arrow_upward,
                                        color: _selectedType == TransactionType.expense
                                            ? Colors.white
                                            : Colors.grey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Expense',
                                        style: TextStyle(
                                          color:
                                              _selectedType == TransactionType.expense
                                                  ? Colors.white
                                                  : Colors.grey,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // Loading overlay when importing
              if (provider.isImporting)
                InvoiceImportLoadingOverlay(
                  currentStep: provider.currentImportStep,
                  uploadProgress: provider.uploadProgress,
                  processingProgress: provider.processingProgress,
                ),
            ],
          );
        },
      ),
    );
  }
}
