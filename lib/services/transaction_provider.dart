import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/invoice_group.dart';
import 'package:mamoney/models/invoice_preview_state.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/widgets/invoice_import_loading_overlay.dart';
import 'package:logging/logging.dart';

final _logger = Logger('TransactionProvider');

class TransactionProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _transactionSubscription;

  // Filter state
  FilterType _filterType = FilterType.month; // Default filter is by month
  DateTime _selectedDate = DateTime.now();

  // Invoice import state
  InvoiceImportStep _currentImportStep = InvoiceImportStep.none;
  double _processingProgress = 0.0;
  double _uploadProgress = 0.0;

  // Invoice grouping state - tracks which invoice groups are expanded
  final Map<String, bool> _expandedInvoices = {};

  // Invoice preview state - holds transactions during preview/edit phase
  InvoicePreviewState? _previewState;

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  FilterType get filterType => _filterType;
  DateTime get selectedDate => _selectedDate;

  // Invoice import state getters
  InvoiceImportStep get currentImportStep => _currentImportStep;
  bool get isImporting => _currentImportStep != InvoiceImportStep.none;
  double get processingProgress => _processingProgress;
  double get uploadProgress => _uploadProgress;

  // Get filtered transactions based on filter type and selected date
  List<Transaction> get filteredTransactions {
    final filtered = _transactions.where((transaction) {
      final matches = _filterType == FilterType.month
          ? transaction.date.year == _selectedDate.year &&
              transaction.date.month == _selectedDate.month
          : transaction.date.year == _selectedDate.year;

      return matches;
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
      final id = await _firebaseService.addTransaction(transaction);
      // Do NOT add optimistically - let the Firebase stream handle it
      // This prevents duplicates from both manual add and stream listener
      return id;
    } catch (e) {
      _error = e.toString();
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

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }
}
