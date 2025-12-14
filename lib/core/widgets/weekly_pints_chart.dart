import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class WeeklyPintsChart extends StatelessWidget {
  final List<int> dailyPints; // 7 days, Monday to Sunday

  const WeeklyPintsChart({
    super.key,
    required this.dailyPints,
  });

  @override
  Widget build(BuildContext context) {
    final maxY = (dailyPints.reduce((a, b) => a > b ? a : b) + 2).toDouble();

    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.only(right: 16, top: 8),
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: 0,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final day = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][group.x.toInt()];
                  return BarTooltipItem(
                    '$day\n${rod.toY.toInt()} pints',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                },
              ),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    if (value.toInt() >= 0 && value.toInt() < days.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          days[value.toInt()],
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    if (value % 1 == 0 && value >= 0) {
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
              ),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) {
                return FlLine(
                  color: Colors.grey.shade200,
                  strokeWidth: 1,
                );
              },
            ),
            barGroups: List.generate(7, (index) {
              final pints = dailyPints[index];
              final isToday = index == DateTime.now().weekday - 1;
              
              return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: pints.toDouble(),
                    gradient: LinearGradient(
                      colors: isToday
                          ? [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ]
                          : [
                              Theme.of(context).colorScheme.primary.withOpacity(0.6),
                              Theme.of(context).colorScheme.primary.withOpacity(0.4),
                            ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                    width: 20,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: Colors.grey.shade100,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

