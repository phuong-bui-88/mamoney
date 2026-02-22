import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:mamoney/screens/edit_transaction_screen.dart';
import 'package:mamoney/screens/add_transaction_screen.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, transactionProvider, _) {
          return Column(
            children: [
              // Filter Section - Single Row
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Filter Type Selector (Month or Year)
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<FilterType>(
                            value: transactionProvider.filterType,
                            isExpanded: true,
                            onChanged: (FilterType? newValue) {
                              if (newValue != null) {
                                transactionProvider.setFilterType(newValue);
                              }
                            },
                            items: const [
                              DropdownMenuItem(
                                value: FilterType.month,
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_month,
                                        size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Month'),
                                  ],
                                ),
                              ),
                              DropdownMenuItem(
                                value: FilterType.year,
                                child: Row(
                                  children: [
                                    Icon(Icons.calendar_today,
                                        size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('Year'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Date Selector based on Filter Type
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            if (transactionProvider.filterType ==
                                FilterType.month) {
                              _selectMonthYear(context, transactionProvider);
                            } else {
                              _selectYear(context, transactionProvider);
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Icon(
                                transactionProvider.filterType ==
                                        FilterType.month
                                    ? Icons.calendar_month
                                    : Icons.calendar_today,
                                size: 20,
                                color: Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getFormattedDate(
                                    transactionProvider.filterType,
                                    transactionProvider.selectedDate),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Totals Section
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Total Expense
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Expense',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(
                                transactionProvider.filteredTotalExpense),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      // Total Income
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Income',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(
                                transactionProvider.filteredTotalIncome),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      // Balance (Income - Expense)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Balance',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(transactionProvider.filteredBalance),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: transactionProvider.filteredBalance >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(),
              // Transactions List
              Expanded(
                child: transactionProvider.filteredTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 48,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No transactions found',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount:
                            transactionProvider.filteredTransactions.length,
                        itemBuilder: (context, index) {
                          final transaction =
                              transactionProvider.filteredTransactions[index];
                          return Dismissible(
                            key: Key(transaction.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              color: Colors.red,
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 16),
                              child: const Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                            onDismissed: (direction) {
                              transactionProvider
                                  .deleteTransaction(transaction.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Transaction deleted successfully')),
                              );
                            },
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => EditTransactionScreen(
                                      transaction: transaction,
                                    ),
                                  ),
                                );
                              },
                              child: ListTile(
                                leading: Icon(
                                  transaction.type.toString().contains('income')
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: transaction.type
                                          .toString()
                                          .contains('income')
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                title: Text(transaction.description),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(transaction.category),
                                    Text(
                                      DateFormat('MMM dd, yyyy')
                                          .format(transaction.date),
                                    ),
                                  ],
                                ),
                                trailing: Text(
                                  '${transaction.type.toString().contains('income') ? '' : '-'}${formatCurrency(transaction.amount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: transaction.type
                                            .toString()
                                            .contains('income')
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _selectMonthYear(BuildContext context, TransactionProvider provider) {
    final currentDate = provider.selectedDate;
    int selectedMonth = currentDate.month;
    int selectedYear = currentDate.year;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with selected month and year
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${_getMonthName(selectedMonth)} $selectedYear',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Year with controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.expand_less,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear > 2020) {
                                    selectedYear--;
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            Text(
                              selectedYear.toString(),
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.expand_more,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear < 2030) {
                                    selectedYear++;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content area with month selector
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Month grid
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 4,
                          childAspectRatio: 1.0,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: List.generate(12, (index) {
                            final month = index + 1;
                            final isSelected = selectedMonth == month;
                            return GestureDetector(
                              onTap: () {
                                final newDate =
                                    DateTime(selectedYear, month, 1);
                                provider.setSelectedDate(newDate);
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.transparent,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  _getMonthName(month),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color:
                                        isSelected ? Colors.white : Colors.blue,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons (Cancel only - selection auto-submits)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectYear(BuildContext context, TransactionProvider provider) {
    final currentDate = provider.selectedDate;
    int selectedYear = currentDate.year;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with selected year
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Select Year',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Year with controls
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.expand_less,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear > 2020) {
                                    selectedYear--;
                                  }
                                });
                              },
                            ),
                            const SizedBox(width: 16),
                            Text(
                              selectedYear.toString(),
                              style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 16),
                            IconButton(
                              icon: const Icon(Icons.expand_more,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear < 2030) {
                                    selectedYear++;
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Content area
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Year grid (5 years per row)
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          children: List.generate(11, (index) {
                            final year = 2020 + index;
                            final isSelected = selectedYear == year;
                            return GestureDetector(
                              onTap: () {
                                final newDate = DateTime(year, 1, 1);
                                provider.setSelectedDate(newDate);
                                Navigator.pop(context);
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.blue
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(
                                          color: Colors.blue,
                                          width: 2,
                                        )
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  year.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  // Action buttons (Cancel only - selection auto-submits)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getMonthName(int month) {
    const monthNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return monthNames[month - 1];
  }

  String _getFormattedDate(FilterType filterType, DateTime date) {
    try {
      if (filterType == FilterType.month) {
        return DateFormat('MMM yyyy').format(date);
      } else {
        return date.year.toString();
      }
    } catch (e) {
      return 'Select Date';
    }
  }
}
