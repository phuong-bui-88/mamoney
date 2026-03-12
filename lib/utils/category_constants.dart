/// Category constants and helpers for income and expense categories
class CategoryConstants {
  // Income categories
  static const List<String> incomeCategories = [
    'Salary',
    'Freelance',
    'Investment',
    'Gift',
    'Other'
  ];

  // Expense categories with emojis
  static const List<String> expenseCategories = [
    '🏠 Housing',
    '🍚 Food',
    '🚗 Transportation',
    '💡 Utilities',
    '🏥 Healthcare'
  ];

  /// Get the emoji and category name from a category string
  /// For categories with emoji prefix (e.g., "🏠 Housing"), returns both
  /// For categories without emoji (e.g., "Salary"), returns the name only
  static Map<String, String> parseCategory(String categoryString) {
    final trimmed = categoryString.trim();
    final firstSpace = trimmed.indexOf(' ');
    if (firstSpace > 0) {
      final prefix = trimmed.substring(0, firstSpace);
      final name = trimmed.substring(firstSpace + 1).trim();
      if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(prefix) && name.isNotEmpty) {
        return {
          'emoji': prefix,
          'name': name,
        };
      }
    }
    return {
      'emoji': '',
      'name': trimmed,
    };
  }

  /// Get the clean category name without emoji
  static String getCategoryName(String categoryString) {
    return parseCategory(categoryString)['name'] ?? categoryString;
  }

  /// Get the emoji from a category string
  static String getEmojiFromCategory(String categoryString) {
    return parseCategory(categoryString)['emoji'] ?? '';
  }

  /// Get color for a category
  /// Income categories: shades of green
  /// Expense categories: shades of red/orange
  static int getCategoryColor(String categoryString, bool isIncome) {
    final cleanName = getCategoryName(categoryString);

    if (isIncome) {
      // Green color palette for income
      const List<int> greenColors = [
        0xFF4CAF50,
        0xFF66BB6A,
        0xFF81C784,
        0xFFA5D6A7,
        0xFFFFeb3b,
      ];
      final index = incomeCategories.indexWhere(
        (cat) => getCategoryName(cat) == cleanName,
      );
      return greenColors[index >= 0 ? index : 0];
    } else {
      // Red/orange palette for expenses
      const List<int> redColors = [
        0xFFF44336,
        0xFFEF5350,
        0xFFE57373,
        0xFFEF9A9A,
        0xFFFF9800,
      ];
      final index = expenseCategories.indexWhere(
        (cat) => getCategoryName(cat) == cleanName,
      );
      return redColors[index >= 0 ? index : 0];
    }
  }
}
