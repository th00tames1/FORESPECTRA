import 'dart:typed_data';

import 'spectrum.dart';

enum AveragingMethod { mean, median, trimmedMean }

extension AveragingMethodLabel on AveragingMethod {
  String get id {
    switch (this) {
      case AveragingMethod.mean:
        return 'mean';
      case AveragingMethod.median:
        return 'median';
      case AveragingMethod.trimmedMean:
        return 'trimmed_mean';
    }
  }

  String get label {
    switch (this) {
      case AveragingMethod.mean:
        return 'Mean';
      case AveragingMethod.median:
        return 'Median';
      case AveragingMethod.trimmedMean:
        return 'Trim';
    }
  }

  static AveragingMethod fromId(String? id) {
    switch (id) {
      case 'median':
        return AveragingMethod.median;
      case 'trimmed_mean':
        return AveragingMethod.trimmedMean;
      case 'mean':
      default:
        return AveragingMethod.mean;
    }
  }
}

/// Clamp a requested trim-drop count to what's valid for [n] scans: never
/// negative, and never so many that fewer than 2 scans would remain.
int clampTrimDrop(int n, int desired) {
  if (n < 3) return 0;
  final maxDrop = n - 2;
  if (desired < 0) return 0;
  if (desired > maxDrop) return maxDrop;
  return desired;
}

Spectrum? averageSpectra(
  List<Spectrum> spectra, {
  AveragingMethod method = AveragingMethod.mean,
  int trimDrop = 2,
}) {
  if (spectra.isEmpty) {
    return null;
  }
  if (spectra.length == 1) {
    final only = spectra.first;
    return Spectrum(
      x: Float64List.fromList(only.x),
      y: Float64List.fromList(only.y),
    );
  }

  final length = spectra
      .map((s) => s.length)
      .reduce((a, b) => a < b ? a : b);
  if (length == 0) {
    return null;
  }

  final x = Float64List(length);
  for (var i = 0; i < length; i++) {
    x[i] = spectra.first.x[i];
  }

  final y = Float64List(length);
  switch (method) {
    case AveragingMethod.mean:
      for (var i = 0; i < length; i++) {
        var sum = 0.0;
        for (final s in spectra) {
          sum += s.y[i];
        }
        y[i] = sum / spectra.length;
      }
      break;
    case AveragingMethod.median:
      final scratch = List<double>.filled(spectra.length, 0);
      for (var i = 0; i < length; i++) {
        for (var k = 0; k < spectra.length; k++) {
          scratch[k] = spectra[k].y[i];
        }
        scratch.sort();
        final n = scratch.length;
        y[i] = n.isOdd
            ? scratch[n ~/ 2]
            : 0.5 * (scratch[n ~/ 2 - 1] + scratch[n ~/ 2]);
      }
      break;
    case AveragingMethod.trimmedMean:
      _trimmedMean(spectra, length, y, clampTrimDrop(spectra.length, trimDrop));
      break;
  }

  return Spectrum(x: x, y: y);
}

/// Drops the scans that deviate most from the per-wavelength median (a robust
/// consensus the outlier itself can't drag), then averages the rest. Lets one
/// badly-placed scan be ignored instead of corrupting the average.
void _trimmedMean(
  List<Spectrum> spectra,
  int length,
  Float64List out,
  int drop,
) {
  final n = spectra.length;
  if (drop <= 0) {
    // Nothing to trim: plain mean.
    for (var i = 0; i < length; i++) {
      var sum = 0.0;
      for (final s in spectra) {
        sum += s.y[i];
      }
      out[i] = sum / n;
    }
    return;
  }

  final order = _deviationOrder(spectra, length);
  final keep = n - drop;
  for (var i = 0; i < length; i++) {
    var sum = 0.0;
    for (var j = 0; j < keep; j++) {
      sum += spectra[order[j]].y[i];
    }
    out[i] = sum / keep;
  }
}

/// Scan indices ordered by ascending deviation from the per-wavelength median
/// (least-deviant first). The most-deviant scans are at the tail.
List<int> _deviationOrder(List<Spectrum> spectra, int length) {
  final n = spectra.length;
  final consensus = Float64List(length);
  final scratch = List<double>.filled(n, 0);
  for (var i = 0; i < length; i++) {
    for (var k = 0; k < n; k++) {
      scratch[k] = spectra[k].y[i];
    }
    scratch.sort();
    consensus[i] = n.isOdd
        ? scratch[n ~/ 2]
        : 0.5 * (scratch[n ~/ 2 - 1] + scratch[n ~/ 2]);
  }
  final deviation = List<double>.filled(n, 0);
  for (var k = 0; k < n; k++) {
    var sum = 0.0;
    for (var i = 0; i < length; i++) {
      sum += (spectra[k].y[i] - consensus[i]).abs();
    }
    deviation[k] = sum / length;
  }
  final order = List<int>.generate(n, (k) => k);
  order.sort((a, b) => deviation[a].compareTo(deviation[b]));
  return order;
}

/// Zero-based indices of the scans a trimmed mean would drop, sorted ascending.
/// Empty when there is nothing to trim.
List<int> trimmedMeanDroppedIndices(List<Spectrum> spectra, int trimDrop) {
  if (spectra.length < 3) return const [];
  final length = spectra
      .map((s) => s.length)
      .reduce((a, b) => a < b ? a : b);
  if (length == 0) return const [];
  final drop = clampTrimDrop(spectra.length, trimDrop);
  if (drop <= 0) return const [];
  final order = _deviationOrder(spectra, length);
  final dropped = order.sublist(order.length - drop)..sort();
  return dropped;
}
