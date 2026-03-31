import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/invoice_group.dart';
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

      if (transaction.invoiceId != null && transaction.invoiceId!.isNotEmpty) {
        _logger.warning(
            '[FILTER] Transaction ${transaction.id} has invoiceId=${transaction.invoiceId}, '
            'filter matches=$matches');
      }
      return matches;
    }).toList();

    _logger.info('[FILTER] filteredTransactions: ${filtered.length} total, '
        'withInvoiceId: ${filtered.where((t) => t.invoiceId != null).length}');
    return filtered;
  }

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
      _logger.info(
          '[TRANSACTION STREAM] Received ${transactions.length} transactions total');

      // Debug log: Check invoiceIds
      int transactionsWithInvoiceId = 0;
      for (final t in transactions) {
        if (t.invoiceId != null && t.invoiceId!.isNotEmpty) {
          transactionsWithInvoiceId++;
          _logger.warning(
              '[INVOICE TRANSACTION] ID: ${t.id}, InvoiceId: ${t.invoiceId}, Desc: ${t.description}');
        }
      }
      _logger.info(
          '[INVOICE COUNT] Total transactions with invoiceId: $transactionsWithInvoiceId');

      // Sort transactions by createdAt in ascending order (oldest to newest)
      transactions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _transactions = transactions;

      _logger.warning(
          '[NOTIFY] Calling notifyListeners() - about to notify $transactionsWithInvoiceId invoice transactions');
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
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    _logger.info(
        '[GROUPING] Starting to create invoice groups from ${filteredTransactions.length} filtered transactions');

    final invoiceGroups = <String, List<Transaction>>{};
    final ungroupedTransactions = <Transaction>[];

    // Group transactions by invoiceId
    for (final transaction in filteredTransactions) {
      if (transaction.invoiceId != null) {
        invoiceGroups.putIfAbsent(transaction.invoiceId!, () => []);
        invoiceGroups[transaction.invoiceId!]!.add(transaction);
        _logger.info(
            '[GROUPING] Added transaction ${transaction.id} to group ${transaction.invoiceId}');
      } else {
        ungroupedTransactions.add(transaction);
        _logger.fine('[GROUPING] Transaction ${transaction.id} is ungrouped');
      }
    }

    _logger.info('[GROUPING] Created ${invoiceGroups.length} invoice groups');
    _logger.info(
        '[GROUPING] Ungrouped transactions: ${ungroupedTransactions.length}');

    // Create InvoiceGroup objects and sort by invoiceDate (newest first)
    final groups = invoiceGroups.entries.map((entry) {
      final transaction = entry.value.first;
      _logger.info(
          '[GROUPING] Creating InvoiceGroup: ${entry.key} with ${entry.value.length} transactions');
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

    _logger.info(
        '[GROUPING] Final: ${groups.length} invoice groups, ${ungroupedTransactions.length} ungrouped');

    return {
      'invoiceGroups': groups,
      'ungroupedTransactions': ungroupedTransactions,
    };
  }

  /// Get invoice groups from filtered transactions
  List<InvoiceGroup> getInvoiceGroups() {
    _logger.info('[UI] getInvoiceGroups() called');
    final result = _createInvoiceGroups();
    final groups = result['invoiceGroups'] as List<InvoiceGroup>;
    _logger.info('[UI] getInvoiceGroups() returning ${groups.length} groups');
    return groups;
  }

  /// Get ungrouped transactions (those without invoiceId)
  List<Transaction> getUngroupedTransactions() {
    _logger.info('[UI] getUngroupedTransactions() called');
    final result = _createInvoiceGroups();
    final ungrouped = result['ungroupedTransactions'] as List<Transaction>;
    _logger.info(
        '[UI] getUngroupedTransactions() returning ${ungrouped.length} transactions');
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

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }
}
