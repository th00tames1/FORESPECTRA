import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/spectrum.dart';
import '../theme/app_theme.dart';

class SpectrumChart extends StatefulWidget {
  const SpectrumChart({
    super.key,
    required this.spectrum,
    required this.title,
    this.axisUnit = 'nm',
    this.maxPoints = 512,
    this.minY = 0,
    this.maxY = 1.1,
    this.simplified = false,
  });

  final Spectrum? spectrum;
  final String title;
  final String axisUnit;
  final int maxPoints;
  final double minY;
  final double maxY;
  final bool simplified;

  @override
  State<SpectrumChart> createState() => _SpectrumChartState();
}

class _SpectrumChartState extends State<SpectrumChart> {
  late Future<List<FlSpot>> _pointsFuture;

  @override
  void initState() {
    super.initState();
    _pointsFuture = _buildPoints();
  }

  @override
  void didUpdateWidget(covariant SpectrumChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spectrum != widget.spectrum ||
        oldWidget.axisUnit != widget.axisUnit ||
        oldWidget.maxPoints != widget.maxPoints ||
        oldWidget.minY != widget.minY ||
        oldWidget.maxY != widget.maxY) {
      _pointsFuture = _buildPoints();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.title.trim().isNotEmpty) ...[
              Text(widget.title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 280,
              child: FutureBuilder<List<FlSpot>>(
                future: _pointsFuture,
                builder: (context, snapshot) {
                  final points = snapshot.data ?? [const FlSpot(0, 0)];
                  final enableTouch = !widget.simplified;
                  return LineChart(
                    LineChartData(
                      minY: widget.minY,
                      maxY: widget.maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.2,
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            interval: 0.2,
                            minIncluded: true,
                            maxIncluded: true,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  value.toStringAsFixed(1),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.muted,
                                    fontSize: 8,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          axisNameWidget: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.axisUnit,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.muted,
                                  ),
                            ),
                          ),
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 26,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  _formatAxisValue(value),
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.muted,
                                    fontSize: 8,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        enabled: enableTouch,
                        handleBuiltInTouches: enableTouch,
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (_) => Theme.of(context).cardColor,
                          getTooltipItems: (spots) {
                            return spots
                                .map(
                                  (spot) => LineTooltipItem(
                                    '${_formatTooltipX(spot.x)} ${widget.axisUnit}\n${spot.y.toStringAsFixed(3)}',
                                    Theme.of(context).textTheme.labelSmall!,
                                  ),
                                )
                                .toList();
                          },
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: points,
                          isCurved: !widget.simplified,
                          barWidth: widget.simplified ? 1.6 : 2.2,
                          dotData: FlDotData(show: false),
                          color: AppTheme.accent,
                          belowBarData: BarAreaData(
                            show: !widget.simplified,
                            gradient: LinearGradient(
                              colors: [
                                AppTheme.accent.withValues(alpha: 0.22),
                                Colors.transparent,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<FlSpot>> _buildPoints() async {
    final spectrum = widget.spectrum;
    if (spectrum == null || spectrum.length == 0) {
      return [const FlSpot(0, 0)];
    }
    try {
      final pairs = await compute(_downsamplePairs, {
        'x': spectrum.x,
        'y': spectrum.y,
        'maxPoints': widget.maxPoints,
        'axisUnit': widget.axisUnit,
      });
      return _pairsToSpots(pairs);
    } catch (_) {
      return _buildPointsSync(spectrum);
    }
  }

  List<FlSpot> _buildPointsSync(Spectrum spectrum) {
    final stride = (spectrum.length / widget.maxPoints)
        .ceil()
        .clamp(1, spectrum.length);
    final points = <FlSpot>[];
    var dn = 1;
    for (var i = 0; i < spectrum.length; i += stride) {
      final x = _toAxisValue(spectrum.x[i], dn);
      points.add(FlSpot(x, spectrum.y[i]));
      dn += 1;
    }
    return points;
  }

  double _toAxisValue(double x, int dn) {
    switch (widget.axisUnit) {
      case 'DN':
        return dn.toDouble();
      case 'cm^-1':
        if (x <= 0) {
          return 0;
        }
        return 10000000.0 / x;
      case 'nm':
      default:
        return x;
    }
  }

  String _formatAxisValue(double value) {
    if (widget.axisUnit == 'DN') {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(0);
  }

  String _formatTooltipX(double value) {
    if (widget.axisUnit == 'DN') {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  List<FlSpot> _pairsToSpots(List<double> pairs) {
    final points = <FlSpot>[];
    for (var i = 0; i + 1 < pairs.length; i += 2) {
      points.add(FlSpot(pairs[i], pairs[i + 1]));
    }
    return points;
  }
}

List<double> _downsamplePairs(Map<String, Object> args) {
  final x = args['x'] as Float64List;
  final y = args['y'] as Float64List;
  final maxPoints = args['maxPoints'] as int;
  final axisUnit = args['axisUnit'] as String;
  if (x.isEmpty || y.isEmpty) {
    return <double>[0, 0];
  }
  final length = x.length < y.length ? x.length : y.length;
  final stride = (length / maxPoints).ceil().clamp(1, length);
  final pairs = <double>[];
  var dn = 1;
  for (var i = 0; i < length; i += stride) {
    if (axisUnit == 'DN') {
      pairs.add(dn.toDouble());
    } else if (axisUnit == 'cm^-1') {
      final raw = x[i];
      pairs.add(raw <= 0 ? 0 : 10000000.0 / raw);
    } else {
      pairs.add(x[i]);
    }
    pairs.add(y[i]);
    dn += 1;
  }
  return pairs;
}
