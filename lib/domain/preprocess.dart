import 'dart:math';
import 'dart:typed_data';

import 'spectrum.dart';

Spectrum applyPreprocessing(Spectrum spectrum, List<Map<String, dynamic>> steps) {
  var current = spectrum;
  for (final step in steps) {
    final type = (step['type'] as String).toLowerCase();
    switch (type) {
      case 'smooth':
      case 'smoothing':
        final window = (step['window'] as int?) ?? 9;
        current = smoothMovingAverage(current, window);
        break;
      case 'snv':
        current = standardNormalVariate(current);
        break;
      case 'baseline':
        current = baselineCorrect(current);
        break;
      case 'derivative':
      case 'first_derivative':
        current = derivative(current, order: 1);
        break;
      case 'second_derivative':
        current = derivative(current, order: 2);
        break;
    }
  }
  return current;
}

Spectrum smoothMovingAverage(Spectrum spectrum, int window) {
  final half = max(1, window ~/ 2);
  final y = Float64List(spectrum.length);
  for (var i = 0; i < spectrum.length; i++) {
    var sum = 0.0;
    var count = 0;
    for (var j = i - half; j <= i + half; j++) {
      if (j >= 0 && j < spectrum.length) {
        sum += spectrum.y[j];
        count++;
      }
    }
    y[i] = sum / max(1, count);
  }
  return Spectrum(x: spectrum.x, y: y);
}

Spectrum standardNormalVariate(Spectrum spectrum) {
  final mean = spectrum.y.reduce((a, b) => a + b) / spectrum.length;
  var variance = 0.0;
  for (final value in spectrum.y) {
    variance += pow(value - mean, 2).toDouble();
  }
  final std = sqrt(variance / spectrum.length);
  final y = Float64List(spectrum.length);
  for (var i = 0; i < spectrum.length; i++) {
    y[i] = std == 0 ? 0 : (spectrum.y[i] - mean) / std;
  }
  return Spectrum(x: spectrum.x, y: y);
}

Spectrum baselineCorrect(Spectrum spectrum) {
  if (spectrum.length < 2) {
    return spectrum;
  }
  final x0 = spectrum.x.first;
  final x1 = spectrum.x.last;
  final y0 = spectrum.y.first;
  final y1 = spectrum.y.last;
  final slope = (y1 - y0) / (x1 - x0);
  final intercept = y0 - slope * x0;
  final y = Float64List(spectrum.length);
  for (var i = 0; i < spectrum.length; i++) {
    final baseline = slope * spectrum.x[i] + intercept;
    y[i] = spectrum.y[i] - baseline;
  }
  return Spectrum(x: spectrum.x, y: y);
}

Spectrum derivative(Spectrum spectrum, {int order = 1}) {
  var current = spectrum;
  for (var k = 0; k < order; k++) {
    final y = Float64List(current.length);
    for (var i = 1; i < current.length - 1; i++) {
      final dx = current.x[i + 1] - current.x[i - 1];
      y[i] = dx == 0 ? 0 : (current.y[i + 1] - current.y[i - 1]) / dx;
    }
    y[0] = y[1];
    y[current.length - 1] = y[current.length - 2];
    current = Spectrum(x: current.x, y: y);
  }
  return current;
}
