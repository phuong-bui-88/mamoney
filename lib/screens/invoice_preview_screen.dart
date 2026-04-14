import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/models/invoice_preview_state.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:mamoney/widgets/editable_transaction_list_item.dart';
import 'package:mamoney/widgets/add_transaction_dialog.dart';

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
      _previewState =
          _previewState.updateTransaction(index, updatedTransaction);
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
      builder: (context) => AddTransactionDialog(
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
      final provider = Provider.of<TransactionProvider>(context, listen: false);
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
                          color:
                              isDarkMode ? Colors.grey[600] : Colors.grey[300],
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
