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
    this.overlays = const [],
  });

  final Spectrum? spectrum;
  final String title;
  final String axisUnit;
  final int maxPoints;
  final double minY;
  final double maxY;
  final bool simplified;

  /// Additional spectra rendered as faded background traces.
  /// Useful for displaying every individual scan under the averaged trace.
  final List<Spectrum> overlays;

  @override
  State<SpectrumChart> createState() => _SpectrumChartState();
}

class _SpectrumChartState extends State<SpectrumChart> {
  late Future<_ChartData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _buildData();
  }

  @override
  void didUpdateWidget(covariant SpectrumChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spectrum != widget.spectrum ||
        oldWidget.axisUnit != widget.axisUnit ||
        oldWidget.maxPoints != widget.maxPoints ||
        oldWidget.minY != widget.minY ||
        oldWidget.maxY != widget.maxY ||
        !identical(oldWidget.overlays, widget.overlays) ||
        oldWidget.overlays.length != widget.overlays.length) {
      _dataFuture = _buildData();
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 280,
              child: FutureBuilder<_ChartData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  final data =
                      snapshot.data ??
                      _ChartData(main: [const FlSpot(0, 0)], overlays: const []);
                  final enableTouch = !widget.simplified;
                  final xInterval = _computeXInterval(data.main);
                  final overlayColor = AppTheme.accent.withValues(alpha: 0.22);
                  final overlayBars = [
                    for (final spots in data.overlays)
                      LineChartBarData(
                        spots: spots,
                        isCurved: false,
                        barWidth: 1.0,
                        dotData: FlDotData(show: false),
                        color: overlayColor,
                        belowBarData: BarAreaData(show: false),
                      ),
                  ];
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
                            interval: xInterval,
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
                        ...overlayBars,
                        LineChartBarData(
                          spots: data.main,
                          isCurved: !widget.simplified,
                          barWidth: widget.simplified ? 1.6 : 2.2,
                          dotData: FlDotData(show: false),
                          color: AppTheme.accent,
                          belowBarData: BarAreaData(
                            show: !widget.simplified && overlayBars.isEmpty,
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

  Future<_ChartData> _buildData() async {
    final spectrum = widget.spectrum;
    if (spectrum == null || spectrum.length == 0) {
      return _ChartData(main: [const FlSpot(0, 0)], overlays: const []);
    }
    if (widget.simplified) {
      return _ChartData(
        main: _buildPointsSync(spectrum),
        overlays: [for (final o in widget.overlays) _buildPointsSync(o)],
      );
    }
    try {
      final pairs = await compute(_downsamplePairs, {
        'x': spectrum.x,
        'y': spectrum.y,
        'maxPoints': widget.maxPoints,
        'axisUnit': widget.axisUnit,
      });
      final mainPoints = _pairsToSpots(pairs);
      if (widget.axisUnit != 'DN') {
        mainPoints.sort((a, b) => a.x.compareTo(b.x));
      }
      final overlayPoints = <List<FlSpot>>[];
      for (final overlay in widget.overlays) {
        overlayPoints.add(_buildPointsSync(overlay));
      }
      return _ChartData(main: mainPoints, overlays: overlayPoints);
    } catch (_) {
      return _ChartData(
        main: _buildPointsSync(spectrum),
        overlays: [for (final o in widget.overlays) _buildPointsSync(o)],
      );
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
    if (widget.axisUnit != 'DN') {
      points.sort((a, b) => a.x.compareTo(b.x));
    }
    return points;
  }

  double _toAxisValue(double x, int dn) {
    switch (widget.axisUnit) {
      case 'DN':
        return dn.toDouble();
      case 'cm^-1':
        return x;
      case 'nm':
        if (x <= 0) {
          return 0;
        }
        return 10000000.0 / x;
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

  double _computeXInterval(List<FlSpot> points) {
    if (points.length < 2) {
      return 1;
    }
    var minX = points.first.x;
    var maxX = points.first.x;
    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.x > maxX) maxX = point.x;
    }
    final range = (maxX - minX).abs();
    if (range <= 0 || !range.isFinite) {
      return 1;
    }
    final interval = range / 4;
    if (!interval.isFinite || interval <= 0) {
      return 1;
    }
    return interval;
  }

  List<FlSpot> _pairsToSpots(List<double> pairs) {
    final points = <FlSpot>[];
    for (var i = 0; i + 1 < pairs.length; i += 2) {
      points.add(FlSpot(pairs[i], pairs[i + 1]));
    }
    return points;
  }
}

class _ChartData {
  _ChartData({required this.main, required this.overlays});

  final List<FlSpot> main;
  final List<List<FlSpot>> overlays;
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
      pairs.add(x[i]);
    } else if (axisUnit == 'nm') {
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
