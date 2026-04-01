import 'dart:math';

import '../models/transaction.dart';

/// Manages transaction embeddings and semantic search for RAG (Retrieval-Augmented Generation).
/// Converts transactions to embeddings and retrieves relevant ones for AI context.
class TransactionEmbeddings {
  // Store embeddings in memory with simple caching
  final Map<String, List<double>> _embeddingCache = {};

  TransactionEmbeddings();

  /// Generate a text summary of transactions for the past 12 months
  /// Groups by month and category for concise representation
  String summarizeTransactions(List<Transaction> transactions) {
    if (transactions.isEmpty) {
      return 'No transactions available for analysis.';
    }

    // Group transactions by month and category
    final Map<String, Map<String, double>> monthlyByCategory = {};

    for (final tx in transactions) {
      // Only include recent transactions (last 12 months)
      final monthsAgo = DateTime.now().difference(tx.date).inDays / 30;
      if (monthsAgo > 12) continue;

      final monthKey =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}';
      final categoryKey = '${tx.type}_${tx.category}';

      if (!monthlyByCategory.containsKey(monthKey)) {
        monthlyByCategory[monthKey] = {};
      }

      monthlyByCategory[monthKey]![categoryKey] =
          (monthlyByCategory[monthKey]![categoryKey] ?? 0) + tx.amount;
    }

    // Format summary
    final StringBuffer summary = StringBuffer();
    summary.writeln('Transaction Summary (Last 12 Months):\n');

    final sortedMonths = monthlyByCategory.keys.toList()..sort();

    for (final monthKey in sortedMonths.reversed) {
      summary.writeln('Month: $monthKey');
      final categoryBreakdown = monthlyByCategory[monthKey]!;
      for (final entry in categoryBreakdown.entries) {
        final separatorIdx = entry.key.indexOf('_');
        final type = separatorIdx == -1
            ? entry.key
            : entry.key.substring(0, separatorIdx);
        final category = separatorIdx == -1
            ? 'unknown'
            : entry.key.substring(separatorIdx + 1);

        summary.writeln(
            '  - $type ($category): \$${entry.value.toStringAsFixed(2)}');
      }
      summary.writeln('');
    }

    return summary.toString();
  }

  /// Get relevant transactions as context for a user's question
  /// Performs semantic search by:
  /// 1. Creating a summary of all transactions
  /// 2. Matching question intent to transaction categories/types
  /// 3. Searching transaction descriptions for relevant keywords
  /// 4. Returning aggregated transaction data for that intent
  Future<String> getRelevantTransactionContext(
    String userQuestion,
    List<Transaction> allTransactions,
  ) async {
    print("all Transactions context for AI:\n$allTransactions");

    try {
      if (allTransactions.isEmpty) {
        return 'User has no transactions recorded.';
      }

      // Use all transactions, no filtering
      List<Transaction> relevantTransactions = allTransactions.toList();

      // Filter to last 12 months
      final now = DateTime.now();
      relevantTransactions = relevantTransactions
          .where((tx) => now.difference(tx.date).inDays <= 365)
          .toList();

      // Sort by date descending (most recent first)
      relevantTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Generate summary
      return _generateContextSummary(relevantTransactions);
    } catch (e) {
      return 'Error retrieving transaction context: $e';
    }
  }

  /// Generate a concise summary of transaction context
  String _generateContextSummary(
    List<Transaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return 'No relevant transactions found.';
    }

    // Calculate totals and stats
    double totalAmount = 0;
    int transactionCount = transactions.length;
    DateTime? oldestDate;
    DateTime? newestDate;

    for (final tx in transactions) {
      totalAmount += tx.amount;
      oldestDate = oldestDate == null || tx.date.isBefore(oldestDate)
          ? tx.date
          : oldestDate;
      newestDate = newestDate == null || tx.date.isAfter(newestDate)
          ? tx.date
          : newestDate;
    }

    final avgAmount = totalAmount / transactionCount;

    final StringBuffer context = StringBuffer();
    context.writeln('Transaction Context:');
    context.writeln('- Total transactions: $transactionCount');
    context.writeln('- Total amount: \$${totalAmount.toStringAsFixed(2)}');
    context.writeln(
        '- Average per transaction: \$${avgAmount.toStringAsFixed(2)}');
    if (oldestDate != null && newestDate != null) {
      context.writeln(
          '- Date range: ${oldestDate.toString().split(' ')[0]} to ${newestDate.toString().split(' ')[0]}');
    }

    // Show all transactions sorted by amount (largest first)
    // This helps the AI accurately identify all expenses/income
    final sortedByAmount = List<Transaction>.from(transactions)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    context.writeln('\nAll transactions by amount:');
    print("All transactions by amount: \n$sortedByAmount");
    for (final tx in sortedByAmount) {
      context.writeln(
          '- ${tx.date.toString().split(' ')[0]}: ${tx.description} (${tx.type}, ${tx.category}) - \$${tx.amount}');
    }

    return context.toString();
  }

  /// Compute cosine similarity between two vectors
  /// Used for semantic similarity comparison
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length || a.isEmpty) return 0.0;

    double dotProduct = 0;
    double magnitudeA = 0;
    double magnitudeB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    magnitudeA = sqrt(magnitudeA);
    magnitudeB = sqrt(magnitudeB);

    if (magnitudeA == 0 || magnitudeB == 0) return 0.0;

    return dotProduct / (magnitudeA * magnitudeB);
  }

  /// Clear embedding cache
  void clearCache() {
    _embeddingCache.clear();
  }
}
