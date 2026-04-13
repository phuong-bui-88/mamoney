import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/ai_service.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/utils/input_formatters.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:logging/logging.dart';

final _logger = Logger('EditTransactionScreen');

class EditTransactionScreen extends StatefulWidget {
  final Transaction transaction;

  const EditTransactionScreen({
    super.key,
    required this.transaction,
  });

  @override
  State<EditTransactionScreen> createState() => _EditTransactionScreenState();
}

class _EditTransactionScreenState extends State<EditTransactionScreen> {
  late TextEditingController _descriptionController;
  late TextEditingController _amountController;
  late TransactionType _selectedType;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;
  bool _addThousands = true; // Add 000 option, default true

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.transaction.description);

    // Detect if "Add 000" was used by checking if amount is divisible by 1000
    final amount = widget.transaction.amount;
    if (amount % 1000 == 0 && amount >= 1000) {
      _addThousands = true;
      _amountController = TextEditingController(
        text: (amount ~/ 1000).toString(),
      );
    } else {
      _addThousands = false;
      _amountController = TextEditingController(
        text: amount.toStringAsFixed(0).replaceAll('.0', ''),
      );
    }

    // Add listener to trigger rebuild when amount changes
    _amountController.addListener(() {
      setState(() {});
    });
    _selectedType = widget.transaction.type;
    _selectedCategory = widget.transaction.category;
    _selectedDate = widget.transaction.date;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _handleUpdateTransaction() async {
    final parsed = _parseAndValidateInputs();
    if (parsed == null) return;

    setState(() => _isSaving = true);

    try {
      await _performUpdate(parsed.description, parsed.amount);
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  ({String description, double amount})? _parseAndValidateInputs() {
    final description = _descriptionController.text.trim();
    final amountStr = _amountController.text.trim();

    if (description.isEmpty || amountStr.isEmpty) {
      _showSnackBar('Please fill in all fields');
      return null;
    }

    final cleanAmount = double.tryParse(AIService.cleanupAmount(amountStr.trim()));
    if (cleanAmount == null || cleanAmount <= 0) {
      _showSnackBar('Please enter a valid amount');
      return null;
    }

    final amount = _addThousands ? cleanAmount * 1000 : cleanAmount;
    return (description: description, amount: amount);
  }

  Future<void> _performUpdate(String description, double amount) async {
    // Read context before any async operations
    final provider = context.read<TransactionProvider>();

    String? ragId = widget.transaction.ragId;

    // If transaction doesn't have a ragId, try to generate one from the description
    if ((ragId == null || ragId.isEmpty) && description.isNotEmpty) {
      _logger
          .info('Transaction missing ragId, attempting to generate from AI...');
      try {
        final aiMessage = '$description ${amount.toInt()}';
        final aiResult = await AIService.parseTransactionMessage(aiMessage);

        if (aiResult['ragId'] != null) {
          ragId = aiResult['ragId'];
        } else {
          _logger.warning('AI response did not include ragId');
        }
      } catch (e) {
        _logger.warning('Failed to generate ragId from AI: $e');
        // Continue with update even if ragId generation fails
      }
    }

    final updatedTransaction = widget.transaction.copyWith(
      description: description,
      amount: amount,
      type: _selectedType,
      category: _selectedCategory,
      date: _selectedDate,
      ragId: ragId,
    );

    await provider.updateTransaction(updatedTransaction);

    if (!mounted) return;

    if (provider.error != null) {
      _showSnackBar('Failed to update: ${provider.error}');
      return;
    }

    _showSnackBar('Transaction updated successfully');
    Navigator.of(context).pop();
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _selectedType == TransactionType.expense;
    final categories = isExpense
        ? CategoryConstants.expenseCategories
        : CategoryConstants.incomeCategories;

    // Ensure initialValue is valid (exists in items list)
    final validInitialValue = categories.contains(_selectedCategory)
        ? _selectedCategory
        : (categories.isNotEmpty ? categories[0] : '');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Description
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  hintText: 'Enter transaction description',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 1,
              ),
              const SizedBox(height: 16),

              // Amount Field with Add 000 Checkbox
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _amountController,
                      decoration: InputDecoration(
                        labelText: 'Amount',
                        hintText: 'Enter amount',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffixText: 'VND',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        ThousandsSeparatorInputFormatter(),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Checkbox(
                          tristate: false,
                          value: _addThousands,
                          onChanged: (bool? value) {
                            setState(() {
                              _addThousands = value ?? true;
                            });
                          },
                        ),
                        const Text(
                          'Add 000',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Preview Amount
              if (_amountController.text.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300] ?? Colors.grey),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Preview:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        () {
                          String amountStr = _amountController.text.trim();
                          if (amountStr.isEmpty) return '0 VND';

                          // Remove commas to get pure digits
                          amountStr = amountStr.replaceAll(',', '');
                          final amount = double.tryParse(amountStr) ?? 0;

                          // Apply thousand multiplier only if enabled
                          final finalAmount =
                              _addThousands ? amount * 1000 : amount;
                          final formatter = NumberFormat('#,##0', 'en_US');
                          return '${formatter.format(finalAmount)} VND';
                        }(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),

              // Transaction Type
              SegmentedButton<TransactionType>(
                segments: const <ButtonSegment<TransactionType>>[
                  ButtonSegment<TransactionType>(
                    value: TransactionType.income,
                    label: Text('Income'),
                  ),
                  ButtonSegment<TransactionType>(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                  ),
                ],
                selected: <TransactionType>{_selectedType},
                onSelectionChanged: (Set<TransactionType> newSelection) {
                  setState(() {
                    _selectedType = newSelection.first;
                    // Reset category when changing type
                    _selectedCategory = '';
                  });
                },
              ),
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<String>(
                initialValue: validInitialValue,
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Date
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Invoice Image Display
              if (widget.transaction.imageUrl != null &&
                  widget.transaction.imageUrl!.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invoice Image',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        widget.transaction.imageUrl!,
                        fit: BoxFit.cover,
                        height: 250,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.image_not_supported,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Failed to load image',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Container(
                            height: 250,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'To remove the image, edit the transaction or delete it.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline, size: 18),
                      label: const Text('Image is from invoice upload'),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),

              // Save Button
              ElevatedButton(
                onPressed: _isSaving ? null : _handleUpdateTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
