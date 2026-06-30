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
    this.maxY = 1.0,
    this.simplified = false,
    this.overlays = const [],
    this.droppedOverlays = const <int>{},
    this.overlayLegendLabel,
    this.droppedLegendLabel,
    this.mainLegendLabel,
  });

  final Spectrum? spectrum;
  final String title;
  final String axisUnit;
  final int maxPoints;
  final double minY;
  final double maxY;
  final bool simplified;

  /// Additional spectra rendered as background traces (one per individual
  /// scan) underneath the bold main/averaged trace.
  final List<Spectrum> overlays;

  /// Indices into [overlays] that were dropped as outliers (e.g. by the trimmed
  /// mean). Drawn as a distinct red dashed trace.
  final Set<int> droppedOverlays;

  /// When set together with [mainLegendLabel] and at least one overlay, a small
  /// legend is drawn under the title identifying the overlay vs main traces.
  final String? overlayLegendLabel;
  final String? droppedLegendLabel;
  final String? mainLegendLabel;

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
        oldWidget.simplified != widget.simplified ||
        !identical(oldWidget.overlays, widget.overlays) ||
        oldWidget.overlays.length != widget.overlays.length) {
      _dataFuture = _buildData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlayLineColor = AppTheme.muted.withValues(alpha: 0.55);
    final droppedColor = const Color(0xFFD0021B).withValues(alpha: 0.75);
    final showLegend = widget.overlays.isNotEmpty &&
        widget.overlayLegendLabel != null &&
        widget.mainLegendLabel != null;
    final showDroppedLegend = widget.droppedOverlays.isNotEmpty &&
        widget.droppedLegendLabel != null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
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
              const SizedBox(height: 8),
            ],
            if (showLegend) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 4,
                  children: [
                    _legendSwatch(
                      context,
                      color: overlayLineColor,
                      label: widget.overlayLegendLabel!,
                      thickness: 1.5,
                    ),
                    if (showDroppedLegend)
                      _legendSwatch(
                        context,
                        color: droppedColor,
                        label: widget.droppedLegendLabel!,
                        thickness: 1.5,
                      ),
                    _legendSwatch(
                      context,
                      color: AppTheme.accent,
                      label: widget.mainLegendLabel!,
                      thickness: 3,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
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
                  final overlayBars = <LineChartBarData>[];
                  for (var idx = 0; idx < data.overlays.length; idx++) {
                    final isDropped = widget.droppedOverlays.contains(idx);
                    overlayBars.add(
                      LineChartBarData(
                        spots: data.overlays[idx],
                        isCurved: false,
                        barWidth: isDropped ? 1.4 : 1.1,
                        dashArray: isDropped ? const [5, 3] : null,
                        dotData: FlDotData(show: false),
                        color: isDropped ? droppedColor : overlayLineColor,
                        belowBarData: BarAreaData(show: false),
                      ),
                    );
                  }
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
                            reservedSize: 22,
                            interval: 0.2,
                            minIncluded: true,
                            maxIncluded: true,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                fitInside:
                                    SideTitleFitInsideData.fromTitleMeta(meta),
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
                            minIncluded: true,
                            maxIncluded: true,
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                // Keep the first/last labels inside the plot box
                                // instead of overflowing the right edge.
                                fitInside:
                                    SideTitleFitInsideData.fromTitleMeta(meta),
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
                          barWidth: widget.simplified
                              ? 1.6
                              : (overlayBars.isEmpty ? 2.2 : 2.6),
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

  Widget _legendSwatch(
    BuildContext context, {
    required Color color,
    required String label,
    required double thickness,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 18, height: thickness, color: color),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
              ),
        ),
      ],
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
      final yv = spectrum.y[i];
      final x = _toAxisValue(spectrum.x[i], dn);
      dn += 1;
      // Skip non-finite samples; fl_chart throws on NaN/Inf spots.
      if (!x.isFinite || !yv.isFinite) continue;
      points.add(FlSpot(x, yv));
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
    // One interval == the whole range => only the two endpoint labels (e.g.
    // 1350 and 2550). Any middle label collides with the fitInside-shifted end
    // labels on a narrow chart, so we drop it entirely.
    final interval = range;
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

  double axisValue(int i, int dn) {
    if (axisUnit == 'DN') return dn.toDouble();
    if (axisUnit == 'cm^-1') return x[i];
    if (axisUnit == 'nm') {
      final raw = x[i];
      return raw <= 0 ? 0 : 10000000.0 / raw;
    }
    return x[i];
  }

  // Skip non-finite samples; fl_chart throws on NaN/Inf spots.
  void emit(double xv, double yv) {
    if (!xv.isFinite || !yv.isFinite) return;
    pairs.add(xv);
    pairs.add(yv);
  }

  // No decimation (or the ordinal DN view): keep every sampled point as-is.
  if (stride == 1 || axisUnit == 'DN') {
    var dn = 1;
    for (var i = 0; i < length; i += stride) {
      emit(axisValue(i, dn), y[i]);
      dn += 1;
    }
    return pairs;
  }

  // Decimating a real wavelength axis: within each stride bucket keep BOTH the
  // min-y and max-y sample (in index order) instead of a single point, so a
  // narrow absorption peak/valley is not silently dropped. The caller re-sorts
  // the main trace by x, so the within-bucket emission order is irrelevant.
  for (var b = 0; b < length; b += stride) {
    final end = (b + stride < length) ? b + stride : length;
    var minIdx = b;
    var maxIdx = b;
    for (var i = b + 1; i < end; i++) {
      if (y[i] < y[minIdx]) minIdx = i;
      if (y[i] > y[maxIdx]) maxIdx = i;
    }
    final lo = minIdx <= maxIdx ? minIdx : maxIdx;
    final hi = minIdx <= maxIdx ? maxIdx : minIdx;
    emit(axisValue(lo, 0), y[lo]);
    if (hi != lo) {
      emit(axisValue(hi, 0), y[hi]);
    }
  }
  return pairs;
}
