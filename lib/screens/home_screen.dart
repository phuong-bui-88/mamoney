import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/auth_provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/screens/add_transaction_screen.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:mamoney/widgets/category_chart_section.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Reset the transaction provider to ensure it loads the current user's transactions
    context.read<TransactionProvider>().reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            final email = authProvider.user?.email ?? 'User';
            return Text(
              'MaMoney - $email',
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().signOut();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Consumer<TransactionProvider>(
                builder: (context, transactionProvider, _) {
                  return Column(
                    children: [
                      // Filter Section - Single Row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
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
                                        transactionProvider
                                            .setFilterType(newValue);
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
                                      _selectMonthYear(
                                          context, transactionProvider);
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

                      // Filtered Balance Card
                      Card(
                        elevation: 4,
                        color: Colors.blue,
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            children: [
                              const Text(
                                'Total Balance',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                formatCurrency(
                                    transactionProvider.filteredBalance),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Filtered Income and Expense Summary
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Colors.green,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Income',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      formatCurrency(transactionProvider
                                          .filteredTotalIncome),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              color: Colors.red,
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    const Text(
                                      'Expense',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      formatCurrency(transactionProvider
                                          .filteredTotalExpense),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Category breakdown charts with tabbed interface
                      CategoryChartSection(
                        transactionProvider: transactionProvider,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
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
                              icon: const Icon(Icons.keyboard_arrow_up,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear < 2030) {
                                    selectedYear++;
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
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear > 2020) {
                                    selectedYear--;
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
                              icon: const Icon(Icons.keyboard_arrow_up,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear < 2030) {
                                    selectedYear++;
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
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear > 2020) {
                                    selectedYear--;
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
