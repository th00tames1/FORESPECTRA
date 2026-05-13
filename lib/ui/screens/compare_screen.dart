import 'dart:typed_data';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/storage/data_store.dart';
import '../../domain/measurement.dart';
import '../../services/app_state.dart';
import '../theme/app_theme.dart';

class CompareScreen extends StatefulWidget {
  const CompareScreen({
    super.key,
    required this.left,
    required this.right,
  });

  final Measurement left;
  final Measurement right;

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  Future<List<_TraceData>>? _loadFuture;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppState>().dataStore;
    _loadFuture = _loadBoth(store);
  }

  Future<List<_TraceData>> _loadBoth(DataStore store) async {
    final measurements = [widget.left, widget.right];
    final blobLists = await Future.wait(
      measurements.map((m) => store.getSpectra(m.id)),
    );
    final results = <_TraceData>[];
    for (var i = 0; i < measurements.length; i++) {
      final blobs = blobLists[i];
      if (blobs.isEmpty) continue;
      final blob = blobs.first;
      results.add(_TraceData(
        measurement: measurements[i],
        x: blob.xBytes.buffer.asFloat64List(),
        y: blob.yBytes.buffer.asFloat64List(),
      ));
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final axisUnit = context.read<AppState>().spectrumAxisUnit;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Compare scans')),
      body: SafeArea(
        child: FutureBuilder<List<_TraceData>>(
          future: _loadFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final traces = snapshot.data!;
            if (traces.length < 2) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Could not load spectra for both scans.',
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _legend(context, traces),
                  const SizedBox(height: 12),
                  Expanded(child: _chart(context, traces, axisUnit)),
                  const SizedBox(height: 12),
                  _meta(context, traces),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _legend(BuildContext context, List<_TraceData> traces) {
    return Row(
      children: [
        _legendDot(AppTheme.accent),
        const SizedBox(width: 6),
        Flexible(child: Text(_traceLabel(traces[0]))),
        const SizedBox(width: 16),
        _legendDot(const Color(0xFF2563EB)),
        const SizedBox(width: 6),
        Flexible(child: Text(_traceLabel(traces[1]))),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  String _traceLabel(_TraceData t) {
    final material = t.measurement.materialName ?? '';
    final sample = t.measurement.sampleName ?? '';
    if (material.isEmpty && sample.isEmpty) {
      return t.measurement.id.substring(0, 8);
    }
    return [material, sample].where((s) => s.isNotEmpty).join(' / ');
  }

  Widget _chart(
    BuildContext context,
    List<_TraceData> traces,
    String axisUnit,
  ) {
    final spots = traces.map((t) => _toSpots(t, axisUnit)).toList();
    final colors = [AppTheme.accent, const Color(0xFF2563EB)];
    final mutedColor =
        Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 12, 12),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 1.1,
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
                  reservedSize: 30,
                  interval: 0.2,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mutedColor,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                axisNameWidget: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    axisUnit,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mutedColor,
                    ),
                  ),
                ),
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mutedColor,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
            ),
            lineBarsData: [
              for (var i = 0; i < spots.length; i++)
                LineChartBarData(
                  spots: spots[i],
                  isCurved: false,
                  barWidth: 2,
                  color: colors[i],
                  dotData: FlDotData(show: false),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<FlSpot> _toSpots(_TraceData t, String axisUnit) {
    final stride = (t.x.length / 512).ceil().clamp(1, t.x.length);
    final points = <FlSpot>[];
    var dn = 1;
    for (var i = 0; i < t.x.length; i += stride) {
      double xv;
      switch (axisUnit) {
        case 'DN':
          xv = dn.toDouble();
          break;
        case 'nm':
          xv = t.x[i] <= 0 ? 0 : 10000000.0 / t.x[i];
          break;
        default:
          xv = t.x[i];
      }
      points.add(FlSpot(xv, t.y[i]));
      dn += 1;
    }
    if (axisUnit != 'DN') {
      points.sort((a, b) => a.x.compareTo(b.x));
    }
    return points;
  }

  Widget _meta(BuildContext context, List<_TraceData> traces) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: traces
              .map(
                (t) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${_traceLabel(t)} — ${t.measurement.timestamp}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _TraceData {
  _TraceData({
    required this.measurement,
    required this.x,
    required this.y,
  });

  final Measurement measurement;
  final Float64List x;
  final Float64List y;
}
