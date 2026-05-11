import 'dart:typed_data';

import 'spectrum.dart';

enum AveragingMethod { mean, median }

extension AveragingMethodLabel on AveragingMethod {
  String get id {
    switch (this) {
      case AveragingMethod.mean:
        return 'mean';
      case AveragingMethod.median:
        return 'median';
    }
  }

  String get label {
    switch (this) {
      case AveragingMethod.mean:
        return 'Mean (co-add)';
      case AveragingMethod.median:
        return 'Median (robust)';
    }
  }

  static AveragingMethod fromId(String? id) {
    switch (id) {
      case 'median':
        return AveragingMethod.median;
      case 'mean':
      default:
        return AveragingMethod.mean;
    }
  }
}

Spectrum? averageSpectra(
  List<Spectrum> spectra, {
  AveragingMethod method = AveragingMethod.mean,
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
  }

  return Spectrum(x: x, y: y);
}
