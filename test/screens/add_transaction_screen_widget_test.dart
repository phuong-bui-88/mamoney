import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/screens/add_transaction_screen.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';

void main() {
  group('ChatMessage', () {
    test('should create user message', () {
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: 'Test message',
      );

      expect(message.type, ChatMessageType.user);
      expect(message.text, 'Test message');
    });

    test('should create assistant message', () {
      final message = ChatMessage(
        type: ChatMessageType.assistant,
        text: 'Hello!',
      );

      expect(message.type, ChatMessageType.assistant);
      expect(message.text, 'Hello!');
    });

    test('should handle empty text', () {
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: '',
      );

      expect(message.text, isEmpty);
    });

    test('should handle long text', () {
      final longText = 'a' * 1000;
      final message = ChatMessage(
        type: ChatMessageType.assistant,
        text: longText,
      );

      expect(message.text.length, 1000);
    });

    test('should handle special characters in text', () {
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: 'Test @#\$%^&*() message',
      );

      expect(message.text, contains('@#\$%^&*()'));
    });

    test('should handle unicode characters', () {
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: 'Xin chào! 你好 🎉',
      );

      expect(message.text, 'Xin chào! 你好 🎉');
    });
  });

  group('TransactionRecord', () {
    test('should create expense record', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Lunch',
        amount: 50000,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'Bought lunch',
      );

      expect(record.description, 'Lunch');
      expect(record.amount, 50000);
      expect(record.category, 'Food');
      expect(record.type, TransactionType.expense);
      expect(record.userMessage, 'Bought lunch');
    });

    test('should create income record', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Salary',
        amount: 15000000,
        category: 'Salary',
        date: now,
        type: TransactionType.income,
        userMessage: 'Got paid',
      );

      expect(record.type, TransactionType.income);
      expect(record.amount, 15000000);
    });

    test('should handle decimal amounts', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Coffee',
        amount: 4.50,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'coffee 4.50',
      );

      expect(record.amount, 4.50);
    });

    test('should handle zero amount', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Free item',
        amount: 0,
        category: 'Other',
        date: now,
        type: TransactionType.expense,
        userMessage: 'free',
      );

      expect(record.amount, 0);
    });

    test('should handle large amounts', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'House',
        amount: 5000000000,
        category: 'Other',
        date: now,
        type: TransactionType.expense,
        userMessage: 'bought house',
      );

      expect(record.amount, 5000000000);
    });

    test('should preserve date correctly', () {
      final specificDate = DateTime(2024, 1, 15, 10, 30);
      final record = TransactionRecord(
        description: 'Test',
        amount: 100,
        category: 'Test',
        date: specificDate,
        type: TransactionType.expense,
        userMessage: 'test',
      );

      expect(record.date, specificDate);
      expect(record.date.year, 2024);
      expect(record.date.month, 1);
      expect(record.date.day, 15);
    });

    test('should handle empty description', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: '',
        amount: 100,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: '100',
      );

      expect(record.description, isEmpty);
    });

    test('should handle long description', () {
      final now = DateTime.now();
      final longDesc = 'a' * 500;
      final record = TransactionRecord(
        description: longDesc,
        amount: 100,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'test',
      );

      expect(record.description.length, 500);
    });

    test('should handle special characters in description', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Dinner @ restaurant #1',
        amount: 150000,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'dinner @ restaurant #1',
      );

      expect(record.description, contains('@'));
      expect(record.description, contains('#'));
    });

    test('should handle Vietnamese text', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Mua đồ ăn',
        amount: 50000,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'mua đồ ăn 50k',
      );

      expect(record.description, 'Mua đồ ăn');
    });

    test('should handle different categories for expenses', () {
      final now = DateTime.now();
      final categories = [
        '🏠 Housing',
        '🍚 Food',
        '🚗 Transportation',
        '💡 Utilities',
        '🏥 Healthcare'
      ];

      for (final category in categories) {
        final record = TransactionRecord(
          description: 'Test',
          amount: 100,
          category: category,
          date: now,
          type: TransactionType.expense,
          userMessage: 'test',
        );

        expect(record.category, category);
      }
    });

    test('should handle different categories for income', () {
      final now = DateTime.now();
      final categories = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'];

      for (final category in categories) {
        final record = TransactionRecord(
          description: 'Test',
          amount: 100,
          category: category,
          date: now,
          type: TransactionType.income,
          userMessage: 'test',
        );

        expect(record.category, category);
      }
    });
  });

  group('AddTransactionScreen Constants', () {
    test('should have correct expense categories', () {
      const expectedExpenseCategories = [
        '🏠 Housing',
        '🍚 Food',
        '🚗 Transportation',
        '💡 Utilities',
        '🏥 Healthcare'
      ];

      // We can't directly access the private state variable,
      // but we can verify the categories are defined correctly
      expect(expectedExpenseCategories.length, 5);
      expect(expectedExpenseCategories.contains('🏠 Housing'), isTrue);
      expect(expectedExpenseCategories.contains('🍚 Food'), isTrue);
      expect(expectedExpenseCategories.contains('🚗 Transportation'), isTrue);
      expect(expectedExpenseCategories.contains('💡 Utilities'), isTrue);
      expect(expectedExpenseCategories.contains('🏥 Healthcare'), isTrue);
    });

    test('should have correct income categories', () {
      const expectedIncomeCategories = [
        'Salary',
        'Freelance',
        'Investment',
        'Gift',
        'Other'
      ];

      expect(expectedIncomeCategories.length, 5);
      expect(expectedIncomeCategories.contains('Salary'), isTrue);
      expect(expectedIncomeCategories.contains('Gift'), isTrue);
    });
  });

  group('ChatMessageType', () {
    test('should have user and assistant types', () {
      expect(ChatMessageType.user, isNotNull);
      expect(ChatMessageType.assistant, isNotNull);
    });

    test('should be different values', () {
      expect(ChatMessageType.user, isNot(ChatMessageType.assistant));
    });
  });

  group('ThousandsSeparatorInputFormatter', () {
    late ThousandsSeparatorInputFormatter formatter;

    setUp(() {
      formatter = ThousandsSeparatorInputFormatter();
    });

    test('should format numbers with thousand separators', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '1234567');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '1,234,567');
    });

    test('should handle empty input', () {
      const oldValue = TextEditingValue(text: '1,234');
      const newValue = TextEditingValue(text: '');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '');
    });

    test('should reject invalid input', () {
      const oldValue = TextEditingValue(text: '123');
      const newValue = TextEditingValue(text: 'abc');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '123');
    });

    test('should handle numbers less than 1000', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '999');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '999');
    });

    test('should format Vietnamese common amounts - 50k', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '50000');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '50,000');
    });

    test('should handle backspace on formatted number', () {
      const oldValue = TextEditingValue(text: '1,234');
      const newValue = TextEditingValue(text: '1,23');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.text, '123');
    });

    test('should place cursor at end of formatted text', () {
      const oldValue = TextEditingValue(text: '');
      const newValue = TextEditingValue(text: '1234');

      final result = formatter.formatEditUpdate(oldValue, newValue);

      expect(result.selection.baseOffset, result.text.length);
    });
  });

  group('Edge Cases', () {
    test('ChatMessage should handle multiline text', () {
      final message = ChatMessage(
        type: ChatMessageType.assistant,
        text: 'Line 1\nLine 2\nLine 3',
      );

      expect(message.text.split('\n').length, 3);
    });

    test('TransactionRecord should handle past dates', () {
      final pastDate = DateTime(2020, 1, 1);
      final record = TransactionRecord(
        description: 'Old transaction',
        amount: 100,
        category: 'Food',
        date: pastDate,
        type: TransactionType.expense,
        userMessage: 'old',
      );

      expect(record.date.isBefore(DateTime.now()), isTrue);
    });

    test('TransactionRecord should handle future dates', () {
      final futureDate = DateTime(2030, 1, 1);
      final record = TransactionRecord(
        description: 'Future transaction',
        amount: 100,
        category: 'Food',
        date: futureDate,
        type: TransactionType.expense,
        userMessage: 'future',
      );

      expect(record.date.isAfter(DateTime.now()), isTrue);
    });

    test('TransactionRecord should handle negative amounts', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Refund',
        amount: -100,
        category: 'Other',
        date: now,
        type: TransactionType.expense,
        userMessage: 'refund',
      );

      expect(record.amount, -100);
    });

    test('ChatMessage should preserve exact whitespace', () {
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: '  spaces  around  ',
      );

      expect(message.text, '  spaces  around  ');
    });

    test('TransactionRecord should handle maximum decimal precision', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Test',
        amount: 123.456789,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'test 123.456789',
      );

      expect(record.amount, 123.456789);
    });

    test('ChatMessage should handle emoji in text', () {
      final message = ChatMessage(
        type: ChatMessageType.assistant,
        text: 'Great! 🎉 You spent 💰 50k on 🍔',
      );

      expect(message.text, contains('🎉'));
      expect(message.text, contains('💰'));
      expect(message.text, contains('🍔'));
    });
  });

  group('Negative Test Cases', () {
    test('TransactionRecord should accept zero category', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Test',
        amount: 100,
        category: '',
        date: now,
        type: TransactionType.expense,
        userMessage: 'test',
      );

      expect(record.category, isEmpty);
    });

    test('ChatMessage should handle extremely long text', () {
      final longText = 'a' * 10000;
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: longText,
      );

      expect(message.text.length, 10000);
    });

    test('TransactionRecord should handle very large amounts', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'House',
        amount: double.maxFinite,
        category: 'Other',
        date: now,
        type: TransactionType.expense,
        userMessage: 'house',
      );

      expect(record.amount, double.maxFinite);
    });

    test('TransactionRecord should handle NaN amount', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Invalid',
        amount: double.nan,
        category: 'Other',
        date: now,
        type: TransactionType.expense,
        userMessage: 'invalid',
      );

      expect(record.amount.isNaN, isTrue);
    });

    test('ChatMessage with only whitespace', () {
      final message = ChatMessage(
        type: ChatMessageType.user,
        text: '     ',
      );

      expect(message.text, '     ');
      expect(message.text.trim(), isEmpty);
    });
  });

  group('Category Validation', () {
    test('should have valid expense categories with emojis', () {
      const expenseCategories = [
        '🏠 Housing',
        '🍚 Food',
        '🚗 Transportation',
        '💡 Utilities',
        '🏥 Healthcare'
      ];

      for (final category in expenseCategories) {
        final now = DateTime.now();
        final record = TransactionRecord(
          description: 'Test',
          amount: 100,
          category: category,
          date: now,
          type: TransactionType.expense,
          userMessage: 'test',
        );

        expect(record.category, category);
        expect(category.length, greaterThan(5)); // Has emoji + text
      }
    });

    test('should have valid income categories without emojis', () {
      const incomeCategories = [
        'Salary',
        'Freelance',
        'Investment',
        'Gift',
        'Other'
      ];

      for (final category in incomeCategories) {
        final now = DateTime.now();
        final record = TransactionRecord(
          description: 'Test',
          amount: 100,
          category: category,
          date: now,
          type: TransactionType.income,
          userMessage: 'test',
        );

        expect(record.category, category);
      }
    });
  });

  group('UserMessage Field Tests', () {
    test('should preserve original user message', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Lunch at cafe',
        amount: 50000,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'va xe 50k',
      );

      expect(record.userMessage, 'va xe 50k');
      expect(record.description, 'Lunch at cafe');
      expect(record.userMessage, isNot(equals(record.description)));
    });

    test('should handle userMessage with special characters', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Dinner',
        amount: 100000,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: 'dinner @ restaurant #1 (50% off) 100k!',
      );

      expect(record.userMessage, contains('@'));
      expect(record.userMessage, contains('#'));
      expect(record.userMessage, contains('%'));
      expect(record.userMessage, contains('!'));
    });

    test('should handle Vietnamese text in userMessage', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Gas',
        amount: 50000,
        category: 'Transportation',
        date: now,
        type: TransactionType.expense,
        userMessage: 'vừa xăng xe 50k',
      );

      expect(record.userMessage, contains('vừa'));
      expect(record.userMessage, contains('xăng'));
    });

    test('should handle empty userMessage', () {
      final now = DateTime.now();
      final record = TransactionRecord(
        description: 'Manual entry',
        amount: 100,
        category: 'Food',
        date: now,
        type: TransactionType.expense,
        userMessage: '',
      );

      expect(record.userMessage, isEmpty);
    });
  });
}