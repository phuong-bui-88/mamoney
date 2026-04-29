import 'package:shared_preferences/shared_preferences.dart';
import 'package:mamoney/models/transaction.dart';
import 'dart:convert';
import 'package:logging/logging.dart';

final _logger = Logger('OfflineQueueService');

/// Service to manage offline transaction queue using SharedPreferences
class OfflineQueueService {
  static const String _queueKey = 'offline_pending_transactions_queue';

  // Singleton pattern
  static final OfflineQueueService _instance = OfflineQueueService._internal();

  factory OfflineQueueService() {
    return _instance;
  }

  OfflineQueueService._internal();

  /// Get SharedPreferences instance
  Future<SharedPreferences> _getPrefs() async {
    return await SharedPreferences.getInstance();
  }

  /// Add a pending transaction to the queue
  Future<void> addPendingTransaction(Transaction transaction) async {
    try {
      final prefs = await _getPrefs();
      final queue = await getPendingTransactions();

      // Add transaction to queue
      queue.add(transaction);

      // Serialize to JSON
      final jsonList = queue.map((t) => jsonEncode(t.toMap())).toList();

      // Save to SharedPreferences
      await prefs.setStringList(_queueKey, jsonList);

      _logger.info(
          'Added transaction to offline queue. Queue size: ${queue.length}');
    } catch (e) {
      _logger.severe('Failed to add pending transaction: $e');
      rethrow;
    }
  }

  /// Get all pending transactions from queue
  Future<List<Transaction>> getPendingTransactions() async {
    try {
      final prefs = await _getPrefs();
      final jsonList = prefs.getStringList(_queueKey) ?? [];

      final transactions = jsonList.map((jsonStr) {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return Transaction.fromMap(map);
      }).toList();

      return transactions;
    } catch (e) {
      _logger.severe('Failed to get pending transactions: $e');
      return [];
    }
  }

  /// Remove a pending transaction by ID
  Future<void> removePendingTransaction(String transactionId) async {
    try {
      final prefs = await _getPrefs();
      final queue = await getPendingTransactions();

      // Remove the transaction from queue
      queue.removeWhere((t) => t.id == transactionId);

      // Serialize and save
      final jsonList = queue.map((t) => jsonEncode(t.toMap())).toList();
      await prefs.setStringList(_queueKey, jsonList);

      _logger.info(
          'Removed transaction from offline queue. Remaining: ${queue.length}');
    } catch (e) {
      _logger.severe('Failed to remove pending transaction: $e');
      rethrow;
    }
  }

  /// Clear all pending transactions
  Future<void> clearAllPendingTransactions() async {
    try {
      final prefs = await _getPrefs();
      await prefs.remove(_queueKey);
      _logger.info('Cleared all pending transactions from queue');
    } catch (e) {
      _logger.severe('Failed to clear pending transactions: $e');
      rethrow;
    }
  }

  /// Get count of pending transactions
  Future<int> getPendingCount() async {
    try {
      final transactions = await getPendingTransactions();
      return transactions.length;
    } catch (e) {
      _logger.severe('Failed to get pending count: $e');
      return 0;
    }
  }

  /// Check if there are any pending transactions
  Future<bool> hasPendingTransactions() async {
    try {
      final count = await getPendingCount();
      return count > 0;
    } catch (e) {
      _logger.severe('Failed to check pending transactions: $e');
      return false;
    }
  }
}
