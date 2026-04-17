import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:intl/intl.dart';

class NetBalanceChart extends StatelessWidget {
  final TransactionProvider transactionProvider;

  const NetBalanceChart({
    super.key,
    required this.transactionProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Get net balance data for 12 months from today (not affected by filter selection)
    final netBalanceData =
        transactionProvider.getNetBalanceByMonthFromToday(12);

    // Get sorted months for display
    final months = netBalanceData.keys.toList()..sort();
    final values = months.map((month) => netBalanceData[month]!).toList();

    // Find min and max for Y-axis scaling
    final maxAbsValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs());

    // Round up to nearest sensible interval (1M, 5M, 10M, etc.)
    final maxValue =
        values.isEmpty ? 1.0 : _roundUpToNearestInterval(maxAbsValue);
    final minValue = -maxValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Net Balance (Expense - Income)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        // Chart container
        Container(
          height: 300,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: values.isEmpty
              ? Center(
                  child: Text(
                    'No transactions for the selected period',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              : BarChart(
                  BarChartData(
                    barGroups: List.generate(
                      months.length,
                      (index) {
                        final value = values[index];
                        final isPositive = value > 0;

                        return BarChartGroupData(
                          x: index,
                          barRods: [
                            BarChartRodData(
                              toY: value,
                              color: isPositive
                                  ? Colors.redAccent
                                  : Colors.greenAccent,
                              width: 12,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ],
                          showingTooltipIndicators: [0],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 80,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              formatCurrency(value),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.right,
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < months.length) {
                              final month = months[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  DateFormat('MMM').format(month),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawHorizontalLine: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxValue / 4,
                      getDrawingHorizontalLine: (value) {
                        return FlLine(
                          color: Colors.grey[200],
                          strokeWidth: 0.8,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: maxValue > 0 ? maxValue : 1,
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: false,
                      touchTooltipData: BarTouchTooltipData(
                        direction: TooltipDirection.top,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final month = months[groupIndex];
                          final amount = rod.toY;
                          return BarTooltipItem(
                            '${DateFormat('MMM yyyy').format(month)}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: formatCurrency(amount),
                                style: TextStyle(
                                  color: amount > 0
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      touchCallback:
                          (FlTouchEvent event, BarTouchResponse? response) {
                        if (event is FlTapUpEvent && response?.spot != null) {
                          final groupIndex =
                              response!.spot!.touchedBarGroupIndex;
                          if (groupIndex >= 0 && groupIndex < months.length) {
                            final selectedMonth = months[groupIndex];
                            // Ensure filter type is set to month
                            transactionProvider.setFilterType(FilterType.month);
                            // Set the selected date to the clicked month
                            transactionProvider.setSelectedDate(selectedMonth);
                          }
                        }
                      },
                    ),
                  ),
                ),
        ),
        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.redAccent, 'Loss (Expense > Income)'),
              const SizedBox(width: 24),
              _buildLegendItem(Colors.greenAccent, 'Profit (Income > Expense)'),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // Helper method to round up to nearest sensible interval
  double _roundUpToNearestInterval(double value) {
    if (value == 0) return 1.0;

    // Determine the order of magnitude
    final magnitude = 10 * (value.abs() / 10).floor().toStringAsFixed(0).length;
    final interval = (value.abs() / magnitude).ceil() * magnitude;

    // Use sensible intervals: 1M, 5M, 10M, 20M, etc.
    if (interval < 5000000) {
      return ((interval / 1000000).ceil() * 1000000).toDouble();
    } else if (interval < 50000000) {
      return ((interval / 5000000).ceil() * 5000000).toDouble();
    } else {
      return ((interval / 10000000).ceil() * 10000000).toDouble();
    }
  }
}
