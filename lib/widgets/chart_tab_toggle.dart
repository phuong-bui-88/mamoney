import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';

/// Custom toggle button widget for switching between Income and Expense chart tabs
class ChartTabToggle extends StatelessWidget {
  final TransactionType selectedTab;
  final ValueChanged<TransactionType> onTabChanged;

  const ChartTabToggle({
    required this.selectedTab,
    required this.onTabChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final isExpenseSelected = selectedTab == TransactionType.expense;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // Expense button
          Expanded(
            child: _TabButton(
              label: 'Expense',
              isSelected: isExpenseSelected,
              onPressed: () => onTabChanged(TransactionType.expense),
            ),
          ),
          const SizedBox(width: 12),
          // Income button
          Expanded(
            child: _TabButton(
              label: 'Income',
              isSelected: !isExpenseSelected,
              onPressed: () => onTabChanged(TransactionType.income),
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual tab button widget
class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  const _TabButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF00BCD4) : Colors.grey[200],
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF00BCD4)
                          .withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }
}
