import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/models/invoice_preview_state.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:mamoney/widgets/editable_transaction_list_item.dart';

/// Screen to preview and edit transactions extracted from an invoice
class InvoicePreviewScreen extends StatefulWidget {
  final InvoicePreviewState initialPreviewState;

  const InvoicePreviewScreen({
    super.key,
    required this.initialPreviewState,
  });

  @override
  State<InvoicePreviewScreen> createState() => _InvoicePreviewScreenState();
}

class _InvoicePreviewScreenState extends State<InvoicePreviewScreen> {
  late InvoicePreviewState _previewState;
  bool _isSaving = false;

  /// Map of category names to emojis
  final Map<String, String> _categoryEmojis = {
    ...CategoryConstants.incomeCategories
        .asMap()
        .entries
        .fold({}, (acc, e) => acc..addAll({e.value: '💰'})),
    ...CategoryConstants.expenseCategories
        .asMap()
        .entries
        .fold({}, (acc, e) => acc..addAll({e.value: '💸'})),
  };

  @override
  void initState() {
    super.initState();
    _previewState = widget.initialPreviewState;
  }

  void _handleTransactionUpdate(int index, Transaction updatedTransaction) {
    setState(() {
      _previewState = _previewState.updateTransaction(index, updatedTransaction);
    });
  }

  void _handleTransactionDelete(int index) {
    setState(() {
      _previewState = _previewState.removeTransaction(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction removed'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleAddTransaction() {
    _showAddTransactionDialog();
  }

  void _showAddTransactionDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddTransactionDialog(
        categoryEmojis: _categoryEmojis,
        onAdd: (transaction) {
          setState(() {
            _previewState = _previewState.addTransaction(transaction);
          });
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaction added'),
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleSaveAll() async {
    if (_previewState.transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions to save'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Validate all transactions
    for (final tx in _previewState.transactions) {
      if (tx.description.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transactions must have a description'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
      if (tx.amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All transaction amounts must be greater than 0'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final provider =
          Provider.of<TransactionProvider>(context, listen: false);
      provider.setInvoicePreview(_previewState);
      await provider.savePreviewTransactions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully saved ${_previewState.transactions.length} transactions',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Pop with success flag
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving transactions: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _handleCancel() {
    Navigator.pop(context, false);
  }

  String _formatCurrency(double amount) {
    return NumberFormat('#,##0', 'vi_VN').format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Invoice'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isSaving ? null : _handleCancel,
        ),
      ),
      body: Column(
        children: [
          // Invoice metadata header
          Container(
            color: isDarkMode ? Colors.grey[900] : Colors.blue[50],
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Invoice details
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Invoice Date',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('MMM dd, yyyy')
                                .format(_previewState.invoiceDate),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Items',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_previewState.getItemCount()}',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Total amount
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Amount',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_formatCurrency(_previewState.getTotalAmount())} VND',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Transactions list
          Expanded(
            child: _previewState.transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox,
                          size: 64,
                          color: isDarkMode
                              ? Colors.grey[600]
                              : Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transactions',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _previewState.transactions.length,
                    itemBuilder: (context, index) {
                      final transaction = _previewState.transactions[index];
                      return EditableTransactionListItem(
                        transaction: transaction,
                        index: index,
                        categoryEmojis: _categoryEmojis,
                        onUpdate: (updated) =>
                            _handleTransactionUpdate(index, updated),
                        onDelete: () => _handleTransactionDelete(index),
                      );
                    },
                  ),
          ),
          // Action buttons
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Add item button
                OutlinedButton.icon(
                  onPressed: _isSaving ? null : _handleAddTransaction,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
                const SizedBox(height: 12),
                // Save All button
                ElevatedButton.icon(
                  onPressed: _isSaving ? null : _handleSaveAll,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _isSaving ? 'Saving...' : 'Save All',
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel button
                OutlinedButton(
                  onPressed: _isSaving ? null : _handleCancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog for adding a new transaction
class _AddTransactionDialog extends StatefulWidget {
  final Map<String, String> categoryEmojis;
  final Function(Transaction) onAdd;

  const _AddTransactionDialog({
    required this.categoryEmojis,
    required this.onAdd,
  });

  @override
  State<_AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<_AddTransactionDialog> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  String _selectedCategory = CategoryConstants.expenseCategories.first;
  TransactionType _selectedType = TransactionType.expense;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    _amountController = TextEditingController();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _handleAdd() {
    final description = _descriptionController.text.trim();
    final amountStr =
        _amountController.text.replaceAll(',', '').replaceAll('.', '');
    final amount = double.tryParse(amountStr);

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description is required'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid amount'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final transaction = Transaction(
      id: '', // Will be generated by Firebase
      userId: '', // Will be set by provider
      description: description,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      date: now,
      createdAt: now,
    );

    widget.onAdd(transaction);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Transaction',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              // Description field
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Amount field
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixText: 'VND',
                ),
              ),
              const SizedBox(height: 16),
              // Type selector
              Text(
                'Type',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<TransactionType>(
                      title: const Text('Income'),
                      value: TransactionType.income,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<TransactionType>(
                      title: const Text('Expense'),
                      value: TransactionType.expense,
                      groupValue: _selectedType,
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value!;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Category selector
              Text(
                'Category',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 8),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedCategory,
                items: (_selectedType == TransactionType.income
                        ? CategoryConstants.incomeCategories
                        : CategoryConstants.expenseCategories)
                    .map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value!;
                  });
                },
              ),
              const SizedBox(height: 24),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: _handleAdd,
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
