import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:mamoney/services/transaction_provider.dart';
import 'package:mamoney/models/transaction.dart';
import 'package:mamoney/utils/currency_utils.dart';
import 'package:intl/intl.dart';

class NetBalanceChart extends StatefulWidget {
  final TransactionProvider transactionProvider;

  const NetBalanceChart({
    super.key,
    required this.transactionProvider,
  });

  @override
  State<NetBalanceChart> createState() => _NetBalanceChartState();
}

class _NetBalanceChartState extends State<NetBalanceChart> {
  int? _selectedBarIndex;

  @override
  Widget build(BuildContext context) {
    final netBalanceData =
        widget.transactionProvider.getNetBalanceByMonthFromToday(12);

    final months = netBalanceData.keys.toList()..sort();
    final values = months.map((month) => netBalanceData[month]!).toList();

    final maxAbsValue = values.isEmpty
        ? 1.0
        : values.reduce((a, b) => a.abs() > b.abs() ? a.abs() : b.abs());

    final maxValue =
        values.isEmpty ? 1.0 : _roundUpToNearestInterval(maxAbsValue);
    final minValue = -maxValue * 0.1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Text(
            'Net Balance (Last 12 Months)',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        Container(
          height: 380,
          padding: const EdgeInsets.fromLTRB(8, 24, 16, 32),
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
                          showingTooltipIndicators:
                              _selectedBarIndex == index ? [0] : [],
                          barRods: [
                            BarChartRodData(
                              toY: value,
                              color: isPositive
                                  ? const Color(0xFFEF5350)
                                  : const Color(0xFF66BB6A),
                              width: 18,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 55,
                          getTitlesWidget: (value, meta) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Text(
                                _formatCompactCurrency(value),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < months.length) {
                              final month = months[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: 12.0),
                                child: Text(
                                  DateFormat('M').format(month), // <-- changed
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w600,
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
                          color: Colors.grey[300],
                          strokeWidth: 0.5,
                          dashArray: [5, 5],
                        );
                      },
                    ),
                    borderData: FlBorderData(
                      show: true,
                      border: Border(
                        left: BorderSide(color: Colors.grey[300]!),
                        bottom: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    minY: 0,
                    maxY: maxValue > 0 ? maxValue : 1,
                    barTouchData: BarTouchData(
                      enabled: true,
                      handleBuiltInTouches: false,
                      touchTooltipData: BarTouchTooltipData(
                        direction: TooltipDirection.top,
                        tooltipPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          final month = months[groupIndex];
                          final amount = rod.toY;
                          return BarTooltipItem(
                            '${DateFormat('MM yyyy').format(month)}\n',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: formatCurrency(amount),
                                style: TextStyle(
                                  color: amount > 0
                                      ? const Color(0xFFFFB74D)
                                      : const Color(0xFF81C784),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      touchCallback:
                          (FlTouchEvent event, BarTouchResponse? response) {
                        if (event is FlTapUpEvent) {
                          final tappedIndex =
                              response?.spot?.touchedBarGroupIndex;

                          setState(() {
                            _selectedBarIndex = tappedIndex == _selectedBarIndex
                                ? null
                                : tappedIndex;
                          });

                          if (tappedIndex != null &&
                              tappedIndex >= 0 &&
                              tappedIndex < months.length) {
                            final selectedMonth = months[tappedIndex];
                            widget.transactionProvider
                                .setFilterType(FilterType.month);
                            widget.transactionProvider
                                .setSelectedDate(selectedMonth);
                          }
                        }
                      },
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                const Color(0xFFEF5350),
                'Loss',
              ),
              const SizedBox(width: 32),
              _buildLegendItem(
                const Color(0xFF66BB6A),
                'Profit',
              ),
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
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCompactCurrency(double value) {
    if (value == 0) {
      return '0';
    }

    final thousands = value / 1000;
    final millions = value / 1000000;

    if (thousands.abs() < 1) {
      return value.toStringAsFixed(0);
    } else if (thousands.abs() < 1000) {
      final formatted = thousands % 1 == 0
          ? thousands.toStringAsFixed(0)
          : thousands.toStringAsFixed(1);
      return '${formatted}k';
    } else if (millions.abs() < 1000) {
      final formatted = millions % 1 == 0
          ? millions.toStringAsFixed(0)
          : millions.toStringAsFixed(1);
      return '$formatted tr';
    } else {
      final billions = value / 1000000000;
      final formatted = billions % 1 == 0
          ? billions.toStringAsFixed(0)
          : billions.toStringAsFixed(1);
      return '$formatted tỷ';
    }
  }

  double _roundUpToNearestInterval(double value) {
    if (value == 0) return 1.0;

    final magnitude = 10 * (value.abs() / 10).floor().toStringAsFixed(0).length;
    final interval = (value.abs() / magnitude).ceil() * magnitude;

    if (interval < 5000000) {
      return ((interval / 1000000).ceil() * 1000000).toDouble();
    } else if (interval < 50000000) {
      return ((interval / 5000000).ceil() * 5000000).toDouble();
    } else {
      return ((interval / 10000000).ceil() * 10000000).toDouble();
    }
  }
}
