import 'package:mamoney/models/transaction.dart';

/// Represents a group of transactions imported from the same invoice
class InvoiceGroup {
  final String invoiceId;
  final String? imageUrl; // URL to the invoice image (same for all in group)
  final DateTime invoiceDate; // When the invoice was imported
  final List<Transaction> transactions; // All transactions in this group

  // Derived properties
  String? get vendorName => _extractVendorName();
  double get totalAmount => transactions.fold(0, (sum, t) => sum + t.amount);
  int get itemCount => transactions.length;
  bool get isExpanded => _isExpanded;

  // Internal state
  bool _isExpanded = true;

  InvoiceGroup({
    required this.invoiceId,
    required this.imageUrl,
    required this.invoiceDate,
    required this.transactions,
  });

  /// Toggle expanded state
  void toggleExpanded() {
    _isExpanded = !_isExpanded;
  }

  /// Set expanded state directly
  void setExpanded(bool expanded) {
    _isExpanded = expanded;
  }

  /// Extract vendor name from transaction messages (if available)
  /// Returns null if no vendor name can be extracted
  String? _extractVendorName() {
    // Try to extract from the first transaction's userMessage or description
    if (transactions.isEmpty) return null;

    final firstTransaction = transactions.first;
    
    // Check userMessage for pattern like "Invoice: Vendor Name"
    if (firstTransaction.userMessage != null) {
      final message = firstTransaction.userMessage!;
      if (message.startsWith('Invoice: ')) {
        // Could parse more sophisticated vendor detection here if needed
        return null;
      }
    }

    return null;
  }

  @override
  String toString() {
    return 'InvoiceGroup(id: $invoiceId, items: ${transactions.length}, total: $totalAmount)';
  }
}
