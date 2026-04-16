import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/utils/input_formatters.dart';

/// Widget to display and inline-edit a transaction item in the invoice preview
class EditableTransactionListItem extends StatefulWidget {
  final Transaction transaction;
  final int index;
  final VoidCallback onDelete;
  final Function(Transaction) onUpdate;
  final Map<String, String> categoryEmojis;

  const EditableTransactionListItem({
    super.key,
    required this.transaction,
    required this.index,
    required this.onDelete,
    required this.onUpdate,
    required this.categoryEmojis,
  });

  @override
  State<EditableTransactionListItem> createState() =>
      _EditableTransactionListItemState();
}

class _EditableTransactionListItemState
    extends State<EditableTransactionListItem> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late FocusNode _descriptionFocus;
  late FocusNode _amountFocus;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.transaction.description);
    _amountController = TextEditingController(
      text: widget.transaction.amount.toStringAsFixed(0),
    );
    _descriptionFocus = FocusNode();
    _amountFocus = FocusNode();

    // Listen for changes and update parent
    _descriptionController.addListener(_updateTransaction);
    _amountController.addListener(_updateTransaction);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _descriptionFocus.dispose();
    _amountFocus.dispose();
    super.dispose();
  }

  void _updateTransaction() {
    try {
      final amount = double.tryParse(
            _amountController.text.replaceAll(',', '').replaceAll('.', ''),
          ) ??
          0;

      if (_descriptionController.text.isEmpty || amount <= 0) {
        return; // Don't update if invalid
      }

      final updated = widget.transaction.copyWith(
        description: _descriptionController.text,
        amount: amount,
      );
      widget.onUpdate(updated);
    } catch (_) {
      // Silently ignore parsing errors during typing
    }
  }

  String _getCategoryEmoji(String category) {
    return widget.categoryEmojis[category] ?? '📦';
  }

  String _getTypeLabel() {
    return widget.transaction.type == TransactionType.income
        ? 'Income'
        : 'Expense';
  }

  Color _getTypeColor() {
    return widget.transaction.type == TransactionType.income
        ? Colors.green
        : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDarkMode ? Colors.grey[800] : Colors.grey[100];
    final borderColor = isDarkMode ? Colors.grey[700] : Colors.grey[300];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border.all(color: borderColor ?? Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Category emoji
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _getTypeColor().withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              _getCategoryEmoji(widget.transaction.category),
              style: const TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Details section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Type badge and description
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor().withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _getTypeColor(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.transaction.category,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Editable description field
                TextField(
                  controller: _descriptionController,
                  focusNode: _descriptionFocus,
                  decoration: InputDecoration(
                    hintText: 'Description',
                    hintStyle: TextStyle(
                      color: isDarkMode ? Colors.grey[600] : Colors.grey[400],
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[700] : Colors.white,
                  ),
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Amount section
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _amountController,
                  focusNode: _amountFocus,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(
                    hintText: '0',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? Colors.grey[700] : Colors.white,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.transaction.type == TransactionType.income
                        ? Colors.green
                        : Colors.red,
                  ),
                  textAlign: TextAlign.right,
                ),
                const SizedBox(height: 8),
                Text(
                  'VND',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: widget.onDelete,
            tooltip: 'Delete transaction',
          ),
        ],
      ),
    );
  }
}
