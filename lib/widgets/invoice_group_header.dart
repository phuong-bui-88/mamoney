import 'package:flutter/material.dart';
import 'package:mamoney/models/invoice_group.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:mamoney/services/firebase_service.dart';

class InvoiceGroupHeader extends StatelessWidget {
  final InvoiceGroup invoiceGroup;
  final VoidCallback onToggleExpanded;

  const InvoiceGroupHeader({
    super.key,
    required this.invoiceGroup,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // Light blue background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggleExpanded,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Invoice thumbnail image
                if (invoiceGroup.imageUrl != null &&
                    invoiceGroup.imageUrl!.isNotEmpty)
                  _buildInvoiceThumbnail(invoiceGroup.imageUrl!)
                else
                  _buildPlaceholderThumbnail(),
                const SizedBox(width: 12),
                // Invoice metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date
                      Text(
                        'Invoice • ${DateFormat('MMM dd, yyyy').format(invoiceGroup.invoiceDate)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Item count and total
                      Text(
                        '${invoiceGroup.itemCount} items • ${formatCurrency(invoiceGroup.totalAmount)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                // Expand/collapse indicator
                Icon(
                  invoiceGroup.isExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  color: const Color(0xFF1976D2),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build invoice thumbnail from image URL
  Widget _buildInvoiceThumbnail(String imageUrl) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWidget(imageUrl),
      ),
    );
  }

  /// Build placeholder thumbnail
  Widget _buildPlaceholderThumbnail() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        border: Border.all(color: const Color(0xFF90CAF9), width: 1),
      ),
      child: const Center(
        child: Icon(
          Icons.receipt_long,
          color: Color(0xFF90CAF9),
          size: 32,
        ),
      ),
    );
  }

  /// Build image widget handling both local and network images
  Widget _buildImageWidget(String imageUrl) {
    if (imageUrl.startsWith('local://')) {
      // Local image stored in SharedPreferences
      return FutureBuilder<Uint8List?>(
        future: FirebaseService().getLocalImage(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.grey[300]!,
                  ),
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
            );
          }

          return Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey[300],
            ),
          );
        },
      );
    } else {
      // Network image
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: Icon(
              Icons.image_not_supported,
              color: Colors.grey[300],
            ),
          );
        },
      );
    }
  }
}
