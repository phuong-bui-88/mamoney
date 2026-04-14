import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';

/// Widget for selecting transaction type (Income/Expense)
class TransactionTypeSelector extends StatelessWidget {
  final TransactionType selectedType;
  final Function(TransactionType) onTypeChanged;
  final bool isEnabled;

  const TransactionTypeSelector({
    required this.selectedType,
    required this.onTypeChanged,
    this.isEnabled = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap:
                isEnabled ? () => onTypeChanged(TransactionType.income) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: selectedType == TransactionType.income
                    ? Colors.green
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: selectedType == TransactionType.income
                    ? Border.all(color: Colors.green.shade700, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_downward,
                    color: selectedType == TransactionType.income
                        ? Colors.white
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Income',
                    style: TextStyle(
                      color: selectedType == TransactionType.income
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap:
                isEnabled ? () => onTypeChanged(TransactionType.expense) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              decoration: BoxDecoration(
                color: selectedType == TransactionType.expense
                    ? Colors.red
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: selectedType == TransactionType.expense
                    ? Border.all(color: Colors.red.shade700, width: 2)
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward,
                    color: selectedType == TransactionType.expense
                        ? Colors.white
                        : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expense',
                    style: TextStyle(
                      color: selectedType == TransactionType.expense
                          ? Colors.white
                          : Colors.grey,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
