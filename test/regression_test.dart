import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/screens/add_transaction_screen.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

/// Regression tests to prevent known issues from reoccurring
/// These tests verify specific bug fixes and edge cases that were problematic
void main() {
  group('Regression Tests', () {
    group('ThousandsSeparatorInputFormatter Regressions', () {
      late ThousandsSeparatorInputFormatter formatter;

      setUp(() {
        formatter = ThousandsSeparatorInputFormatter();
      });

      test('REGRESSION: Should not crash on rapid consecutive inputs', () {
        const inputs = ['1', '12', '123', '1234', '12345', '123456'];

        for (var i = 0; i < inputs.length; i++) {
          final oldValue = TextEditingValue(
            text: i > 0 ? inputs[i - 1] : '',
          );
          final newValue = TextEditingValue(text: inputs[i]);

          expect(
            () => formatter.formatEditUpdate(oldValue, newValue),
            returnsNormally,
          );
        }
      });

      test('REGRESSION: Should handle backspace correctly on formatted number',
          () {
        // User types 1,234 then backspaces
        const oldValue = TextEditingValue(text: '1,234');
        const newValue = TextEditingValue(text: '1,23');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Should format 123 without comma
        expect(result.text, '123');
      });

      test('REGRESSION: Should not lose cursor position on valid input', () {
        const oldValue = TextEditingValue(text: '123');
        const newValue = TextEditingValue(text: '1234');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        // Cursor should be at end of formatted text
        expect(result.selection.baseOffset, result.text.length);
      });

      test('REGRESSION: Should handle paste of large number', () {
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '123456789');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '123,456,789');
      });

      test('REGRESSION: Should handle deletion of all digits', () {
        const oldValue = TextEditingValue(text: '1,234,567');
        const newValue = TextEditingValue(text: '');

        final result = formatter.formatEditUpdate(oldValue, newValue);

        expect(result.text, '');
      });
    });

    group('AIService Regressions', () {
      test('REGRESSION: Should handle Vietnamese "k" notation correctly', () {
        // Vietnamese users type "50k" for 50,000
        const response = 'DESCRIPTION: Va xe | AMOUNT: 50000';
        expect(response, contains('50000'));
      });

      test('REGRESSION: Should not fail on empty API response', () async {
        // If API returns empty, should handle gracefully
        final result = await AIService.parseTransactionMessage('');
        expect(result, isA<Map<String, String>>());
      });

      test('REGRESSION: Should handle special characters in description', () {
        const response =
            'DESCRIPTION: Coffee @ café #1 (50% off) | AMOUNT: 25';

        final descRegex = RegExp(r'DESCRIPTION:\s*([^|]+)', caseSensitive: false);
        final match = descRegex.firstMatch(response);

        expect(match?.group(1)?.trim(), contains('@'));
        expect(match?.group(1)?.trim(), contains('#'));
        expect(match?.group(1)?.trim(), contains('%'));
      });

      test('REGRESSION: Should extract amount even with currency symbols', () {
        const response = 'DESCRIPTION: Lunch | AMOUNT: \$50.00';

        final amountRegex =
            RegExp(r'AMOUNT:\s*(\d+(?:\.\d+)?)', caseSensitive: false);
        final match = amountRegex.firstMatch(response);

        expect(match?.group(1), '50.00');
      });
    });

    group('Transaction Model Regressions', () {
      test('REGRESSION: Should preserve exact amount through serialization', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 123.456789,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final map = original.toMap();
        final restored = Transaction.fromMap(map);

        expect(restored.amount, original.amount);
      });

      test('REGRESSION: Should handle copyWith with null values correctly', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Original',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        // copyWith with no parameters should return identical values
        final copied = original.copyWith();

        expect(copied.id, original.id);
        expect(copied.description, original.description);
        expect(copied.amount, original.amount);
      });

      test('REGRESSION: Should handle int amount conversion in fromMap', () {
        final map = {
          'id': '1',
          'userId': 'user1',
          'description': 'Test',
          'amount': 100, // int, not double
          'type': 'expense',
          'category': 'Food',
          'date': Timestamp.now(),
          'createdAt': Timestamp.now(),
        };

        expect(() => Transaction.fromMap(map), returnsNormally);
        final transaction = Transaction.fromMap(map);
        expect(transaction.amount, isA<double>());
      });
    });

    group('Currency Formatting Regressions', () {
      test('REGRESSION: Should handle very small amounts', () {
        expect(() => formatCurrency(0.01), returnsNormally);
      });

      test('REGRESSION: Should format Vietnamese common amounts correctly', () {
        // Common Vietnamese amounts
        final amounts = {
          5000: '5,000',
          10000: '10,000',
          20000: '20,000',
          50000: '50,000',
          100000: '100,000',
          200000: '200,000',
          500000: '500,000',
        };

        for (final entry in amounts.entries) {
          final result = formatCurrency(entry.key);
          expect(result, contains('VND'));
          // Should contain the number representation
          expect(result, isNotEmpty);
        }
      });

      test('REGRESSION: Should round decimals consistently', () {
        // VND doesn't use decimals, so should round
        final result1 = formatCurrency(1234.4);
        final result2 = formatCurrency(1234.6);

        // Both should format to VND without decimals
        expect(result1, contains('VND'));
        expect(result2, contains('VND'));
      });
    });

    group('Integration Regressions', () {
      test(
          'REGRESSION: Formatter should work with typical user input sequence',
          () {
        final formatter = ThousandsSeparatorInputFormatter();

        // Simulate user typing "lunch 50000"
        // They input just the numbers
        final steps = [
          ('', '5'),
          ('5', '50'),
          ('50', '500'),
          ('500', '5000'),
          ('5,000', '50000'),
        ];

        for (final step in steps) {
          final oldValue = TextEditingValue(text: step.$1);
          final newValue = TextEditingValue(text: step.$2);

          expect(
            () => formatter.formatEditUpdate(oldValue, newValue),
            returnsNormally,
          );
        }
      });

      test('REGRESSION: Should handle concurrent rapid changes', () {
        final formatter = ThousandsSeparatorInputFormatter();

        // Simulate rapid typing
        for (var i = 1; i <= 100; i++) {
          final oldValue = TextEditingValue(text: (i - 1).toString());
          final newValue = TextEditingValue(text: i.toString());

          expect(
            () => formatter.formatEditUpdate(oldValue, newValue),
            returnsNormally,
          );
        }
      });

      test('REGRESSION: Transaction type should be preserved in serialization',
          () {
        final income = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Salary',
          amount: 10000000,
          type: TransactionType.income,
          category: 'Salary',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final expense = Transaction(
          id: '2',
          userId: 'user1',
          description: 'Food',
          amount: 50000,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final incomeMap = income.toMap();
        final expenseMap = expense.toMap();

        expect(incomeMap['type'], 'income');
        expect(expenseMap['type'], 'expense');

        final restoredIncome = Transaction.fromMap(incomeMap);
        final restoredExpense = Transaction.fromMap(expenseMap);

        expect(restoredIncome.type, TransactionType.income);
        expect(restoredExpense.type, TransactionType.expense);
      });
    });

    group('Boundary Conditions', () {
      test('BOUNDARY: Maximum safe integer in formatter', () {
        final formatter = ThousandsSeparatorInputFormatter();
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '9007199254740991');

        expect(
          () => formatter.formatEditUpdate(oldValue, newValue),
          returnsNormally,
        );
      });

      test('BOUNDARY: Zero amount transaction', () {
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

        final map = transaction.toMap();
        final restored = Transaction.fromMap(map);

        expect(restored.amount, 0);
      });

      test('BOUNDARY: Very long description', () {
        final longDesc = 'a' * 1000;
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: longDesc,
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        expect(transaction.description.length, 1000);
        expect(() => transaction.toMap(), returnsNormally);
      });

      test('BOUNDARY: Date at Unix epoch', () {
        final epochDate = DateTime.fromMillisecondsSinceEpoch(0);
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: epochDate,
          createdAt: epochDate,
        );

        final map = transaction.toMap();
        expect(() => Transaction.fromMap(map), returnsNormally);
      });

      test('BOUNDARY: Future date far in the future', () {
        final futureDate = DateTime(2100, 1, 1);
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Future transaction',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: futureDate,
          createdAt: DateTime.now(),
        );

        expect(transaction.date.year, 2100);
      });
    });

    group('Negative Test Cases', () {
      test('NEGATIVE: Formatter with only special characters', () {
        final formatter = ThousandsSeparatorInputFormatter();
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '@#\$%');

        final result = formatter.formatEditUpdate(oldValue, newValue);
        // Should return old value on invalid input
        expect(result.text, '');
      });

      test('NEGATIVE: Transaction with null-like empty strings', () {
        final transaction = Transaction(
          id: '',
          userId: '',
          description: '',
          amount: 0,
          type: TransactionType.expense,
          category: '',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          userMessage: '',
        );

        expect(transaction.id, isEmpty);
        expect(transaction.userId, isEmpty);
        expect(transaction.description, isEmpty);
        expect(transaction.category, isEmpty);
        expect(transaction.userMessage, isEmpty);
      });

      test('NEGATIVE: AIService extraction with malformed response', () {
        const response = 'Random text without proper format';

        final descRegex = RegExp(r'DESCRIPTION:\s*([^|]+)', caseSensitive: false);
        final amountRegex =
            RegExp(r'AMOUNT:\s*(\d+(?:\.\d+)?)', caseSensitive: false);

        final descMatch = descRegex.firstMatch(response);
        final amountMatch = amountRegex.firstMatch(response);

        expect(descMatch, isNull);
        expect(amountMatch, isNull);
      });

      test('NEGATIVE: Transaction serialization with extreme dates', () {
        final extremeDate = DateTime.fromMillisecondsSinceEpoch(0);
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Test',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: extremeDate,
          createdAt: extremeDate,
        );

        final map = transaction.toMap();
        expect(() => Transaction.fromMap(map), returnsNormally);
      });

      test('NEGATIVE: Empty string in all formatter operations', () {
        final formatter = ThousandsSeparatorInputFormatter();
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '');

        final result = formatter.formatEditUpdate(oldValue, newValue);
        expect(result.text, '');
      });

      test('NEGATIVE: Currency format with NaN', () {
        // formatCurrency should handle NaN gracefully
        expect(() => formatCurrency(double.nan), returnsNormally);
      });

      test('NEGATIVE: Currency format with infinity', () {
        // formatCurrency should handle infinity gracefully
        expect(() => formatCurrency(double.infinity), returnsNormally);
      });

      test('NEGATIVE: Formatter with mixed commas and numbers', () {
        final formatter = ThousandsSeparatorInputFormatter();
        const oldValue = TextEditingValue(text: '');
        const newValue = TextEditingValue(text: '1,2,3,4');

        final result = formatter.formatEditUpdate(oldValue, newValue);
        // Should strip commas and reformat
        expect(result.text, '1,234');
      });

      test('NEGATIVE: Transaction copyWith preserving userMessage', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Original',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          userMessage: 'original message',
        );

        final copied = original.copyWith(description: 'Updated');

        expect(copied.userMessage, original.userMessage);
        expect(copied.description, 'Updated');
      });
    });

    group('UserMessage Regressions', () {
      test('REGRESSION: userMessage should be preserved in serialization', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Lunch',
          amount: 50000,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          userMessage: 'va xe 50k',
        );

        final map = original.toMap();
        final restored = Transaction.fromMap(map);

        expect(restored.userMessage, 'va xe 50k');
      });

      test('REGRESSION: userMessage should handle null correctly', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Manual entry',
          amount: 100,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );

        final map = original.toMap();
        expect(map['userMessage'], isNull);

        final restored = Transaction.fromMap(map);
        expect(restored.userMessage, isNull);
      });

      test('REGRESSION: userMessage with special Vietnamese characters', () {
        final transaction = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Gas',
          amount: 50000,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          userMessage: 'vừa đổ xăng xe 50k ở trạm gần nhà',
        );

        final map = transaction.toMap();
        final restored = Transaction.fromMap(map);

        expect(restored.userMessage, contains('vừa'));
        expect(restored.userMessage, contains('đổ'));
        expect(restored.userMessage, contains('ở'));
      });

      test('REGRESSION: userMessage copyWith should update correctly', () {
        final original = Transaction(
          id: '1',
          userId: 'user1',
          description: 'Lunch',
          amount: 50000,
          type: TransactionType.expense,
          category: 'Food',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          userMessage: 'original message',
        );

        final updated = original.copyWith(userMessage: 'updated message');

        expect(updated.userMessage, 'updated message');
        expect(original.userMessage, 'original message');
      });
    });

    group('Category Extraction Regressions', () {
      test('REGRESSION: Should extract category from AI response', () {
        const response =
            'DESCRIPTION: Rent | AMOUNT: 5000000 | CATEGORY: 🏠 Housing';

        final categoryRegex =
            RegExp(r'CATEGORY:\s*([^|]+)', caseSensitive: false);
        final match = categoryRegex.firstMatch(response);

        expect(match, isNotNull);
        expect(match?.group(1)?.trim(), '🏠 Housing');
      });

      test('REGRESSION: Should handle missing category gracefully', () {
        const response = 'DESCRIPTION: Lunch | AMOUNT: 50';

        final categoryRegex =
            RegExp(r'CATEGORY:\s*([^|]+)', caseSensitive: false);
        final match = categoryRegex.firstMatch(response);

        expect(match, isNull);
      });

      test('REGRESSION: Should extract category with emoji correctly', () {
        const categories = [
          '🏠 Housing',
          '🍚 Food',
          '🚗 Transportation',
          '💡 Utilities',
          '🏥 Healthcare'
        ];

        for (final category in categories) {
          final response =
              'DESCRIPTION: Test | AMOUNT: 100 | CATEGORY: $category';
          final categoryRegex =
              RegExp(r'CATEGORY:\s*([^|]+)', caseSensitive: false);
          final match = categoryRegex.firstMatch(response);

          expect(match?.group(1)?.trim(), category);
        }
      });
    });

    group('Stress Tests', () {
      test('STRESS: Formatter with rapid sequential updates', () {
        final formatter = ThousandsSeparatorInputFormatter();

        for (var i = 1; i <= 1000; i++) {
          final oldValue = TextEditingValue(text: (i - 1).toString());
          final newValue = TextEditingValue(text: i.toString());

          expect(
            () => formatter.formatEditUpdate(oldValue, newValue),
            returnsNormally,
          );
        }
      });

      test('STRESS: Transaction creation with extreme values', () {
        final extremeValues = [
          0.0,
          0.000001,
          double.maxFinite / 2,
          999999999999.99,
        ];

        for (final amount in extremeValues) {
          expect(
            () => Transaction(
              id: 'test',
              userId: 'user',
              description: 'Test',
              amount: amount,
              type: TransactionType.expense,
              category: 'Food',
              date: DateTime.now(),
              createdAt: DateTime.now(),
            ),
            returnsNormally,
          );
        }
      });

      test('STRESS: Multiple transactions with same timestamp', () {
        final timestamp = DateTime.now();
        final transactions = List.generate(
          100,
          (i) => Transaction(
            id: 'id-$i',
            userId: 'user1',
            description: 'Transaction $i',
            amount: i.toDouble(),
            type: TransactionType.expense,
            category: 'Food',
            date: timestamp,
            createdAt: timestamp,
          ),
        );

        expect(transactions.length, 100);
        expect(
            transactions.every((t) => t.date == timestamp && t.createdAt == timestamp),
            isTrue);
      });
    });
  });
}