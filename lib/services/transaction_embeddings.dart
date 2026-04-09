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
  /// 1. Parsing question to extract month/year and type (expense/income)
  /// 2. Filtering transactions to match the specific month/year
  /// 3. Filtering by type if question specifies expense or income
  /// 4. Returning aggregated transaction data for that query
  Future<String> getRelevantTransactionContext(
    String userQuestion,
    List<Transaction> allTransactions,
  ) async {
    print("all Transactions context for AI:\n$allTransactions");

    try {
      if (allTransactions.isEmpty) {
        return 'User has no transactions recorded.';
      }

      // Parse question to extract month, year, and type
      final queryInfo = _parseUserQuestion(userQuestion);
      print("Parsed query info: $queryInfo");

      List<Transaction> relevantTransactions = allTransactions.toList();

      // Filter to last 12 months (fallback if no specific month detected)
      final now = DateTime.now();
      relevantTransactions = relevantTransactions
          .where((tx) => now.difference(tx.date).inDays <= 365)
          .toList();

      // Filter by type if detected (expense/income)
      if (queryInfo['type'] != null) {
        final transactionType = queryInfo['type'] == 'expense'
            ? TransactionType.expense
            : TransactionType.income;
        relevantTransactions = relevantTransactions
            .where((tx) => tx.type == transactionType)
            .toList();
      }

      // Filter by month if detected
      if (queryInfo['month'] != null) {
        final targetMonth = queryInfo['month'] as int;
        final targetYear = queryInfo['year'] ?? DateTime.now().year;
        relevantTransactions = relevantTransactions.where((tx) {
          return tx.date.month == targetMonth && tx.date.year == targetYear;
        }).toList();
      }

      // Sort by date descending (most recent first)
      relevantTransactions.sort((a, b) => b.date.compareTo(a.date));

      // Generate summary
      return _generateContextSummary(relevantTransactions);
    } catch (e) {
      return 'Error retrieving transaction context: $e';
    }
  }

  /// Parse user question to extract month, year, and transaction type
  /// Returns a map with 'month', 'year', and 'type' keys (all optional)
  /// Vietnamese month: tháng 3 = month 3
  /// Type detection: "chi" = expense, "thu" = income
  Map<String, dynamic> _parseUserQuestion(String question) {
    final result = <String, dynamic>{};
    final lowerQuestion = question.toLowerCase();

    // Detect month from Vietnamese patterns
    // Patterns: "tháng 3", "tháng 1", "month 3" etc.
    final monthPatterns = [
      'tháng\\s+(\\d+)', // Vietnamese: tháng 3
      'month\\s+(\\d+)', // English: month 3
      'thang\\s+(\\d+)', // Alternative Vietnamese (without accent)
    ];

    for (final pattern in monthPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(question);
      if (match != null) {
        final monthStr = match.group(1);
        if (monthStr != null) {
          int month = int.tryParse(monthStr) ?? -1;
          if (month >= 1 && month <= 12) {
            result['month'] = month;
            break;
          }
        }
      }
    }

    // Detect year if present
    // Patterns: "năm 2026", "year 2026", "2026"
    final yearPatterns = [
      'năm\\s+(\\d{4})', // Vietnamese: năm 2026
      'year\\s+(\\d{4})', // English: year 2026
      '(?:tháng|month)\\s+\\d+\\s+(\\d{4})', // month X year YYYY
    ];

    for (final pattern in yearPatterns) {
      final regex = RegExp(pattern, caseSensitive: false);
      final match = regex.firstMatch(question);
      if (match != null) {
        final yearStr = match.group(1);
        if (yearStr != null) {
          int year = int.tryParse(yearStr) ?? -1;
          if (year >= 2000 && year <= 2100) {
            result['year'] = year;
            break;
          }
        }
      }
    }

    // Detect transaction type
    if (lowerQuestion.contains('chi') || // Vietnamese: chi = expense
        lowerQuestion.contains('tiêu') || // Vietnamese: tiêu = spend
        lowerQuestion.contains('expense') || // English
        lowerQuestion.contains('spent') ||
        lowerQuestion.contains('spending')) {
      result['type'] = 'expense';
    } else if (lowerQuestion.contains('thu') || // Vietnamese: thu = income
        lowerQuestion.contains('lãi') || // Vietnamese: interest
        lowerQuestion.contains('income') || // English
        lowerQuestion.contains('earned') ||
        lowerQuestion.contains('salary') ||
        lowerQuestion.contains('bonus') ||
        lowerQuestion.contains('received')) {
      result['type'] = 'income';
    }

    return result;
  }

  /// Generate a concise summary of transaction context
  /// Summary clearly shows all filtered transactions with totals
  String _generateContextSummary(
    List<Transaction> transactions,
  ) {
    if (transactions.isEmpty) {
      return 'No transactions match your query. Please check the month/year/type you asked about.';
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

    final avgAmount = transactionCount > 0 ? totalAmount / transactionCount : 0;

    final StringBuffer context = StringBuffer();
    context.writeln('Transaction Context (Filtered Results):');
    context.writeln('- Number of transactions: $transactionCount');
    context.writeln(
        '- **TOTAL AMOUNT: ${totalAmount.toStringAsFixed(0)}** (This is the answer)');
    context
        .writeln('- Average per transaction: ${avgAmount.toStringAsFixed(0)}');
    if (oldestDate != null && newestDate != null) {
      final format =
          '${oldestDate.year}-${oldestDate.month.toString().padLeft(2, '0')}-${oldestDate.day.toString().padLeft(2, '0')}';
      context.writeln('- All transactions are from: $format');
    }

    // Show all transactions sorted by amount (largest first)
    // This helps the AI understand which transactions are included in the total
    final sortedByAmount = List<Transaction>.from(transactions)
      ..sort((a, b) => b.amount.compareTo(a.amount));

    context.writeln('\n=== ALL TRANSACTIONS INCLUDED IN THE TOTAL ===');
    for (final tx in sortedByAmount) {
      final dateStr =
          '${tx.date.year}-${tx.date.month.toString().padLeft(2, '0')}-${tx.date.day.toString().padLeft(2, '0')}';
      context.writeln(
          '- $dateStr: ${tx.description} (${tx.type}) - ${tx.amount.toStringAsFixed(0)}');
    }
    context.writeln('=== END OF TRANSACTIONS ===');

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
