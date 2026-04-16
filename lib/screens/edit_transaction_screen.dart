import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final cleanAmount =
        double.tryParse(AIService.cleanupAmount(amountStr.trim()));
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
    final isExpense = widget.transaction.type == TransactionType.expense;
    final categories = isExpense
        ? CategoryConstants.expenseCategories
        : CategoryConstants.incomeCategories;

    // Ensure initialValue is valid (exists in items list)
    final validInitialValue = categories.contains(_selectedCategory)
        ? _selectedCategory
        : (categories.isNotEmpty ? categories[0] : '');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Transaction'),
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Transaction Type - Read-only display
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildTransactionTypeDisplay(
                    isExpense, isDark, primaryColor),
              ),
              const SizedBox(height: 28),

              // Amount & Add 000 Section
              _buildSectionLabel('Amount'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildTextField(
                      controller: _amountController,
                      label: '',
                      hint: 'Enter amount',
                      suffix: 'VND',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: _buildAddThousandsToggle(),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Preview Amount
              if (_amountController.text.isNotEmpty) ...[
                _buildAmountPreview(isDark, primaryColor),
                const SizedBox(height: 28),
              ],

              // Description
              _buildSectionLabel('Description'),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _descriptionController,
                label: 'Description',
                hint: 'Enter transaction description',
                maxLines: 1,
              ),
              const SizedBox(height: 28),

              // Category
              _buildSectionLabel('Category'),
              const SizedBox(height: 12),
              _buildCategoryDropdown(categories, validInitialValue),
              const SizedBox(height: 28),

              // Date
              _buildSectionLabel('Date'),
              const SizedBox(height: 12),
              _buildDatePicker(context),
              const SizedBox(height: 32),

              // Save Button with Help Text
              Text(
                'Review your changes before saving',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isSaving ? null : _handleUpdateTransaction,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  backgroundColor: primaryColor,
                  disabledBackgroundColor:
                      primaryColor.withAlpha((255 * 0.5).toInt()),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? suffix,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: '',
        hintText: hint,
        suffixText: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey[400] ?? Colors.grey,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildAddThousandsToggle() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[400] ?? Colors.grey),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 24,
            child: Checkbox(
              tristate: false,
              value: _addThousands,
              onChanged: (bool? value) {
                setState(() {
                  _addThousands = value ?? true;
                });
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Add 000',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionTypeDisplay(
      bool isExpense, bool isDark, Color primaryColor) {
    final typeLabel = isExpense ? 'Expense' : 'Income';
    final typeColor = isExpense ? Colors.red[600] : Colors.green[600];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark
              ? Colors.grey[700] ?? Colors.grey
              : Colors.grey[300] ?? Colors.grey,
          width: 1,
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: typeColor?.withAlpha((255 * 0.2).toInt()),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          typeLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: typeColor,
          ),
        ),
      ),
    );
  }

  Widget _buildAmountPreview(bool isDark, Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withAlpha((255 * 0.1).toInt()),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: primaryColor.withAlpha((255 * 0.3).toInt()),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Amount',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.grey[400] : Colors.grey[700],
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            () {
              String amountStr = _amountController.text.trim();
              if (amountStr.isEmpty) return '0 VND';

              amountStr = amountStr.replaceAll(',', '');
              final amount = double.tryParse(amountStr) ?? 0;

              final finalAmount = _addThousands ? amount * 1000 : amount;
              final formatter = NumberFormat('#,##0', 'en_US');
              return '${formatter.format(finalAmount)} VND';
            }(),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(
    List<String> categories,
    String validInitialValue,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: validInitialValue,
      decoration: InputDecoration(
        labelText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Colors.grey[400] ?? Colors.grey,
            width: 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
            color: Theme.of(context).primaryColor,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 16,
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
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () => _selectDate(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Colors.grey[400] ?? Colors.grey,
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(
              color: Theme.of(context).primaryColor,
              width: 2,
            ),
          ),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: Theme.of(context).primaryColor,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
        child: Text(
          DateFormat('MMM dd, yyyy').format(_selectedDate),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}
