import 'package:flutter/material.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:mamoney/screens/edit_transaction_screen.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:mamoney/services/firebase_service.dart';
import 'package:provider/provider.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/widgets/rag_ai_badge.dart';
import 'package:logging/logging.dart';

final _logger = Logger('InvoiceTransactionTile');

class InvoiceTransactionTile extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback? onDelete;

  const InvoiceTransactionTile({
    super.key,
    required this.transaction,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Log transaction details
    final isFromInvoice =
        transaction.invoiceId != null && transaction.invoiceId!.isNotEmpty;

    _logger.info('[TILE] Building transaction: ${transaction.description}, '
        'isFromInvoice: $isFromInvoice');

    if (isFromInvoice) {
      _logger.warning('[TILE] ✅ BLUE BG CONDITION MET! ID: ${transaction.id}');
    } else {
      _logger.info('[TILE] Not from invoice: ${transaction.id}');
    }

    return Dismissible(
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
        context
            .read<TransactionProvider>()
            .removeTransactionFromView(transaction.id);

        // Delete in background without awaiting
        context
            .read<TransactionProvider>()
            .deleteTransaction(transaction.id)
            .then((_) {
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

        onDelete?.call();
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
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: isFromInvoice
                ? const Color(
                    0xFFE3E8F5) // Light blue background for invoice transactions
                : const Color(
                    0xFFF5F5F5), // Subtle gray background for normal transactions
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: isFromInvoice
                    ? const Color(
                        0xFF1976D2) // Vibrant blue for invoice transactions
                    : const Color(0xFF1976D2), // Blue left accent
                width: isFromInvoice
                    ? 5
                    : 3, // Thicker border for invoice transactions
              ),
            ),
          ),
          child: Card(
            color: Colors.transparent,
            elevation: 0,
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
                        color: transaction.type.toString().contains('income')
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
                          color: transaction.type.toString().contains('income')
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
                  // Invoice Image Thumbnail (if available)
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

  Widget _buildTransactionImageWidget(String imageUrl) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      child: Builder(
        builder: (context) {
          return Stack(
            children: [
              _buildImageDisplay(context, imageUrl),
            ],
          );
        },
      ),
    );
  }

  Widget _buildImageDisplay(BuildContext context, String imageUrl) {
    if (imageUrl.startsWith('local://')) {
      return FutureBuilder<Uint8List?>(
        future: FirebaseService().getLocalImage(imageUrl),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Image.memory(snapshot.data!),
                    ),
                  ),
                );
              },
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: Image.memory(
                  snapshot.data!,
                  fit: BoxFit.cover,
                ),
              ),
            );
          }

          return Container(
            height: 100,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                Icons.image_not_supported,
                color: Colors.grey[400],
              ),
            ),
          );
        },
      );
    } else {
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Image.network(imageUrl),
              ),
            ),
          );
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey[200],
          ),
          child: Image.network(
            imageUrl,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Icon(
                  Icons.image_not_supported,
                  color: Colors.grey[400],
                ),
              );
            },
          ),
        ),
      );
    }
  }
}
