import 'package:flutter/material.dart';
import 'package:mamoney/models/invoice_group.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:intl/intl.dart';

class InvoiceGroupHeader extends StatelessWidget {
  final InvoiceGroup invoiceGroup;
  final VoidCallback onToggleExpanded;
  final bool isExpanded;

  const InvoiceGroupHeader({
    super.key,
    required this.invoiceGroup,
    required this.onToggleExpanded,
    this.isExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    final formattedDate = dateFormatter.format(invoiceGroup.invoiceDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue[300]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          Icons.description,
          color: Colors.blue[700],
          size: 28,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice ID or "Invoice" label
            Text(
              invoiceGroup.vendorName ?? 'Invoice ${invoiceGroup.invoiceId}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            const SizedBox(height: 4),
            // Date and item count
            Text(
              '$formattedDate • ${invoiceGroup.itemCount} item${invoiceGroup.itemCount == 1 ? '' : 's'}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Total amount
            Text(
              formatCurrency(invoiceGroup.totalAmount),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 4),
            // Expand/collapse indicator
            GestureDetector(
              onTap: onToggleExpanded,
              child: Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.blue[700],
              ),
            ),
          ],
        ),
        onTap: onToggleExpanded,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }
}
