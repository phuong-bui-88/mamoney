import 'package:mamoney/models/transaction.dart';

/// Holds the state of invoice transactions during preview/edit phase
/// before they are saved to Firestore.
class InvoicePreviewState {
  final String invoiceId;
  final DateTime invoiceDate;
  final String imageUrl;
  final List<Transaction> transactions;
  final List<Transaction> originalTransactions; // For comparison/undo

  InvoicePreviewState({
    required this.invoiceId,
    required this.invoiceDate,
    required this.imageUrl,
    required this.transactions,
    required this.originalTransactions,
  });

  /// Create a copy with modified fields
  InvoicePreviewState copyWith({
    String? invoiceId,
    DateTime? invoiceDate,
    String? imageUrl,
    List<Transaction>? transactions,
    List<Transaction>? originalTransactions,
  }) {
    return InvoicePreviewState(
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      imageUrl: imageUrl ?? this.imageUrl,
      transactions: transactions ?? this.transactions,
      originalTransactions: originalTransactions ?? this.originalTransactions,
    );
  }

  /// Update a transaction at the given index
  InvoicePreviewState updateTransaction(
    int index,
    Transaction updatedTransaction,
  ) {
    if (index < 0 || index >= transactions.length) {
      return this;
    }
    final newTransactions = [...transactions];
    newTransactions[index] = updatedTransaction;
    return copyWith(transactions: newTransactions);
  }

  /// Remove a transaction at the given index
  InvoicePreviewState removeTransaction(int index) {
    if (index < 0 || index >= transactions.length) {
      return this;
    }
    final newTransactions = [...transactions];
    newTransactions.removeAt(index);
    return copyWith(transactions: newTransactions);
  }

  /// Add a new transaction to the preview
  InvoicePreviewState addTransaction(Transaction transaction) {
    final newTransactions = [
      ...transactions,
      transaction.copyWith(
        invoiceId: invoiceId,
        imageUrl: imageUrl,
        invoiceDate: invoiceDate,
      ),
    ];
    return copyWith(transactions: newTransactions);
  }

  /// Check if any transactions have been modified or deleted
  bool isModified() {
    if (transactions.length != originalTransactions.length) {
      return true;
    }
    for (int i = 0; i < transactions.length; i++) {
      if (transactions[i].description != originalTransactions[i].description ||
          transactions[i].amount != originalTransactions[i].amount) {
        return true;
      }
    }
    return false;
  }

  /// Get the total amount of all transactions
  double getTotalAmount() {
    return transactions.fold(0.0, (sum, tx) => sum + tx.amount);
  }

  /// Get the count of transactions
  int getItemCount() {
    return transactions.length;
  }
}

/// Extension to add copyWith method to Transaction for preview edits
extension TransactionCopyWith on Transaction {
  Transaction copyWith({
    String? id,
    String? userId,
    String? description,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    DateTime? createdAt,
    String? userMessage,
    String? imageUrl,
    String? invoiceId,
    DateTime? invoiceDate,
    String? ragId,
  }) {
    return Transaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      userMessage: userMessage ?? this.userMessage,
      imageUrl: imageUrl ?? this.imageUrl,
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      ragId: ragId ?? this.ragId,
    );
  }
}
