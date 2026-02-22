import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/firebase_service.dart';

class TransactionProvider extends ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();

  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  StreamSubscription? _transactionSubscription;

  // Filter state
  FilterType _filterType = FilterType.month; // Default filter is by month
  DateTime _selectedDate = DateTime.now();

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  FilterType get filterType => _filterType;
  DateTime get selectedDate => _selectedDate;

  // Get filtered transactions based on filter type and selected date
  List<Transaction> get filteredTransactions {
    return _transactions.where((transaction) {
      if (_filterType == FilterType.month) {
        return transaction.date.year == _selectedDate.year &&
            transaction.date.month == _selectedDate.month;
      } else {
        // Filter by year
        return transaction.date.year == _selectedDate.year;
      }
    }).toList();
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
      print(
          '[DEBUG] TransactionProvider received ${transactions.length} transactions');
      // Sort transactions by createdAt in descending order
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _transactions = transactions;
      notifyListeners();
    });
  }

  void reset() {
    _initializeTransactionStream();
  }

  Future<void> addTransaction(Transaction transaction) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _firebaseService.addTransaction(transaction);
      // Do NOT add optimistically - let the Firebase stream handle it
      // This prevents duplicates from both manual add and stream listener
    } catch (e) {
      _error = e.toString();
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

  @override
  void dispose() {
    _transactionSubscription?.cancel();
    super.dispose();
  }
}
