import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/models/transaction.dart';

void main() {
  group('TransactionProvider', () {
    late TransactionProvider provider;

    setUp(() {
      provider = TransactionProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    group('Initialization', () {
      test('should initialize with empty transactions list', () {
        expect(provider.transactions, isEmpty);
      });

      test('should initialize with loading false', () {
        expect(provider.isLoading, isFalse);
      });

      test('should initialize with no error', () {
        expect(provider.error, isNull);
      });
    });

    group('Computed properties', () {
      test('should calculate total income correctly', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Salary',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Freelance',
            amount: 500,
            type: TransactionType.income,
            category: 'Freelance',
            date: now,
            createdAt: now,
          ),
        ];

        // Simulate transactions being set
        provider.transactions.addAll(mockTransactions);

        expect(provider.totalIncome, 1500);
      });

      test('should calculate total expense correctly', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Food',
            amount: 100,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Transport',
            amount: 50,
            type: TransactionType.expense,
            category: 'Transport',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.totalExpense, 150);
      });

      test('should calculate balance correctly', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Salary',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Food',
            amount: 300,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.balance, 700);
      });

      test('should handle zero balance', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Salary',
            amount: 500,
            type: TransactionType.income,
            category: 'Salary',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Food',
            amount: 500,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.balance, 0);
      });

      test('should handle negative balance', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Salary',
            amount: 100,
            type: TransactionType.income,
            category: 'Salary',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Food',
            amount: 500,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.balance, -400);
      });
    });

    group('getTransactionsByCategory', () {
      test('should filter transactions by category', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Lunch',
            amount: 50,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Dinner',
            amount: 100,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '3',
            userId: 'user1',
            description: 'Taxi',
            amount: 30,
            type: TransactionType.expense,
            category: 'Transport',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        final foodTransactions = provider.getTransactionsByCategory('Food');

        expect(foodTransactions.length, 2);
        expect(foodTransactions.every((t) => t.category == 'Food'), isTrue);
      });

      test('should return empty list for non-existent category', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Lunch',
            amount: 50,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        final result = provider.getTransactionsByCategory('NonExistent');

        expect(result, isEmpty);
      });

      test('should be case-sensitive when filtering', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Lunch',
            amount: 50,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        final result = provider.getTransactionsByCategory('food');

        expect(result, isEmpty);
      });
    });

    group('Edge cases', () {
      test('should handle empty transactions for totalIncome', () {
        expect(provider.totalIncome, 0);
      });

      test('should handle empty transactions for totalExpense', () {
        expect(provider.totalExpense, 0);
      });

      test('should handle empty transactions for balance', () {
        expect(provider.balance, 0);
      });

      test('should handle only income transactions', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Salary',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.totalIncome, 1000);
        expect(provider.totalExpense, 0);
        expect(provider.balance, 1000);
      });

      test('should handle only expense transactions', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Food',
            amount: 500,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.totalIncome, 0);
        expect(provider.totalExpense, 500);
        expect(provider.balance, -500);
      });

      test('should handle very large amounts', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Big income',
            amount: 999999999.99,
            type: TransactionType.income,
            category: 'Salary',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.totalIncome, 999999999.99);
      });

      test('should handle decimal amounts correctly', () {
        final now = DateTime.now();
        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Coffee',
            amount: 4.50,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Snack',
            amount: 2.25,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.totalExpense, closeTo(6.75, 0.001));
      });

      test('should handle multiple transactions of same category', () {
        final now = DateTime.now();
        final mockTransactions = List.generate(
          100,
          (i) => Transaction(
            id: 'id_$i',
            userId: 'user1',
            description: 'Transaction $i',
            amount: 10,
            type: TransactionType.expense,
            category: 'Food',
            date: now,
            createdAt: now,
          ),
        );

        provider.transactions.addAll(mockTransactions);

        final foodTransactions = provider.getTransactionsByCategory('Food');
        expect(foodTransactions.length, 100);
        expect(provider.totalExpense, 1000);
      });
    });

    group('Provider state management', () {
      test('should not be loading initially', () {
        expect(provider.isLoading, isFalse);
      });

      test('should have no error initially', () {
        expect(provider.error, isNull);
      });
    });

    group('Transaction Filtering', () {
      test('should filter transactions by month by default', () {
        final now = DateTime.now();
        final currentMonth = now;
        final nextMonth = DateTime(now.year, now.month + 1, 1);

        final mockTransactions = [
          // Current month
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Current month income',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: currentMonth,
            createdAt: currentMonth,
          ),
          // Next month
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Next month expense',
            amount: 500,
            type: TransactionType.expense,
            category: 'Food',
            date: nextMonth,
            createdAt: nextMonth,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.filterType, FilterType.month);
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.description,
            'Current month income');
      });

      test('should filter transactions by year when filterType is year', () {
        final now = DateTime.now();
        final currentYear = DateTime(now.year, 1, 1);
        final nextYear = DateTime(now.year + 1, 1, 1);

        final mockTransactions = [
          // Current year
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Current year income',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: currentYear,
            createdAt: currentYear,
          ),
          // Next year
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Next year expense',
            amount: 500,
            type: TransactionType.expense,
            category: 'Food',
            date: nextYear,
            createdAt: nextYear,
          ),
        ];

        provider.transactions.addAll(mockTransactions);
        provider.setFilterType(FilterType.year);

        expect(provider.filterType, FilterType.year);
        expect(provider.filteredTransactions.length, 1);
        expect(provider.filteredTransactions.first.description,
            'Current year income');
      });

      test('should calculate filtered total income correctly', () {
        final now = DateTime.now();
        final currentMonth = now;
        final nextMonth = DateTime(now.year, now.month + 1, 1);

        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Current month income',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: currentMonth,
            createdAt: currentMonth,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Next month income',
            amount: 500,
            type: TransactionType.income,
            category: 'Bonus',
            date: nextMonth,
            createdAt: nextMonth,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.filteredTotalIncome, 1000);
        expect(provider.totalIncome, 1500);
      });

      test('should calculate filtered total expense correctly', () {
        final now = DateTime.now();
        final currentMonth = now;
        final nextMonth = DateTime(now.year, now.month + 1, 1);

        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Current month expense',
            amount: 300,
            type: TransactionType.expense,
            category: 'Food',
            date: currentMonth,
            createdAt: currentMonth,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Next month expense',
            amount: 200,
            type: TransactionType.expense,
            category: 'Transport',
            date: nextMonth,
            createdAt: nextMonth,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.filteredTotalExpense, 300);
        expect(provider.totalExpense, 500);
      });

      test('should calculate filtered balance correctly', () {
        final now = DateTime.now();
        final currentMonth = now;
        final nextMonth = DateTime(now.year, now.month + 1, 1);

        final mockTransactions = [
          Transaction(
            id: '1',
            userId: 'user1',
            description: 'Current month income',
            amount: 1000,
            type: TransactionType.income,
            category: 'Salary',
            date: currentMonth,
            createdAt: currentMonth,
          ),
          Transaction(
            id: '2',
            userId: 'user1',
            description: 'Current month expense',
            amount: 300,
            type: TransactionType.expense,
            category: 'Food',
            date: currentMonth,
            createdAt: currentMonth,
          ),
          Transaction(
            id: '3',
            userId: 'user1',
            description: 'Next month income',
            amount: 500,
            type: TransactionType.income,
            category: 'Bonus',
            date: nextMonth,
            createdAt: nextMonth,
          ),
        ];

        provider.transactions.addAll(mockTransactions);

        expect(provider.filteredBalance, 700);
        expect(provider.balance, 1200);
      });

      test('setSelectedDate should update the selected date', () {
        final newDate = DateTime(2024, 5, 15);
        provider.setSelectedDate(newDate);

        expect(provider.selectedDate, newDate);
      });

      test('setFilterType should update the filter type', () {
        expect(provider.filterType, FilterType.month);
        provider.setFilterType(FilterType.year);
        expect(provider.filterType, FilterType.year);
      });

      test('should handle empty filtered transactions', () {
        final futureDate = DateTime(2099, 1, 1);
        provider.setSelectedDate(futureDate);

        expect(provider.filteredTransactions, isEmpty);
        expect(provider.filteredTotalIncome, 0);
        expect(provider.filteredTotalExpense, 0);
        expect(provider.filteredBalance, 0);
      });
    });
  });
}
