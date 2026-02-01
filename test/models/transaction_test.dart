import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  group('Transaction Model', () {
    group('Constructor', () {
      test('should create transaction with all fields', () {
        final now = DateTime.now();
        final transaction = Transaction(
          id: 'test-id',
          userId: 'user-123',
          description: 'Test transaction',
          amount: 100.50,
          type: TransactionType.expense,
          category: 'Food',
          date: now,
          createdAt: now,
        );

        expect(transaction.id, 'test-id');
        expect(transaction.userId, 'user-123');
        expect(transaction.description, 'Test transaction');
        expect(transaction.amount, 100.50);
        expect(transaction.type, TransactionType.expense);
        expect(transaction.category, 'Food');
        expect(transaction.date, now);
        expect(transaction.createdAt, now);
      });

      test('should create income transaction', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Salary',
          amount: 5000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.type, TransactionType.income);
      });

      test('should create expense transaction', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Lunch',
          amount: 50,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.type, TransactionType.expense);
      });
    });

    group('toMap', () {
      test('should convert transaction to map correctly', () {
        final now = DateTime.now();
        final transaction = Transaction(
          id: 'test-id',
          userId: 'user-123',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: now,
          createdAt: now,
        );

        final map = transaction.toMap();

        expect(map['id'], 'test-id');
        expect(map['userId'], 'user-123');
        expect(map['description'], 'Test');
        expect(map['amount'], 100);
        expect(map['type'], 'expense');
        expect(map['category'], 'Food');
        expect(map['date'], isA<Timestamp>());
        expect(map['createdAt'], isA<Timestamp>());
      });

      test('should convert income type to string', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Salary',
          amount: 5000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final map = transaction.toMap();
        expect(map['type'], 'income');
      });

      test('should convert expense type to string', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Food',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final map = transaction.toMap();
        expect(map['type'], 'expense');
      });

      test('should convert dates to Timestamp', () {
        final now = DateTime.now();
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: now,
          createdAt: now,
        );

        final map = transaction.toMap();
        expect(map['date'], isA<Timestamp>());
        expect(map['createdAt'], isA<Timestamp>());
      });
    });

    group('fromMap', () {
      test('should create transaction from map', () {
        final now = DateTime.now();
        final map = {
          'id': 'test-id',
          'userId': 'user-123',
          'description': 'Test',
          'amount': 100.0,
          'type': 'expense',
          'category': 'Food',
          'date': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
        };

        final transaction = Transaction.fromMap(map);

        expect(transaction.id, 'test-id');
        expect(transaction.userId, 'user-123');
        expect(transaction.description, 'Test');
        expect(transaction.amount, 100.0);
        expect(transaction.type, TransactionType.expense);
        expect(transaction.category, 'Food');
      });

      test('should parse income type from string', () {
        final map = {
          'id': '1',
          'userId': 'user1',
          'description': 'Salary',
          'amount': 5000.0,
          'type': 'income',
          'category': 'Salary',
          'date': Timestamp.now(),
          'createdAt': Timestamp.now(),
        };

        final transaction = Transaction.fromMap(map);
        expect(transaction.type, TransactionType.income);
      });

      test('should parse expense type from string', () {
        final map = {
          'id': '1',
          'userId': 'user1',
          'description': 'Food',
          'amount': 100.0,
          'type': 'expense',
          'category': 'Food',
          'date': Timestamp.now(),
          'createdAt': Timestamp.now(),
        };

        final transaction = Transaction.fromMap(map);
        expect(transaction.type, TransactionType.expense);
      });

      test('should handle missing optional fields with defaults', () {
        final map = {
          'amount': 100.0,
          'type': 'expense',
          'date': Timestamp.now(),
          'createdAt': Timestamp.now(),
        };

        final transaction = Transaction.fromMap(map);
        expect(transaction.id, '');
        expect(transaction.userId, '');
        expect(transaction.description, '');
        expect(transaction.category, '');
      });

      test('should convert int amount to double', () {
        final map = {
          'id': '1',
          'userId': 'user1',
          'description': 'Test',
          'amount': 100, // int instead of double
          'type': 'expense',
          'category': 'Food',
          'date': Timestamp.now(),
          'createdAt': Timestamp.now(),
        };

        final transaction = Transaction.fromMap(map);
        expect(transaction.amount, 100.0);
        expect(transaction.amount, isA<double>());
      });
    });

    group('copyWith', () {
      test('should copy transaction with new id', () {
        final original = Transaction(
          id: 'old-id',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final copied = original.copyWith(id: 'new-id');

        expect(copied.id, 'new-id');
        expect(copied.userId, original.userId);
        expect(copied.description, original.description);
      });

      test('should copy transaction with new amount', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final copied = original.copyWith(amount: 200);

        expect(copied.amount, 200);
        expect(copied.id, original.id);
      });

      test('should copy transaction with new type', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final copied = original.copyWith(type: TransactionType.income);

        expect(copied.type, TransactionType.income);
      });

      test('should copy without changes when no parameters provided', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.amount, original.amount);
        expect(copied.type, original.type);
      });

      test('should copy multiple fields at once', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final copied = original.copyWith(
          description: 'New description',
          amount: 200,
          category: 'Transport',
        );

        expect(copied.description, 'New description');
        expect(copied.amount, 200);
        expect(copied.category, 'Transport');
        expect(copied.id, original.id);
        expect(copied.userId, original.userId);
      });
    });

    group('toString', () {
      test('should return string representation', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final str = transaction.toString();

        expect(str, contains('Transaction'));
        expect(str, contains('id: 1'));
        expect(str, contains('description: Test'));
        expect(str, contains('amount: 100'));
      });
    });

    group('Edge cases', () {
      test('should handle zero amount', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Free item',
          amount: 0,
          type: TransactionType.expense,
          category: 'Other',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.amount, 0);
      });

      test('should handle very large amounts', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'House',
          amount: 999999999.99,
          type: TransactionType.expense,
          category: 'Other',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.amount, 999999999.99);
      });

      test('should handle empty strings', () {
        final transaction = Transaction(
          id: '',
          userId: '',
          description: '',
          amount: 100,
          type: TransactionType.expense,
          category: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.id, isEmpty);
        expect(transaction.description, isEmpty);
      });

      test('should handle special characters in description', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Coffee @ café #1 (50%)',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.description, contains('@'));
        expect(transaction.description, contains('#'));
        expect(transaction.description, contains('%'));
      });

      test('should preserve decimal precision', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 123.456789,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.amount, 123.456789);
      });

      test('should handle dates in different timezones', () {
        final utcDate = DateTime.utc(2024, 1, 1, 12, 0, 0);
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: utcDate,
          createdAt: utcDate,
        );

        expect(transaction.date, utcDate);
      });
    });

    group('TransactionType enum', () {
      test('should have income and expense types', () {
        expect(TransactionType.income, isNotNull);
        expect(TransactionType.expense, isNotNull);
      });

      test('should convert to string correctly', () {
        expect(TransactionType.income.toString(), contains('income'));
        expect(TransactionType.expense.toString(), contains('expense'));
      });
    });
  });
}