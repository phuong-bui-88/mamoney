import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/utils/currency_utils.dart';

// Transaction Record Model (for displaying completed transactions)
class TransactionRecord {
  final String description;
  final double amount;
  final String category;
  final DateTime date;
  final TransactionType type;
  final String userMessage;
  final String? imageUrl;
  final String? invoiceId;

  TransactionRecord({
    required this.description,
    required this.amount,
    required this.category,
    required this.date,
    required this.type,
    required this.userMessage,
    this.imageUrl,
    this.invoiceId,
  });
}

// Completed Transaction Card Widget
class CompletedTransactionCard extends StatelessWidget {
  final TransactionRecord record;
  final Function(String)? onImageTap;

  const CompletedTransactionCard({
    required this.record,
    this.onImageTap,
    super.key,
  });

  String _getEmoji() {
    if (record.category.isNotEmpty) {
      final spaceIndex = record.category.indexOf(' ');
      if (spaceIndex > 0) {
        return record.category.substring(0, spaceIndex).trim();
      }
    }
    if (record.type == TransactionType.expense) return '🛒';
    return '💰';
  }

  @override
  Widget build(BuildContext context) {
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
                      _getEmoji(),
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
}

// Current Transaction Preview Card Widget
class TransactionPreviewCard extends StatelessWidget {
  final String description;
  final String category;
  final double amount;
  final TransactionType type;
  final DateTime date;

  const TransactionPreviewCard({
    required this.description,
    required this.category,
    required this.amount,
    required this.type,
    required this.date,
    super.key,
  });

  String _getEmoji() {
    if (category.isNotEmpty) {
      final spaceIndex = category.indexOf(' ');
      if (spaceIndex > 0) {
        return category.substring(0, spaceIndex).trim();
      }
    }
    if (type == TransactionType.expense) return '🛒';
    return '💰';
  }

  @override
  Widget build(BuildContext context) {
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
                  'Recorded: ${type == TransactionType.expense ? 'Expense' : 'Income'}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('EEE, MMM dd').format(date),
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
                      _getEmoji(),
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
                        description.isNotEmpty ? description : 'No description',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        category,
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
                    color: type == TransactionType.expense
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
