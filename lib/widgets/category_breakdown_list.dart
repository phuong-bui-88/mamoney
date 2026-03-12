import 'package:flutter/material.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:mamoney/utils/currency_utils.dart' show formatCurrency;

/// Widget that displays a list of categories with their amounts and percentages
class CategoryBreakdownList extends StatelessWidget {
  final Map<String, double> categoryData;
  final double totalAmount;
  final bool isIncome;

  const CategoryBreakdownList({
    required this.categoryData,
    required this.totalAmount,
    required this.isIncome,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (categoryData.isEmpty || totalAmount == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Text(
            isIncome ? 'No income data' : 'No expense data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    // Sort categories by amount in descending order
    final sortedCategories = categoryData.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          ...sortedCategories.map((entry) {
            final categoryName = entry.key;
            final amount = entry.value;
            final percentage = (amount / totalAmount * 100);

            final categoryInfo =
                CategoryConstants.parseCategory(categoryName);
            final emoji = categoryInfo['emoji'] ?? '';
            final name = categoryInfo['name'] ?? categoryName;
            final color = CategoryConstants.getCategoryColor(
              categoryName,
              isIncome,
            );

            return _CategoryBreakdownItem(
              emoji: emoji,
              categoryName: name,
              amount: amount,
              percentage: percentage,
              color: color,
            );
          }),
        ],
      ),
    );
  }
}

/// Individual category breakdown item widget
class _CategoryBreakdownItem extends StatelessWidget {
  final String emoji;
  final String categoryName;
  final double amount;
  final double percentage;
  final int color;

  const _CategoryBreakdownItem({
    required this.emoji,
    required this.categoryName,
    required this.amount,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Column(
        children: [
          Row(
            children: [
              // Category emoji and name
              if (emoji.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              Expanded(
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Amount
              Text(
                formatCurrency(amount),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Percentage bar
          Row(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    // Background bar
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    // Filled bar
                    Container(
                      height: 8,
                      width: MediaQuery.of(context).size.width *
                          (percentage / 100) *
                          0.7, // Account for margins and percentage text
                      decoration: BoxDecoration(
                        color: Color(color),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Percentage text
              SizedBox(
                width: 45,
                child: Text(
                  '${percentage.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
