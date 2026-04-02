/// Financial knowledge base for RAG (Retrieval-Augmented Generation)
/// Contains curated financial advice and tips to augment AI responses
class FinancialKnowledgeBase {
  /// Financial management tips by category
  static const Map<String, String> financialTips = {
    'budgeting':
        'Follow the 50/30/20 rule: allocate 50% to needs, 30% to wants, 20% to savings. '
            'Track expenses regularly and review quarterly.',
    'saving':
        'Build an emergency fund covering 3-6 months of expenses. Start with 5-10% of income. '
            'Use automatic transfers to savings for consistency.',
    'food': 'Meal planning reduces waste. Buy generic brands (20-30% cheaper). '
        'Eating out costs 3-5x more than home cooking.',
    'transport':
        'Public transportation is cheaper than car ownership. Maintain vehicles regularly. '
            'Compare insurance rates annually.',
    'utilities':
        'Energy-efficient appliances reduce bills by 20-30%. Use programmable thermostats. '
            'Negotiate bills annually for better rates.',
    'entertainment': 'Set a monthly entertainment budget (5-10% of income). '
        'Cancel unused subscriptions. Look for discount days.',
    'health':
        'Preventive care is cheaper than emergency treatment. Generic medications work equally well. '
            'Health costs should be 5-15% of your budget.',
    'shopping':
        'Distinguish needs from wants. Shop off-season for 30-50% savings. '
            'Avoid shopping when stressed or hungry.',
    'debt':
        'Pay more than minimum on credit cards to reduce interest. High-interest debt is priority. '
            'Keep debt-to-income ratio below 36%.',
    'investment':
        'Only invest after building emergency fund. Diversify across asset classes. '
            'Start with index funds. Long-term investing beats short-term trading.',
    'income':
        'Side gigs add 15-30% income. Upskilling increases earning potential. '
            'Negotiate salary at job changes.',
    'goals':
        'Set SMART goals: Specific, Measurable, Achievable, Relevant, Time-bound. '
            'Review quarterly and adjust based on progress.',
  };

  static const String generalAdvice = '''
Key Principles:
- Track all expenses to understand spending patterns
- Build emergency fund before investing
- Distinguish between needs and wants
- Review finances monthly and adjust as needed
- Don't compare your finances to others - everyone's situation is unique

Common Mistakes:
- Living paycheck to paycheck without emergency fund
- Not tracking expenses (can't control what you don't measure)
- Using credit cards as loans (high interest compounds)
- Ignoring long-term financial planning
- Overlooking "small" expenses (they compound significantly)

Financial Metrics to Track:
- Savings rate: (Income - Expenses) / Income (Target: 20%+)
- Debt-to-income: Total monthly debt / Gross income (Target: <36%)
- Emergency fund months: Months of expenses covered (Target: 3-6)
- Spending by category: Should align with budget percentages
- Net worth: Assets - Liabilities (Track annually)
''';

  /// Get knowledge relevant to a specific topic
  static String getRelevantKnowledge(String topic) {
    final lowerTopic = topic.toLowerCase();

    // Try to find matching category
    for (final key in financialTips.keys) {
      if (lowerTopic.contains(key)) {
        return '${key.toUpperCase()}: ${financialTips[key]}';
      }
    }

    // Check for specific keywords
    if (lowerTopic.contains('spend') ||
        lowerTopic.contains('expense') ||
        lowerTopic.contains('cost')) {
      return 'BUDGETING: ${financialTips['budgeting']}';
    } else if (lowerTopic.contains('earn') ||
        lowerTopic.contains('income') ||
        lowerTopic.contains('salary')) {
      return 'INCOME: ${financialTips['income']}';
    } else if (lowerTopic.contains('emergency') ||
        lowerTopic.contains('reserve')) {
      return 'SAVING: ${financialTips['saving']}';
    } else if (lowerTopic.contains('debt') || lowerTopic.contains('credit')) {
      return 'DEBT: ${financialTips['debt']}';
    }

    // Default: return general advice and a tip
    return 'GENERAL ADVICE:\n$generalAdvice\n\nTip: ${financialTips['budgeting']}';
  }

  /// Get a quick tip for a category
  static String getQuickTip(String category) {
    return financialTips[category.toLowerCase()] ??
        'Tip: Track your spending, set clear goals, and review your finances monthly.';
  }
}
