import 'package:flutter_test/flutter_test.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/transaction_filter.dart';

void main() {
  group('TransactionFilter', () {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    final incomeTransaction = Transaction(
      id: '1',
      userId: 'user1',
      description: 'Salary',
      amount: 1000,
      type: TransactionType.income,
      category: 'Salary',
      date: now,
      createdAt: now,
    );

    final expenseTransaction = Transaction(
      id: '2',
      userId: 'user1',
      description: 'Grocery',
      amount: 50,
      type: TransactionType.expense,
      category: 'Food',
      date: yesterday,
      createdAt: yesterday,
    );

    test('Empty filter matches all transactions', () {
      final filter = TransactionFilter();
      expect(filter.matches(incomeTransaction), true);
      expect(filter.matches(expenseTransaction), true);
      expect(filter.isEmpty, true);
    });

    test('Type filter matches transaction type', () {
      final incomeFilter = TransactionFilter(type: TransactionType.income);
      expect(incomeFilter.matches(incomeTransaction), true);
      expect(incomeFilter.matches(expenseTransaction), false);
    });

    test('Category filter matches category', () {
      final salaryFilter = TransactionFilter(category: 'Salary');
      expect(salaryFilter.matches(incomeTransaction), true);
      expect(salaryFilter.matches(expenseTransaction), false);
    });

    test('Date range filter works', () {
      final dateFilter = TransactionFilter(
        startDate: yesterday,
        endDate: now,
      );
      expect(dateFilter.matches(incomeTransaction), true);
      expect(dateFilter.matches(expenseTransaction), true);

      final restrictedFilter = TransactionFilter(
        startDate: now,
        endDate: tomorrow,
      );
      expect(restrictedFilter.matches(incomeTransaction), true);
      expect(restrictedFilter.matches(expenseTransaction), false);
    });

    test('Amount range filter works', () {
      final amountFilter = TransactionFilter(
        minAmount: 100,
        maxAmount: 1500,
      );
      expect(amountFilter.matches(incomeTransaction), true);
      expect(amountFilter.matches(expenseTransaction), false);
    });

    test('Combined filters work', () {
      final combinedFilter = TransactionFilter(
        type: TransactionType.income,
        category: 'Salary',
        minAmount: 500,
      );
      expect(combinedFilter.matches(incomeTransaction), true);
      expect(combinedFilter.matches(expenseTransaction), false);
    });

    test('copyWith creates new filter with updated values', () {
      final filter1 = TransactionFilter(type: TransactionType.income);
      final filter2 = filter1.copyWith(category: 'Salary');
      
      expect(filter1.type, TransactionType.income);
      expect(filter1.category, null);
      expect(filter2.type, TransactionType.income);
      expect(filter2.category, 'Salary');
    });
  });
}
