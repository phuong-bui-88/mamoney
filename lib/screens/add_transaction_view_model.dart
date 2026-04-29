import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/transaction_sync_status.dart';
import 'package:mamoney/models/invoice_preview_state.dart';

import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:mamoney/services/connectivity_provider.dart';

import 'package:mamoney/widgets/chat_bubble_widget.dart';
import 'package:mamoney/widgets/transaction_card_widget.dart';
import 'package:mamoney/widgets/invoice_widgets.dart';

import 'package:mamoney/utils/category_constants.dart';

class AddTransactionViewModel extends ChangeNotifier {
  final TransactionProvider transactionProvider;
  ConnectivityProvider? _connectivityProvider;

  AddTransactionViewModel({
    required this.transactionProvider,
  });

  bool get isConnected => _connectivityProvider?.isConnected ?? true;

  // ================= STATE =================
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();

  final List<ChatMessage> messages = [];
  final List<dynamic> history = [];

  bool isLoading = false;
  bool isProcessingImage = false;

  TransactionType selectedType = TransactionType.expense;

  // ================= INIT =================
  void init(BuildContext? context) {
    transactionProvider.addListener(_reloadHistory);
    if (context != null) {
      try {
        _connectivityProvider = context.read<ConnectivityProvider>();
        transactionProvider.setupConnectivityListener(_connectivityProvider!);
      } catch (_) {
        _connectivityProvider = null;
      }
    }
    _reloadHistory();
  }

  void disposeVM() {
    messageController.dispose();
    scrollController.dispose();
    transactionProvider.removeListener(_reloadHistory);
  }

  // ================= HELPERS =================
  void _addMessage(String text, ChatMessageType type,
      {TransactionSyncStatus? syncStatus}) {
    messages.add(ChatMessage(
      type: type,
      text: text,
      syncStatus: syncStatus,
    ));
    notifyListeners();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.jumpTo(scrollController.position.maxScrollExtent);
      }
    });
  }

  String _mapCategory(String input, TransactionType type) {
    final list = type == TransactionType.income
        ? CategoryConstants.incomeCategories
        : CategoryConstants.expenseCategories;

    return list.firstWhere(
      (c) => c.toLowerCase().contains(input.toLowerCase()),
      orElse: () => list.first,
    );
  }

  Future<String?> _uploadImage(XFile file) async {
    final uid = FirebaseService().currentUser?.uid;
    if (uid == null) return null;

    final bytes = await file.readAsBytes();
    return FirebaseService().uploadTransactionImage(
      null,
      uid,
      DateTime.now().millisecondsSinceEpoch.toString(),
      imageBytes: bytes,
    );
  }

  // ================= HISTORY =================
  void _reloadHistory() {
    final cutoff = DateTime.now().subtract(const Duration(hours: 48));

    final all = [
      ...transactionProvider.transactions,
      ...transactionProvider.pendingTransactions,
    ].where((e) => e.createdAt.isAfter(cutoff)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    history.clear();

    final Map<String, List<TransactionRecord>> grouped = {};
    final List<TransactionRecord> singles = [];

    for (var tx in all) {
      final record = TransactionRecord(
        description: tx.description,
        amount: tx.amount,
        category: tx.category,
        date: tx.date,
        type: tx.type,
        userMessage: tx.userMessage ?? tx.description,
        imageUrl: tx.imageUrl,
        invoiceId: tx.invoiceId,
        syncStatus: tx.syncStatus,
      );

      if (tx.invoiceId != null && tx.invoiceId!.isNotEmpty) {
        grouped.putIfAbsent(tx.invoiceId!, () => []).add(record);
      } else {
        singles.add(record);
      }
    }

    history.addAll(grouped.entries.map((e) {
      return InvoiceGroup(
        invoiceId: e.key,
        invoiceDate: e.value.first.date,
        transactions: e.value,
        syncStatus: e.value.first.syncStatus,
      );
    }));

    history.addAll(singles);

    notifyListeners();
  }

  // ================= AI =================
  Future<void> handleAI() async {
    final text = messageController.text.trim();
    if (text.isEmpty || isLoading) return;

    messageController.clear();
    isLoading = true;
    notifyListeners();

    final uid = FirebaseService().currentUser?.uid;

    if (uid == null) {
      _addMessage('Login required', ChatMessageType.assistant);
      isLoading = false;
      notifyListeners();
      return;
    }

    try {
      if (!isConnected) {
        final tx = Transaction(
          id: '',
          userId: uid,
          description: text,
          amount: 0,
          type: selectedType,
          category: CategoryConstants.expenseCategories.first,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          userMessage: text,
        );

        final id = await transactionProvider.addTransaction(tx);
        final status = transactionProvider.getTransactionSyncStatus(id);

        _addMessage(text, ChatMessageType.user, syncStatus: status);
        return;
      }

      final result = await AIService.parseTransactionMessage(text);

      if (result.containsKey('error')) {
        _addMessage(
            result['error'] ?? 'Unknown error', ChatMessageType.assistant);
        return;
      }

      final amount =
          double.tryParse(AIService.cleanupAmount(result['amount'] ?? '')) ?? 0;

      final type = (result['type'] == 'income')
          ? TransactionType.income
          : TransactionType.expense;

      final tx = Transaction(
        id: '',
        userId: uid,
        description: result['description'] ?? '',
        amount: amount,
        type: type,
        category: _mapCategory(result['category'] ?? '', type),
        date: DateTime.now(),
        createdAt: DateTime.now(),
        userMessage: text,
        ragId: result['ragId'],
      );

      final id = await transactionProvider.addTransaction(tx);
      final status = transactionProvider.getTransactionSyncStatus(id);

      _addMessage(text, ChatMessageType.user, syncStatus: status);
    } catch (e) {
      _addMessage('Error: $e', ChatMessageType.assistant);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // ================= INVOICE =================
  Future<InvoicePreviewState?> handleInvoice(XFile file) async {
    if (isProcessingImage) return null;

    isProcessingImage = true;
    notifyListeners();

    try {
      _addMessage('📸 Processing...', ChatMessageType.assistant);

      final bytes = await file.readAsBytes();

      final result = await AIService.parseInvoiceImage(
        null,
        imageBytes: bytes,
        mediaType: file.mimeType ?? 'image/jpeg',
      );

      final items = result['items'] as List? ?? [];
      if (items.isEmpty) {
        _addMessage('No items detected', ChatMessageType.assistant);
        return null;
      }

      final imageUrl = await _uploadImage(file);

      return InvoicePreviewState(
        invoiceId: result['invoiceId'] ?? DateTime.now().toString(),
        invoiceDate: result['invoiceDate'] ?? DateTime.now(),
        imageUrl: imageUrl ?? '',
        transactions: items.map<Transaction>((e) {
          final amount =
              double.tryParse(AIService.cleanupAmount(e['amount'])) ?? 0;

          final type = (e['type'] == 'income')
              ? TransactionType.income
              : TransactionType.expense;

          return Transaction(
            id: '',
            userId: FirebaseService().currentUser!.uid,
            description: e['description'],
            amount: amount,
            type: type,
            category: _mapCategory(e['category'], type),
            date: DateTime.now(),
            createdAt: DateTime.now(),
            userMessage: 'Invoice',
            imageUrl: imageUrl,
          );
        }).toList(),
        originalTransactions: [],
      );
    } catch (e) {
      _addMessage('Error: $e', ChatMessageType.assistant);
      return null;
    } finally {
      isProcessingImage = false;
      notifyListeners();
    }
  }

  void onInvoiceSaved() {
    _addMessage('✅ Invoice saved', ChatMessageType.assistant);
    init(null);
  }
}
