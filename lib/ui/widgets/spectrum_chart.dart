import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/spectrum.dart';
import '../theme/app_theme.dart';

class SpectrumChart extends StatelessWidget {
  const SpectrumChart({super.key, required this.spectrum, required this.title});

  final Spectrum? spectrum;
  final String title;

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints(spectrum);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            AspectRatio(
              aspectRatio: 1.7,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 42),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: points,
                      isCurved: true,
                      barWidth: 2.4,
                      dotData: FlDotData(show: false),
                      color: AppTheme.accent,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accent.withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<FlSpot> _buildPoints(Spectrum? spectrum) {
    if (spectrum == null || spectrum.length == 0) {
      return [const FlSpot(0, 0)];
    }
    final stride = (spectrum.length / 512).ceil().clamp(1, spectrum.length);
    final points = <FlSpot>[];
    for (var i = 0; i < spectrum.length; i += stride) {
      points.add(FlSpot(spectrum.x[i], spectrum.y[i]));
    }
    return points;
  }
}
