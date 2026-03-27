import 'package:cloud_firestore/cloud_firestore.dart';

enum TransactionType { income, expense }

enum FilterType { month, year }

class Transaction {
  final String id;
  final String userId;
  final String description;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final DateTime createdAt;
  final String? userMessage; // Original user input message
  final String? imageUrl; // Invoice/receipt image URL
  final String? invoiceId; // Groups transactions imported from same invoice
  final DateTime? invoiceDate; // When the invoice was imported

  Transaction({
    required this.id,
    required this.userId,
    required this.description,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.createdAt,
    this.userMessage,
    this.imageUrl,
    this.invoiceId,
    this.invoiceDate,
  });

  // Convert Transaction to JSON
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'description': description,
      'amount': amount,
      'type': type.toString().split('.').last,
      'category': category,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      'userMessage': userMessage,
      'imageUrl': imageUrl,
      'invoiceId': invoiceId,
      'invoiceDate':
          invoiceDate != null ? Timestamp.fromDate(invoiceDate!) : null,
    };
  }

  // Create Transaction from JSON
  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] == 'income'
          ? TransactionType.income
          : TransactionType.expense,
      category: map['category'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      userMessage: map['userMessage'],
      imageUrl: map['imageUrl'],
      invoiceId: map['invoiceId'],
      invoiceDate: map['invoiceDate'] != null
          ? (map['invoiceDate'] as Timestamp).toDate()
          : null,
    );
  }

  // Copy with method
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
    );
  }

  @override
  String toString() {
    return 'Transaction(id: $id, userId: $userId, description: $description, amount: $amount, type: $type, category: $category, date: $date)';
  }
}
