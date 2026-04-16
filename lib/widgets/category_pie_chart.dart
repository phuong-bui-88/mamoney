import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mamoney/utils/category_constants.dart';
import 'package:mamoney/utils/currency_utils.dart' show formatCurrency;
import 'dart:developer' as developer;

class CategoryPieChart extends StatefulWidget {
  final String title;
  final Map<String, double> categoryData;
  final List<Color>? colors;
  final Color backgroundColor;
  final Function(String category)? onCategoryTap;

  const CategoryPieChart({
    super.key,
    required this.title,
    required this.categoryData,
    this.colors,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.onCategoryTap,
  });

  @override
  State<CategoryPieChart> createState() => _CategoryPieChartState();
}

class _CategoryPieChartState extends State<CategoryPieChart> {
  int? hoveredIndex;
  late List<MapEntry<String, double>> entries;
  late double total;
  late List<Color> chartColors;

  @override
  void didUpdateWidget(CategoryPieChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    _initializeData();
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    total =
        widget.categoryData.values.fold<double>(0, (sum, value) => sum + value);
    entries = widget.categoryData.entries.toList();
    chartColors = widget.colors ?? _generateColors(entries.length);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categoryData.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              MouseRegion(
                onEnter: (_) {},
                onExit: (_) {
                  setState(() {
                    hoveredIndex = null;
                  });
                },
                child: GestureDetector(
                  onDoubleTap: () {
                    // Handle double-tap on chart - navigate to transactions filtered by category
                    if (hoveredIndex != null && hoveredIndex! < entries.length) {
                      final selectedCategory = entries[hoveredIndex!].key;
                      widget.onCategoryTap?.call(selectedCategory);
                    }
                  },
                  child: SizedBox(
                    height: 250,
                    child: PieChart(
                      PieChartData(
                        sections: _buildPieSections(entries, chartColors, total),
                        centerSpaceRadius: 40,
                        sectionsSpace: 2,
                        pieTouchData: PieTouchData(
                          enabled: true,
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            try {
                              if (pieTouchResponse != null &&
                                  pieTouchResponse.touchedSection != null) {
                                final newIndex = pieTouchResponse
                                    .touchedSection!.touchedSectionIndex;
                                // Validate index before updating
                                if (newIndex >= 0 && newIndex < entries.length) {
                                  if (hoveredIndex != newIndex) {
                                    setState(() {
                                      hoveredIndex = newIndex;
                                    });
                                  }
                                }
                              }
                            } catch (e) {
                              developer.log('Touch error: $e');
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Hover tooltip
        if (hoveredIndex != null && hoveredIndex! < entries.length)
          Positioned(
            right: 20,
            top: 60,
            child: _buildHoverTooltip(hoveredIndex!),
          ),
      ],
    );
  }

  Widget _buildHoverTooltip(int index) {
    // Safety check
    if (index < 0 || index >= entries.length) {
      return const SizedBox.shrink();
    }

    final categoryName = entries[index].key;
    final amount = entries[index].value;
    final percentage = (amount / total) * 100;
    final color = chartColors[index % chartColors.length];

    // Parse category to get emoji
    final categoryInfo = CategoryConstants.parseCategory(categoryName);
    final emoji = categoryInfo['emoji'] ?? '';
    final cleanName = categoryInfo['name'] ?? categoryName;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category name with emoji
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                Text(
                  cleanName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Amount
            Text(
              'Amount: ${formatCurrency(amount)}',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            // Percentage
            Text(
              'Percentage: ${percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 32),
          const Text(
            'No data available',
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildPieSections(
    List<MapEntry<String, double>> entries,
    List<Color> colors,
    double total,
  ) {
    return entries.asMap().entries.map((entry) {
      final index = entry.key;
      final categoryEntry = entry.value;
      final percentage = (categoryEntry.value / total) * 100;
      final isHovered = hoveredIndex != null && hoveredIndex == index;

      return PieChartSectionData(
        color: isHovered
            ? colors[index % colors.length]
            : colors[index % colors.length].withValues(alpha: 0.7),
        value: categoryEntry.value,
        title: '${percentage.toStringAsFixed(0)}%',
        radius: isHovered ? 90 : 80,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }

  List<Color> _generateColors(int count) {
    // Different color palettes based on whether it's income or expense chart
    final incomeColors = [
      const Color(0xFF4CAF50),
      const Color(0xFF66BB6A),
      const Color(0xFF81C784),
      const Color(0xFFA5D6A7),
      const Color(0xFFFFeb3b),
    ];

    final expenseColors = [
      const Color(0xFFF44336),
      const Color(0xFFEF5350),
      const Color(0xFFE57373),
      const Color(0xFFEF9A9A),
      const Color(0xFFFF9800),
    ];

    // Determine if this is likely an income or expense chart based on title
    final colors = widget.title.toLowerCase().contains('income')
        ? incomeColors
        : expenseColors;

    // If we need more colors, cycle through the list
    return List.generate(
      count,
      (index) => colors[index % colors.length],
    );
  }
}
