import 'package:mamoney/models/transaction.dart';

class TransactionFilter {
  final DateTime? startDate;
  final DateTime? endDate;
  final TransactionType? type; // null means all types
  final String? category; // null means all categories
  final double? minAmount;
  final double? maxAmount;

  TransactionFilter({
    this.startDate,
    this.endDate,
    this.type,
    this.category,
    this.minAmount,
    this.maxAmount,
  });

  bool matches(Transaction transaction) {
    // Check date range
    if (startDate != null && transaction.date.isBefore(startDate!)) {
      return false;
    }
    if (endDate != null) {
      final endOfDay = endDate!.add(const Duration(days: 1));
      if (transaction.date.isAfter(endOfDay)) {
        return false;
      }
    }

    // Check transaction type
    if (type != null && transaction.type != type) {
      return false;
    }

    // Check category
    if (category != null && transaction.category != category) {
      return false;
    }

    // Check amount range
    if (minAmount != null && transaction.amount < minAmount!) {
      return false;
    }
    if (maxAmount != null && transaction.amount > maxAmount!) {
      return false;
    }

    return true;
  }

  bool get isEmpty =>
      startDate == null &&
      endDate == null &&
      type == null &&
      category == null &&
      minAmount == null &&
      maxAmount == null;

  TransactionFilter copyWith({
    DateTime? startDate,
    DateTime? endDate,
    TransactionType? type,
    String? category,
    double? minAmount,
    double? maxAmount,
  }) {
    return TransactionFilter(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      type: type ?? this.type,
      category: category ?? this.category,
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
    );
  }
}
