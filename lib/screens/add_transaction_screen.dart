import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/invoice_preview_state.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mamoney/widgets/invoice_import_loading_overlay.dart';
import 'package:mamoney/widgets/image_source_picker_dialog.dart';
import 'package:mamoney/screens/invoice_preview_screen.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:logging/logging.dart';
import 'package:mamoney/widgets/chat_bubble_widget.dart';
import 'package:mamoney/widgets/transaction_card_widget.dart';
import 'package:mamoney/widgets/invoice_widgets.dart';
import 'package:mamoney/widgets/invoice_image_widget.dart';
import 'package:mamoney/widgets/input_section_widget.dart';

final _logger = Logger('AddTransactionScreen');

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

  final List<ChatMessage> _chatMessages = [];
  final List<dynamic> _completedTransactions =
      []; // Can contain TransactionRecord or InvoiceGroup
  bool _isParsingAI = false;
  bool _isSavingTransaction = false;
  bool _isProcessingImage = false;
  bool _isUploadingImage = false;
  XFile? _selectedInvoiceImage; // Store the invoice image for upload

  // Invoice grouping fields
  List<Map<String, dynamic>> _parsedInvoiceItems = [];
  String? _currentInvoiceId;

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
    _selectedCategory = CategoryConstants.expenseCategories[0];
    _loadOldTransactions();
  }

  /// Load transactions from the last 48 hours from Firebase, grouped by invoice
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

      // Group transactions by invoiceId
      final Map<String, List<TransactionRecord>> invoiceGroups = {};
      final List<TransactionRecord> nonInvoiceTransactions = [];

      for (final tx in oldTransactions) {
        final record = TransactionRecord(
          description: tx.description,
          amount: tx.amount,
          category: tx.category,
          date: tx.date,
          type: tx.type,
          userMessage: tx.userMessage ?? tx.description,
          imageUrl: tx.imageUrl,
          invoiceId: tx.invoiceId,
        );

        if (tx.invoiceId != null && tx.invoiceId!.isNotEmpty) {
          // Group by invoice
          invoiceGroups.putIfAbsent(tx.invoiceId!, () => []).add(record);
        } else {
          // Individual transaction
          nonInvoiceTransactions.add(record);
        }
      }

      // Create a mixed list of both groups and individual transactions
      final List<dynamic> mixedList = [];

      // Add invoice groups
      for (final invoiceId in invoiceGroups.keys) {
        final transactions = invoiceGroups[invoiceId]!;
        final invoiceDate =
            transactions.isNotEmpty ? transactions.first.date : now;
        mixedList.add(InvoiceGroup(
          invoiceId: invoiceId,
          invoiceDate: invoiceDate,
          transactions: transactions,
        ));
      }

      // Add individual transactions
      mixedList.addAll(nonInvoiceTransactions);

      // Sort mixed list by date (oldest to newest)
      mixedList.sort((a, b) {
        DateTime dateA;
        DateTime dateB;

        if (a is InvoiceGroup) {
          dateA = a.invoiceDate;
        } else if (a is TransactionRecord) {
          dateA = a.date;
        } else {
          return 0;
        }

        if (b is InvoiceGroup) {
          dateB = b.invoiceDate;
        } else if (b is TransactionRecord) {
          dateB = b.date;
        } else {
          return 0;
        }

        return dateA.compareTo(dateB);
      });

      _completedTransactions.addAll(mixedList);
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
      final parseResult = await AIService.parseInvoiceImage(
        null,
        imageBytes: imageBytes,
        mediaType: mediaType,
      );

      provider.setProcessingProgress(0.9);

      if (!mounted) return;

      // Extract results
      final items = parseResult['items'] as List<Map<String, dynamic>>? ?? [];
      final invoiceId = parseResult['invoiceId'] as String?;
      final invoiceDate = parseResult['invoiceDate'] as DateTime?;

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

      // Store parsed invoice items for grouping display
      setState(() {
        _parsedInvoiceItems = items;
        _currentInvoiceId =
            invoiceId ?? 'invoice_${DateTime.now().millisecondsSinceEpoch}';
      });

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
        invoiceImageUrl = await _uploadInvoiceImage(_selectedInvoiceImage!);
      }

      // Transition to saving step
      provider.setImportStep(InvoiceImportStep.saving);

      // Process all items and create Transaction objects
      // These will NOT be saved immediately - user will review first
      final List<Transaction> transactionsForPreview = [];

      for (final item in items) {
        final description = item['description'] ?? '';
        final amount = item['amount'] ?? '';
        final category = item['category'] ?? 'Other';
        final type = item['type'] ?? 'expense';

        if (description.isEmpty || amount.isEmpty) {
          continue;
        }

        // Determine transaction type
        TransactionType selectedType = TransactionType.expense;
        if (type.toLowerCase() == 'income') {
          selectedType = TransactionType.income;
        }

        // Parse amount for database storage
        // Use AIService.cleanupAmount to properly handle various number formats
        // (Vietnamese: 27.500,00 → 27500, US: 27,500.00 → 27500, etc.)
        final cleanedAmount = AIService.cleanupAmount(amount.trim());
        var parsedAmount = double.tryParse(cleanedAmount) ?? 0;

        // Validate amount is reasonable (not 0 or too small)
        if (parsedAmount <= 0) {
          continue;
        }

        // Validate and map category
        final categories = selectedType == TransactionType.income
            ? CategoryConstants.incomeCategories
            : CategoryConstants.expenseCategories;

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

        // Create transaction object (without saving yet)
        // Try to get ragId from AI parsing
        String? ragId;
        try {
          final aiMessage = '$description ${parsedAmount.toInt()}';
          final aiResult = await AIService.parseTransactionMessage(aiMessage);
          if (aiResult['ragId'] != null) {
            ragId = aiResult['ragId'];
            _logger.info('Generated ragId for invoice item: $ragId');
          }
        } catch (e) {
          _logger.warning('Failed to generate ragId for invoice item: $e');
          // Continue without ragId if AI parsing fails
        }

        final transaction = Transaction(
          id: '', // Will be generated on save
          userId: uid,
          description: description,
          amount: parsedAmount,
          type: selectedType,
          category: validCategory,
          date: _selectedDate,
          createdAt: DateTime.now(),
          userMessage: 'Invoice: $description',
          imageUrl: invoiceImageUrl,
          invoiceId: invoiceId,
          invoiceDate: invoiceDate,
          ragId: ragId,
        );

        transactionsForPreview.add(transaction);
      }

      if (transactionsForPreview.isEmpty) {
        _addChatMessage(
          'Could not extract any valid items from invoice. Please try another image.',
          ChatMessageType.assistant,
        );
        setState(() {
          _isProcessingImage = false;
        });
        provider.clearImportStep();
        return;
      }

      // Transition to preview step
      provider.setImportStep(InvoiceImportStep.none);

      // Create preview state
      final previewState = InvoicePreviewState(
        invoiceId:
            invoiceId ?? 'invoice_${DateTime.now().millisecondsSinceEpoch}',
        invoiceDate: invoiceDate ?? DateTime.now(),
        imageUrl: invoiceImageUrl ?? '',
        transactions: transactionsForPreview,
        originalTransactions: transactionsForPreview,
      );

      // Set preview state in provider
      provider.setInvoicePreview(previewState);

      if (!mounted) return;

      _addChatMessage(
        '✅ Found ${transactionsForPreview.length} items. Please review before saving.',
        ChatMessageType.assistant,
      );

      // Navigate to preview screen
      if (mounted) {
        final result = await Navigator.of(context).push<bool?>(
          MaterialPageRoute(
            builder: (context) => InvoicePreviewScreen(
              initialPreviewState: previewState,
            ),
          ),
        );

        // Check if preview was successfully saved
        if (result == true) {
          // Preview screen handled the save, refresh the UI
          if (mounted) {
            _addChatMessage(
              '✅ Invoice saved successfully!',
              ChatMessageType.assistant,
            );
            await Future.delayed(const Duration(milliseconds: 500));
            _loadOldTransactions();
            _scrollToBottom();
          }
        }
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
        _addChatMessage(
          'You must be signed in to upload an invoice image',
          ChatMessageType.assistant,
        );
        return null;
      }

      // print('DEBUG _uploadInvoiceImage: User UID: $uid');
      _addChatMessage(
        '⬆️ Uploading invoice image...',
        ChatMessageType.assistant,
      );

      // Read image bytes - works on both web and mobile
      provider.setUploadProgress(0.1);
      final imageBytes = await imageFile.readAsBytes();
      // print(
      //     'DEBUG _uploadInvoiceImage: Image bytes read: ${imageBytes.length} bytes');

      provider.setUploadProgress(0.2);

      // Use current timestamp as transaction ID for now (will be replaced with actual ID if needed)
      final transactionId = '${DateTime.now().millisecondsSinceEpoch}';
      // print(
      //     'DEBUG _uploadInvoiceImage: Calling uploadTransactionImage with transactionId: $transactionId');

      provider.setUploadProgress(0.5);
      final imageUrl = await firebaseService.uploadTransactionImage(
        null,
        uid,
        transactionId,
        imageBytes: imageBytes,
      );

      provider.setUploadProgress(1.0);
      // print('DEBUG _uploadInvoiceImage: Upload successful. URL: $imageUrl');
      _addChatMessage(
        '✅ Invoice image uploaded successfully',
        ChatMessageType.assistant,
      );

      return imageUrl;
    } catch (e) {
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
        final ragId = result['ragId']; // Extract ragId from AI response

        // Update selected type based on AI result
        if (type.toLowerCase() == 'income') {
          _selectedType = TransactionType.income;
        } else {
          _selectedType = TransactionType.expense;
        }

        if (description.isNotEmpty && amount.isNotEmpty) {
          // Parse amount for database storage
          // Use AIService.cleanupAmount to properly handle various number formats
          final cleanAmount = AIService.cleanupAmount(amount.trim());
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
              ? CategoryConstants.incomeCategories
              : CategoryConstants.expenseCategories;

          String validCategory = category;
          if (!categories.contains(category)) {
            // Try to find partial match (e.g., "Food" matches "🍚 Food")
            final partialMatch = categories.firstWhere(
              (cat) => cat.toLowerCase().contains(category.toLowerCase()),
              orElse: () => categories.first,
            );
            validCategory = partialMatch;
          }

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
            ragId: ragId, // Store RAG API request ID
          );

          // Save to database
          final provider = context.read<TransactionProvider>();
          final savedId = await provider.addTransaction(transaction);

          _logger.info('Transaction saved with ID: $savedId');

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

  @override
  @override
  Widget build(BuildContext context) {
    final categories = _selectedType == TransactionType.income
        ? CategoryConstants.incomeCategories
        : CategoryConstants.expenseCategories;
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
                  // Show invoice group preview at top (if items are parsed)
                  if (_parsedInvoiceItems.isNotEmpty)
                    InvoiceGroupPreviewCard(
                      items: _parsedInvoiceItems,
                      invoiceId: _currentInvoiceId,
                    ),

                  // Chat Messages Area with Completed Transactions
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      itemCount:
                          _chatMessages.length + _completedTransactions.length,
                      itemBuilder: (context, index) {
                        // All chat messages
                        if (index < _chatMessages.length) {
                          return ChatBubbleWidget(
                            message: _chatMessages[index],
                          );
                        }

                        // All completed transactions and invoice groups
                        final itemIndex = index - _chatMessages.length;
                        final item = _completedTransactions[itemIndex];

                        // Display invoice groups (multiple transactions grouped together)
                        if (item is InvoiceGroup) {
                          return CompletedInvoiceGroupCard(group: item);
                        }

                        // Display individual transactions (with user message + card)
                        if (item is TransactionRecord) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              children: [
                                ChatBubbleWidget(
                                  message: ChatMessage(
                                    type: ChatMessageType.user,
                                    text: item.userMessage,
                                  ),
                                ),
                                CompletedTransactionCard(record: item),
                                if (item.imageUrl != null &&
                                    item.imageUrl!.isNotEmpty)
                                  InvoiceImageWidget(
                                    imageUrl: item.imageUrl!,
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) =>
                                            ImagePreviewDialog(
                                          imageUrl: item.imageUrl!,
                                        ),
                                      );
                                    },
                                  ),
                              ],
                            ),
                          );
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  // Current in-progress transaction (if exists)
                  if (_descriptionController.text.isNotEmpty ||
                      _amountController.text.isNotEmpty)
                    SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Column(
                          children: [
                            ChatBubbleWidget(
                              message: ChatMessage(
                                type: ChatMessageType.user,
                                text: _aiMessageController.text.isNotEmpty
                                    ? _aiMessageController.text
                                    : '',
                              ),
                            ),
                            TransactionPreviewCard(
                              description: _descriptionController.text,
                              category: _selectedCategory,
                              amount: double.tryParse(AIService.cleanupAmount(
                                      _amountController.text.trim())) ??
                                  0,
                              type: _selectedType,
                              date: _selectedDate,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Suggested Input Area
                  if (_descriptionController.text.isNotEmpty ||
                      _amountController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
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
                  // Input Section
                  InputSectionWidget(
                    messageController: _aiMessageController,
                    selectedType: _selectedType,
                    onTypeChanged: (type) {
                      setState(() {
                        _selectedType = type;
                        _selectedCategory = type == TransactionType.income
                            ? CategoryConstants.incomeCategories.first
                            : CategoryConstants.expenseCategories.first;
                      });
                    },
                    onCameraPressed: _isProcessingImage ||
                            _isSavingTransaction ||
                            provider.isImporting
                        ? null
                        : () {
                            ImageSourcePickerDialog.show(
                              context,
                              onImageSourceSelected: _captureAndParseInvoice,
                            );
                          },
                    onSendPressed: _isParsingAI || provider.isImporting
                        ? null
                        : _parseAIMessage,
                    isProcessingImage: _isProcessingImage,
                    isSavingTransaction: _isSavingTransaction,
                    isImporting: provider.isImporting,
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
