import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/services/firebase_service.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/models/invoice_group.dart';
import 'package:mamoney/services/auth_provider.dart';
import 'package:intl/intl.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:mamoney/screens/edit_transaction_screen.dart';
import 'package:mamoney/screens/add_transaction_screen.dart' hide InvoiceGroup;
import 'package:mamoney/widgets/invoice_group_header.dart';
import 'package:mamoney/widgets/invoice_transaction_tile.dart';
import 'package:mamoney/widgets/rag_ai_badge.dart';
import 'package:logging/logging.dart';

final _logger = Logger('TransactionListScreen');

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() {
    return _TransactionListScreenState();
  }
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  @override
  void initState() {
    super.initState();
    _logger.info('[TLS] ===== initState() CALLED =====');
  }

  @override
  void dispose() {
    _logger.info('=== _TransactionListScreenState.dispose() called ===');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _logger.info('[TLS] build() called');

    try {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Transactions'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () {
                context.read<AuthProvider>().signOut();
              },
            ),
          ],
        ),
        body: Consumer<TransactionProvider>(
          builder: (context, transactionProvider, _) {
            _logger.info('[TLS-CONSUMER] builder entered');

            try {
              return Column(
                children: [
                  // Filter Section - Single Row
                  Padding(
                    padding: const EdgeInsets.all(16.0),
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
                                    transactionProvider.setFilterType(newValue);
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
                  // Totals Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Total Expense
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Expense',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrency(
                                    transactionProvider.filteredTotalExpense),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          // Total Income
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Income',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrency(
                                    transactionProvider.filteredTotalIncome),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          // Balance (Income - Expense)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Balance',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                formatCurrency(
                                    transactionProvider.filteredBalance),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      transactionProvider.filteredBalance >= 0
                                          ? Colors.green
                                          : Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(),
                  // Transactions List with Invoice Grouping
                  Expanded(
                    child: () {
                      try {
                        final result =
                            _buildTransactionList(context, transactionProvider);
                        return result;
                      } catch (e) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error,
                                  size: 64, color: Colors.red),
                              const SizedBox(height: 20),
                              Text('Error: $e', textAlign: TextAlign.center),
                            ],
                          ),
                        );
                      }
                    }(),
                  ),
                ],
              );
            } catch (e) {
              _logger.severe('[CONSUMER] ERROR in Consumer builder: $e');
              return Center(
                child: Text('Error: $e'),
              );
            }
          },
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
    } catch (e) {
      _logger.severe('[BUILD] Exception in build(): $e');
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Build error: $e')),
      );
    }
  }

  Widget _buildTransactionImageWidget(String imageUrl) {
    // Handle both local and network images
    if (imageUrl.startsWith('local://')) {
      // Local image - fetch from SharedPreferences
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: () => _showImagePreview(imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<Uint8List?>(
              future: FirebaseService().getLocalImage(imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }

                if (snapshot.hasError || snapshot.data == null) {
                  return Container(
                    height: 120,
                    color: Colors.grey[200],
                    child: const Center(
                      child:
                          Icon(Icons.image_not_supported, color: Colors.grey),
                    ),
                  );
                }

                return Stack(
                  children: [
                    Image.memory(
                      snapshot.data!,
                      height: 120,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      );
    } else {
      // Network image - use Image.network
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: () => _showImagePreview(imageUrl),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child:
                            Icon(Icons.image_not_supported, color: Colors.grey),
                      ),
                    );
                  },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      height: 120,
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  },
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            color: Colors.black.withValues(alpha: 0.9),
            child: Center(
              child: imageUrl.startsWith('local://')
                  ? FutureBuilder<Uint8List?>(
                      future: FirebaseService().getLocalImage(imageUrl),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return InteractiveViewer(
                            child: Image.memory(snapshot.data!),
                          );
                        }
                        return const SizedBox(
                          width: 50,
                          height: 50,
                          child: CircularProgressIndicator(),
                        );
                      },
                    )
                  : InteractiveViewer(
                      child: Image.network(imageUrl),
                    ),
            ),
          ),
        ),
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
                              icon: const Icon(Icons.expand_less,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear > 2020) {
                                    selectedYear--;
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
                              icon: const Icon(Icons.expand_more,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear < 2030) {
                                    selectedYear++;
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
                              icon: const Icon(Icons.expand_less,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear > 2020) {
                                    selectedYear--;
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
                              icon: const Icon(Icons.expand_more,
                                  color: Colors.white, size: 24),
                              onPressed: () {
                                setDialogState(() {
                                  if (selectedYear < 2030) {
                                    selectedYear++;
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

  Widget _buildTransactionList(
    BuildContext context,
    TransactionProvider provider,
  ) {
    // CRITICAL: Log immediately to see if method is called at all
    _logger.info('[TLS-BUILD] _buildTransactionList called');
    _logger.warning('[TLS-BUILD] ▶▶▶ METHOD ENTRY POINT ▶▶▶');

    try {
      _logger.warning('[BUILD] ===== START _buildTransactionList =====');
      final txnCount = provider.filteredTransactions.length;
      _logger.info('[BUILD] filteredTransactions.length = $txnCount');

      if (provider.filteredTransactions.isEmpty) {
        _logger
            .warning('[BUILD] No filtered transactions - showing empty state');
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.receipt_long,
                size: 48,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 16),
              Text(
                'No transactions found',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      // Get invoice groups and ungrouped transactions
      _logger.warning('[BUILD] GROUP NOW! Calling getInvoiceGroups...');
      List<InvoiceGroup> invoiceGroups = [];
      try {
        invoiceGroups = provider.getInvoiceGroups();
        _logger.warning(
            '[BUILD] getInvoiceGroups SUCCESS: ${invoiceGroups.length} groups');
      } catch (e, st) {
        _logger.severe('[BUILD] getInvoiceGroups ERROR: $e\n$st');
      }

      _logger.warning('[BUILD] Calling getUngroupedTransactions...');
      List<Transaction> ungroupedTransactions = [];
      try {
        ungroupedTransactions = provider.getUngroupedTransactions();
        _logger.warning(
            '[BUILD] getUngroupedTransactions SUCCESS: ${ungroupedTransactions.length} ungrouped');
      } catch (e, st) {
        _logger.severe('[BUILD] getUngroupedTransactions ERROR: $e\n$st');
      }

      _logger.info('[BUILD] invoiceGroups.length = ${invoiceGroups.length}');
      _logger.info(
          '[BUILD] ungroupedTransactions.length = ${ungroupedTransactions.length}');

      for (var i = 0; i < invoiceGroups.length; i++) {
        final group = invoiceGroups[i];
        _logger.info(
            '[BUILD] Invoice group $i: id=${group.invoiceId}, transactions=${group.transactions.length}');
      }

      // Build list items combining both invoice groups and regular transactions
      final listItems = <Widget>[];

      // Add invoice groups
      for (final group in invoiceGroups) {
        _logger
            .info('[BUILD] Adding header for invoice group ${group.invoiceId}');
        // Add group header
        listItems.add(
          InvoiceGroupHeader(
            invoiceGroup: group,
            onToggleExpanded: () {
              provider.toggleInvoiceExpanded(group.invoiceId);
            },
            onDelete: () {
              // Remove invoice from view immediately (optimistic removal)
              provider.removeInvoiceFromView(group.invoiceId);

              // Delete in background without awaiting
              provider.deleteInvoice(group.invoiceId).then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invoice deleted successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }).catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting invoice: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              });
            },
          ),
        );

        // Add transactions if group is expanded
        if (provider.isInvoiceExpanded(group.invoiceId)) {
          _logger.info(
              '[BUILD] Invoice group ${group.invoiceId} is expanded, adding ${group.transactions.length} transactions');
          for (final transaction in group.transactions) {
            listItems.add(
              InvoiceTransactionTile(
                transaction: transaction,
              ),
            );
          }
        } else {
          _logger.info('[BUILD] Invoice group ${group.invoiceId} is collapsed');
        }
      }

      // Add ungrouped transactions
      _logger.info(
          '[BUILD] Adding ${ungroupedTransactions.length} ungrouped transactions');
      for (final transaction in ungroupedTransactions) {
        listItems.add(
          Dismissible(
            key: Key(transaction.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Colors.red,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 16),
              child: const Icon(
                Icons.delete,
                color: Colors.white,
              ),
            ),
            onDismissed: (direction) {
              // Remove optimistically - widget MUST be removed from tree immediately
              provider.removeTransactionFromView(transaction.id);

              // Delete in background without awaiting
              provider.deleteTransaction(transaction.id).then((_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Transaction deleted successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }).catchError((e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting transaction: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              });
            },
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => EditTransactionScreen(
                      transaction: transaction,
                    ),
                  ),
                );
              },
              child: Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Transaction Details Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Icon(
                            transaction.type.toString().contains('income')
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color:
                                transaction.type.toString().contains('income')
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          const SizedBox(width: 12),
                          // Title and Subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  transaction.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  transaction.category,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('MMM dd, yyyy')
                                      .format(transaction.date),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Amount
                          Text(
                            '${transaction.type.toString().contains('income') ? '' : '-'}${formatCurrency(transaction.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color:
                                  transaction.type.toString().contains('income')
                                      ? Colors.green
                                      : Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // RAG AI Icon (if ragId is not null)
                          if (transaction.ragId != null &&
                              transaction.ragId!.isNotEmpty)
                            const RagAiBadge(),
                        ],
                      ),
                      // Invoice Image Thumbnail
                      if (transaction.imageUrl != null &&
                          transaction.imageUrl!.isNotEmpty)
                        _buildTransactionImageWidget(transaction.imageUrl!),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }

      _logger.info('[BUILD] Final listItems.length = ${listItems.length}');
      _logger.info('[BUILD] Returning ListView with all items');
      return ListView(
        children: listItems,
      );
    } catch (e, st) {
      _logger.severe('[BUILD] EXCEPTION in _buildTransactionList: $e\n$st');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error building transaction list: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ],
        ),
      );
    }
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
