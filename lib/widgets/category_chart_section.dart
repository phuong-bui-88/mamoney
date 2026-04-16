import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/widgets/category_pie_chart.dart';
import 'package:mamoney/widgets/chart_tab_toggle.dart';
import 'package:mamoney/widgets/category_breakdown_list.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/screens/transaction_list_screen.dart';

class CategoryChartSection extends StatefulWidget {
  final TransactionProvider transactionProvider;

  const CategoryChartSection({
    super.key,
    required this.transactionProvider,
  });

  @override
  State<CategoryChartSection> createState() => _CategoryChartSectionState();
}

class _CategoryChartSectionState extends State<CategoryChartSection> {
  late TransactionType _selectedTabType;

  @override
  void initState() {
    super.initState();
    _selectedTabType = TransactionType.expense;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Category breakdown charts with tabbed interface
        ChartTabToggle(
          selectedTab: _selectedTabType,
          onTabChanged: (TransactionType newTab) {
            setState(() {
              _selectedTabType = newTab;
            });
          },
        ),
        const SizedBox(height: 12),
        // Pie chart based on selected tab
        _selectedTabType == TransactionType.income
            ? CategoryPieChart(
                title: 'Income by Category',
                categoryData:
                    widget.transactionProvider.getIncomeCategoryBreakdown(),
                colors: const [
                  Color(0xFF4CAF50),
                  Color(0xFF66BB6A),
                  Color(0xFF81C784),
                  Color(0xFFA5D6A7),
                  Color(0xFFFFeb3b),
                ],
                onCategoryTap: (category) {
                  _navigateToTransactionsList(context, category);
                },
              )
            : CategoryPieChart(
                title: 'Expenses by Category',
                categoryData:
                    widget.transactionProvider.getExpenseCategoryBreakdown(),
                colors: const [
                  Color(0xFFF44336),
                  Color(0xFFEF5350),
                  Color(0xFFE57373),
                  Color(0xFFEF9A9A),
                  Color(0xFFFF9800),
                ],
                onCategoryTap: (category) {
                  _navigateToTransactionsList(context, category);
                },
              ),
        const SizedBox(height: 8),
        // Category breakdown list
        _selectedTabType == TransactionType.income
            ? CategoryBreakdownList(
                categoryData:
                    widget.transactionProvider.getIncomeCategoryBreakdown(),
                totalAmount: widget.transactionProvider.filteredTotalIncome,
                isIncome: true,
              )
            : CategoryBreakdownList(
                categoryData:
                    widget.transactionProvider.getExpenseCategoryBreakdown(),
                totalAmount: widget.transactionProvider.filteredTotalExpense,
                isIncome: false,
              ),
      ],
    );
  }

  void _navigateToTransactionsList(BuildContext context, String category) {
    // Set the selected category filter
    context.read<TransactionProvider>().setSelectedCategory(category);

    // Navigate to transactions list screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TransactionListScreen(),
      ),
    );
  }
}
