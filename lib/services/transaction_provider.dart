import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/transaction_sync_status.dart';
import 'package:mamoney/models/invoice_group.dart';
import 'package:mamoney/models/invoice_preview_state.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/services/offline_queue_service.dart';
import 'package:mamoney/services/connectivity_provider.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:mamoney/widgets/invoice_import_loading_overlay.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:logging/logging.dart';

final _logger = Logger('TransactionProvider');

class TransactionProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final OfflineQueueService _offlineQueueService = OfflineQueueService();
  late ConnectivityProvider _connectivityProvider;

  List<Transaction> _transactions = [];
  List<Transaction> _pendingTransactions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _transactionSubscription;

  // Filter state
  FilterType _filterType = FilterType.month; // Default filter is by month
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory; // Filter by category (null = no category filter)

  // Invoice import state
  InvoiceImportStep _currentImportStep = InvoiceImportStep.none;
  double _processingProgress = 0.0;
  double _uploadProgress = 0.0;

  // Invoice grouping state - tracks which invoice groups are expanded
  final Map<String, bool> _expandedInvoices = {};

  // Invoice preview state - holds transactions during preview/edit phase
  InvoicePreviewState? _previewState;

  List<Transaction> get transactions => _transactions;
  List<Transaction> get pendingTransactions => _pendingTransactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  FilterType get filterType => _filterType;
  DateTime get selectedDate => _selectedDate;
  String? get selectedCategory => _selectedCategory;

  // Invoice import state getters
  InvoiceImportStep get currentImportStep => _currentImportStep;
  bool get isImporting => _currentImportStep != InvoiceImportStep.none;
  double get processingProgress => _processingProgress;
  double get uploadProgress => _uploadProgress;

  // Get filtered transactions based on filter type, selected date, and category
  List<Transaction> get filteredTransactions {
    final filtered = _transactions.where((transaction) {
      // Filter by date
      final dateMatches = _filterType == FilterType.month
          ? transaction.date.year == _selectedDate.year &&
              transaction.date.month == _selectedDate.month
          : transaction.date.year == _selectedDate.year;

      // Filter by category if selected
      final categoryMatches = _selectedCategory == null ||
          transaction.category == _selectedCategory;

      return dateMatches && categoryMatches;
    }).toList();
    return filtered;
  }

  // Preview state getter
  InvoicePreviewState? get previewState => _previewState;
  bool get hasPreview => _previewState != null;

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get balance => totalIncome - totalExpense;

  // Filtered totals
  double get filteredTotalIncome => filteredTransactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get filteredTotalExpense => filteredTransactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get filteredBalance => filteredTotalIncome - filteredTotalExpense;

  TransactionProvider() {
    _initializeTransactionStream();
    _loadPendingTransactions();
  }

  /// Load pending transactions from offline queue on app startup
  Future<void> _loadPendingTransactions() async {
    try {
      final pending = await _offlineQueueService.getPendingTransactions();
      _pendingTransactions = pending;
      _logger.info(
          'Loaded ${pending.length} pending transactions from offline queue');
      notifyListeners();
    } catch (e) {
      _logger.severe('Failed to load pending transactions: $e');
    }
  }

  /// Set up listener for connectivity changes to trigger automatic sync
  void setupConnectivityListener(ConnectivityProvider connectivityProvider) {
    // Store reference for use in addTransaction
    _connectivityProvider = connectivityProvider;

    bool previousState = connectivityProvider.isConnected;

    connectivityProvider.addListener(() {
      final currentState = connectivityProvider.isConnected;

      // If connectivity transitioned from offline to online
      if (!previousState && currentState) {
        _logger.info(
            'Connectivity restored - triggering sync of pending transactions');
        syncPendingTransactions();
      }

      previousState = currentState;
    });
  }

  void _initializeTransactionStream() {
    // Cancel any existing subscription
    _transactionSubscription?.cancel();

    final transactionStream = _firebaseService.getTransactionsStream();
    _transactionSubscription = transactionStream.listen((transactions) {
      // Sort transactions by createdAt in ascending order (oldest to newest)
      transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _transactions = transactions;

      notifyListeners();
    });
  }

  void reset() {
    _initializeTransactionStream();
  }

  Future<String> addTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Check if device is connected to internet (use stored connectivity provider)
      final isConnected = _connectivityProvider.isConnected;
      _logger.info(
          'addTransaction: isConnected = $isConnected, description = ${transaction.description}');

      if (!isConnected) {
        // Device is offline - save to offline queue
        _logger.info(
            'Device offline - saving transaction to offline queue: ${transaction.description}');

        // Generate a temporary ID for the transaction
        final tempId = transaction.id.isEmpty
            ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
            : transaction.id;

        // Create transaction with pending status and temp ID
        final pendingTransaction = transaction.copyWith(
          id: tempId,
          syncStatus: TransactionSyncStatus.pending,
        );

        // Add to pending list and queue
        _pendingTransactions.add(pendingTransaction);
        await _offlineQueueService.addPendingTransaction(pendingTransaction);

        notifyListeners();
        return tempId;
      } else {
        // Device is online - save to Firebase directly
        _logger.info(
            'Device online - saving transaction to Firebase: ${transaction.description}');
        final id = await _firebaseService.addTransaction(transaction);
        // Do NOT add optimistically - let the Firebase stream handle it
        // This prevents duplicates from both manual add and stream listener
        return id;
      }
    } catch (e) {
      _error = e.toString();
      _logger.severe('Error adding transaction: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(String transactionId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.deleteTransaction(transactionId);
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Delete all transactions with a specific invoiceId
  Future<void> deleteInvoice(String invoiceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Find all transactions with this invoiceId
      final transactionsToDelete =
          _transactions.where((t) => t.invoiceId == invoiceId).toList();

      // Delete each transaction
      for (final transaction in transactionsToDelete) {
        await _firebaseService.deleteTransaction(transaction.id);
      }
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Remove transaction from view immediately (optimistic removal for Dismissible)
  void removeTransactionFromView(String transactionId) {
    _transactions.removeWhere((t) => t.id == transactionId);
    notifyListeners();
  }

  /// Remove invoice from view immediately (optimistic removal for invoice delete)
  void removeInvoiceFromView(String invoiceId) {
    _transactions.removeWhere((t) => t.invoiceId == invoiceId);
    notifyListeners();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.updateTransaction(transaction);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<Transaction> getTransactionsByCategory(String category) {
    return _transactions.where((t) => t.category == category).toList();
  }

  void setFilterType(FilterType filterType) {
    _filterType = filterType;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  void setSelectedCategory(String? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  // Invoice import state setters
  void setImportStep(InvoiceImportStep step) {
    _currentImportStep = step;
    notifyListeners();
  }

  void clearImportStep() {
    _currentImportStep = InvoiceImportStep.none;
    notifyListeners();
  }

  void setProcessingProgress(double progress) {
    _processingProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setUploadProgress(double progress) {
    _uploadProgress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }

  // Get category breakdown for a list of transactions
  // Returns a map of category names to total amounts
  Map<String, double> getCategoryBreakdown(List<Transaction> transactions) {
    final breakdown = <String, double>{};

    for (var transaction in transactions) {
      breakdown[transaction.category] =
          (breakdown[transaction.category] ?? 0) + transaction.amount;
    }

    return breakdown;
  }

  // Get income category breakdown for filtered transactions
  Map<String, double> getIncomeCategoryBreakdown() {
    final incomeTransactions = filteredTransactions
        .where((t) => t.type == TransactionType.income)
        .toList();
    return getCategoryBreakdown(incomeTransactions);
  }

  // Get expense category breakdown for filtered transactions
  Map<String, double> getExpenseCategoryBreakdown() {
    final expenseTransactions = filteredTransactions
        .where((t) => t.type == TransactionType.expense)
        .toList();
    return getCategoryBreakdown(expenseTransactions);
  }

  /// Get net balance (expense - income) for each month
  /// Returns a map of DateTime (first day of month) to net balance values
  /// monthsToShow determines how many months to include (from current selection backwards)
  Map<DateTime, double> getNetBalanceByMonth(int monthsToShow) {
    final result = <DateTime, double>{};

    // Start from the selected date and go backwards
    for (int i = monthsToShow - 1; i >= 0; i--) {
      final targetMonth = DateTime(
        _selectedDate.year,
        _selectedDate.month - i,
        1,
      );

      // Calculate total income and expense for this month
      final monthTransactions = _transactions.where((t) {
        return t.date.year == targetMonth.year &&
            t.date.month == targetMonth.month;
      }).toList();

      final monthIncome = monthTransactions
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final monthExpense = monthTransactions
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);

      // Net balance = expense - income (positive means net loss, negative means net profit)
      result[targetMonth] = monthExpense - monthIncome;
    }

    return result;
  }

  /// Returns a map of DateTime (first day of month) to net balance values
  /// Always calculates from today backwards (not affected by filter selection)
  /// Used for the home screen chart to show 12-month rolling window
  Map<DateTime, double> getNetBalanceByMonthFromToday(int monthsToShow) {
    final result = <DateTime, double>{};
    final today = DateTime.now();

    // Start from today and go backwards
    for (int i = monthsToShow - 1; i >= 0; i--) {
      final targetMonth = DateTime(
        today.year,
        today.month - i,
        1,
      );

      // Calculate total income and expense for this month
      final monthTransactions = _transactions.where((t) {
        return t.date.year == targetMonth.year &&
            t.date.month == targetMonth.month;
      }).toList();

      final monthIncome = monthTransactions
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final monthExpense = monthTransactions
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);

      // Net balance = expense - income (positive means net loss, negative means net profit)
      result[targetMonth] = monthExpense - monthIncome;
    }

    return result;
  }

  /// Create invoice groups from filtered transactions
  /// Groups transactions by invoiceId, sorts groups by invoiceDate (newest first)
  /// Returns both invoice groups and ungrouped transactions
  Map<String, dynamic> _createInvoiceGroups() {
    final invoiceGroups = <String, List<Transaction>>{};
    final ungroupedTransactions = <Transaction>[];

    // Group transactions by invoiceId
    for (final transaction in filteredTransactions) {
      if (transaction.invoiceId != null) {
        invoiceGroups.putIfAbsent(transaction.invoiceId!, () => []);
        invoiceGroups[transaction.invoiceId!]!.add(transaction);
      } else {
        ungroupedTransactions.add(transaction);
        _logger.fine('[GROUPING] Transaction ${transaction.id} is ungrouped');
      }
    }

    // Create InvoiceGroup objects and sort by invoiceDate (newest first)
    final groups = invoiceGroups.entries.map((entry) {
      final transaction = entry.value.first;

      return InvoiceGroup(
        invoiceId: entry.key,
        imageUrl: transaction.imageUrl,
        invoiceDate: transaction.invoiceDate ?? DateTime.now(),
        transactions: entry.value,
      );
    }).toList();

    groups.sort((a, b) => b.invoiceDate.compareTo(a.invoiceDate));

    // Restore expanded state for each group
    for (final group in groups) {
      if (_expandedInvoices.containsKey(group.invoiceId)) {
        group.setExpanded(_expandedInvoices[group.invoiceId]!);
      }
    }

    return {
      'invoiceGroups': groups,
      'ungroupedTransactions': ungroupedTransactions,
    };
  }

  /// Get invoice groups from filtered transactions
  List<InvoiceGroup> getInvoiceGroups() {
    final result = _createInvoiceGroups();
    final groups = result['invoiceGroups'] as List<InvoiceGroup>;
    return groups;
  }

  /// Get ungrouped transactions (those without invoiceId)
  List<Transaction> getUngroupedTransactions() {
    final result = _createInvoiceGroups();
    final ungrouped = result['ungroupedTransactions'] as List<Transaction>;
    return ungrouped;
  }

  /// Toggle expanded state for an invoice group
  void toggleInvoiceExpanded(String invoiceId) {
    final currentState = _expandedInvoices[invoiceId] ?? true;
    _expandedInvoices[invoiceId] = !currentState;
    notifyListeners();
  }

  /// Set expanded state for an invoice group
  void setInvoiceExpanded(String invoiceId, bool expanded) {
    _expandedInvoices[invoiceId] = expanded;
    notifyListeners();
  }

  /// Check if an invoice group is expanded
  bool isInvoiceExpanded(String invoiceId) {
    return _expandedInvoices[invoiceId] ?? true;
  }

  // ============ Invoice Preview State Management ============

  /// Set the invoice preview state when starting review
  void setInvoicePreview(InvoicePreviewState state) {
    _previewState = state;
    notifyListeners();
  }

  /// Update a single transaction in the preview
  void updatePreviewTransaction(int index, Transaction updatedTransaction) {
    if (_previewState == null) return;
    _previewState = _previewState!.updateTransaction(index, updatedTransaction);
    notifyListeners();
  }

  /// Remove a transaction from the preview
  void removeFromPreview(int index) {
    if (_previewState == null) return;
    _previewState = _previewState!.removeTransaction(index);
    notifyListeners();
  }

  /// Add a new transaction to the preview
  void addToPreview(Transaction transaction) {
    if (_previewState == null) return;
    _previewState = _previewState!.addTransaction(transaction);
    notifyListeners();
  }

  /// Save all transactions from preview to Firebase and clear preview state
  Future<void> savePreviewTransactions() async {
    if (_previewState == null || _previewState!.transactions.isEmpty) {
      throw Exception('No transactions to save in preview');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _logger.info(
        '[PREVIEW] Saving ${_previewState!.transactions.length} transactions '
        'from invoice ${_previewState!.invoiceId}',
      );

      // Save all transactions from preview
      final transactions = _previewState!.transactions;
      for (final transaction in transactions) {
        await _firebaseService.addTransaction(transaction);
      }

      _logger.info(
        '[PREVIEW] Successfully saved ${transactions.length} transactions',
      );

      // Clear preview state after successful save
      _previewState = null;
    } catch (e) {
      _error = e.toString();
      _logger.severe('[PREVIEW] Error saving transactions: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear the invoice preview state without saving
  void clearPreview() {
    _previewState = null;
    notifyListeners();
  }

  /// Sync all pending transactions to Firebase when connectivity is restored
  Future<void> syncPendingTransactions() async {
    if (_pendingTransactions.isEmpty) {
      _logger.info('No pending transactions to sync');
      return;
    }

    _logger.info(
        'Starting sync of ${_pendingTransactions.length} pending transactions');

    // Log details of each pending transaction
    for (var i = 0; i < _pendingTransactions.length; i++) {
      final t = _pendingTransactions[i];
      _logger.info(
          '[SYNC] Transaction $i: id=${t.id}, desc=${t.description}, amount=${t.amount}, userMessage=${t.userMessage}, syncStatus=${t.syncStatus}');
    }

    final List<String> succeededIds = [];
    final List<String> failedIds = [];

    // Process all pending transactions in parallel
    await Future.wait(
      _pendingTransactions.map((transaction) async {
        try {
          // Mark as syncing
          var syncingTransaction = transaction.copyWith(
            syncStatus: TransactionSyncStatus.syncing,
          );

          // Update the pending transaction in the list
          var index =
              _pendingTransactions.indexWhere((t) => t.id == transaction.id);
          if (index >= 0) {
            _pendingTransactions[index] = syncingTransaction;
          }
          notifyListeners();

          // Check if transaction needs parsing (offline-saved with amount=0)
          final needsParsing = transaction.amount == 0 &&
              transaction.userMessage != null &&
              transaction.userMessage!.isNotEmpty;

          _logger.info(
              '[SYNC] Transaction ${transaction.id}: needsParsing=$needsParsing, amount=${transaction.amount}, userMessage=${transaction.userMessage}');

          if (needsParsing) {
            _logger.info(
                '[SYNC] Parsing unparsed transaction: ${transaction.userMessage}');

            // Parse the user message with AI
            final parseResult = await AIService.parseTransactionMessage(
                transaction.userMessage!);

            if (parseResult.containsKey('error')) {
              _logger.warning(
                  'Failed to parse transaction during sync: ${parseResult['error']}');
              // Continue with original data if parsing fails
              syncingTransaction = syncingTransaction.copyWith(
                syncStatus: TransactionSyncStatus.synced,
              );
            } else {
              // Extract parsed values
              final description =
                  parseResult['description'] ?? transaction.description;
              final amountStr = parseResult['amount'] ?? '0';
              final category = parseResult['category'] ?? transaction.category;
              final type = parseResult['type'] ?? 'expense';
              final ragId = parseResult['ragId'];

              // Parse amount
              final cleanAmount = AIService.cleanupAmount(amountStr.trim());
              final parsedAmount = double.tryParse(cleanAmount) ?? 0;

              // Determine type
              final transactionType = type.toLowerCase() == 'income'
                  ? TransactionType.income
                  : TransactionType.expense;

              // Validate and map category
              final categories = transactionType == TransactionType.income
                  ? CategoryConstants.incomeCategories
                  : CategoryConstants.expenseCategories;

              String validCategory = category;
              if (!categories.contains(category)) {
                final partialMatch = categories.firstWhere(
                  (cat) => cat.toLowerCase().contains(category.toLowerCase()),
                  orElse: () => categories.first,
                );
                validCategory = partialMatch;
              }

              // Update transaction with parsed values
              syncingTransaction = syncingTransaction.copyWith(
                description: description,
                amount: parsedAmount,
                category: validCategory,
                type: transactionType,
                ragId: ragId,
                syncStatus: TransactionSyncStatus.synced,
              );

              _logger.info(
                  'Parsed transaction: $description, amount: $parsedAmount, category: $validCategory');
            }
          } else {
            syncingTransaction = syncingTransaction.copyWith(
              syncStatus: TransactionSyncStatus.synced,
            );
          }

          // Clear the temp ID before saving to Firebase so it generates a new one
          final transactionToSync = syncingTransaction.copyWith(id: '');

          _logger.info(
              'Syncing transaction: ${transactionToSync.description}, amount: ${transactionToSync.amount}, userMessage: ${transactionToSync.userMessage}');

          // Try to save to Firebase
          final newId =
              await _firebaseService.addTransaction(transactionToSync);

          _logger.info(
              'Successfully synced transaction: ${syncingTransaction.description} (new ID: $newId)');
          succeededIds.add(transaction.id);

          // Remove from pending queue
          await _offlineQueueService.removePendingTransaction(transaction.id);
        } catch (e) {
          _logger.severe('Failed to sync transaction ${transaction.id}: $e');
          failedIds.add(transaction.id);

          // Mark transaction as failed (but keep in queue for retry)
          final failedTransaction = transaction.copyWith(
            syncStatus: TransactionSyncStatus.failed,
          );
          final index =
              _pendingTransactions.indexWhere((t) => t.id == transaction.id);
          if (index >= 0) {
            _pendingTransactions[index] = failedTransaction;
          }
        }
      }),
      eagerError: false, // Continue syncing even if some fail
    );

    // Remove succeeded transactions from pending list
    _pendingTransactions.removeWhere((t) => succeededIds.contains(t.id));

    // Log results
    _logger.info(
        'Sync complete: ${succeededIds.length} succeeded, ${failedIds.length} failed');
    notifyListeners();
  }

  /// Get sync status for a specific transaction
  TransactionSyncStatus getTransactionSyncStatus(String transactionId) {
    // Check pending transactions
    for (final transaction in _pendingTransactions) {
      if (transaction.id == transactionId) {
        return transaction.syncStatus;
      }
    }

    // Check synced transactions
    for (final transaction in _transactions) {
      if (transaction.id == transactionId) {
        return transaction.syncStatus;
      }
    }

    return TransactionSyncStatus.synced;
  }

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }
}
