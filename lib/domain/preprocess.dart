import 'dart:math';
import 'dart:typed_data';

import 'spectrum.dart';

final Map<String, List<double>> _sgCoeffCache = <String, List<double>>{};

Spectrum applyPreprocessing(
  Spectrum spectrum,
  List<Map<String, dynamic>> steps,
) {
  var current = spectrum;
  for (final step in steps) {
    final type = (step['type'] as String).toLowerCase();
    switch (type) {
      case 'smooth':
      case 'smoothing':
        final window = (step['window'] as num?)?.toInt() ?? 9;
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
      case 'savitzky_golay':
      case 'savitzky-golay':
      case 'sg':
        final window = (step['window'] as num?)?.toInt() ?? 11;
        final polyorder = (step['polyorder'] as num?)?.toInt() ?? 2;
        final derivativeOrder = (step['derivative'] as num?)?.toInt() ?? 0;
        current = savitzkyGolay(
          current,
          windowLength: window,
          polyorder: polyorder,
          derivativeOrder: derivativeOrder,
        );
        break;
    }
  }
  return current;
}

Spectrum savitzkyGolay(
  Spectrum spectrum, {
  required int windowLength,
  required int polyorder,
  int derivativeOrder = 0,
}) {
  if (spectrum.length == 0) {
    return spectrum;
  }

  var window = windowLength;
  if (window < 3) {
    window = 3;
  }
  if (window.isEven) {
    window += 1;
  }
  if (window > spectrum.length) {
    window = spectrum.length.isOdd ? spectrum.length : spectrum.length - 1;
  }
  if (window < 3 || window <= polyorder) {
    return spectrum;
  }

  final safeDerivative = derivativeOrder < 0
      ? 0
      : (derivativeOrder > polyorder ? polyorder : derivativeOrder);

  final coeffs = _savgolCoefficients(
    windowLength: window,
    polyorder: polyorder,
    derivativeOrder: safeDerivative,
  );
  final half = window ~/ 2;

  final out = Float64List(spectrum.length);
  for (var i = 0; i < spectrum.length; i++) {
    var sum = 0.0;
    for (var j = 0; j < window; j++) {
      final sourceIndex = _reflectIndex(i + j - half, spectrum.length);
      sum += coeffs[j] * spectrum.y[sourceIndex];
    }
    out[i] = sum;
  }

  return Spectrum(x: spectrum.x, y: out);
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

int _reflectIndex(int index, int length) {
  if (length <= 1) {
    return 0;
  }
  var i = index;
  while (i < 0 || i >= length) {
    if (i < 0) {
      i = -i - 1;
    } else {
      i = (2 * length) - i - 1;
    }
  }
  return i;
}

List<double> _savgolCoefficients({
  required int windowLength,
  required int polyorder,
  required int derivativeOrder,
}) {
  final cacheKey = '$windowLength|$polyorder|$derivativeOrder';
  final cached = _sgCoeffCache[cacheKey];
  if (cached != null) {
    return cached;
  }

  final rows = windowLength;
  final cols = polyorder + 1;
  final half = windowLength ~/ 2;

  final a = List<List<double>>.generate(rows, (r) {
    final k = (r - half).toDouble();
    return List<double>.generate(cols, (c) => pow(k, c).toDouble());
  });

  final ata = List<List<double>>.generate(
    cols,
    (_) => List<double>.filled(cols, 0),
  );
  for (var r = 0; r < rows; r++) {
    for (var i = 0; i < cols; i++) {
      for (var j = 0; j < cols; j++) {
        ata[i][j] += a[r][i] * a[r][j];
      }
    }
  }

  final invAta = _invertMatrix(ata);
  final factorial = _factorial(derivativeOrder).toDouble();
  final coeff = List<double>.filled(rows, 0);
  for (var r = 0; r < rows; r++) {
    var value = 0.0;
    for (var j = 0; j < cols; j++) {
      value += invAta[derivativeOrder][j] * a[r][j];
    }
    coeff[r] = value * factorial;
  }

  _sgCoeffCache[cacheKey] = coeff;
  return coeff;
}

List<List<double>> _invertMatrix(List<List<double>> matrix) {
  final n = matrix.length;
  final a = List<List<double>>.generate(n, (i) => List<double>.from(matrix[i]));
  final inv = List<List<double>>.generate(
    n,
    (i) => List<double>.generate(n, (j) => i == j ? 1.0 : 0.0),
  );

  for (var i = 0; i < n; i++) {
    var pivot = a[i][i];
    if (pivot.abs() < 1e-12) {
      var swapRow = i + 1;
      while (swapRow < n && a[swapRow][i].abs() < 1e-12) {
        swapRow += 1;
      }
      if (swapRow >= n) {
        throw StateError(
          'Matrix inversion failed for Savitzky-Golay coefficients',
        );
      }
      final tmpA = a[i];
      a[i] = a[swapRow];
      a[swapRow] = tmpA;
      final tmpInv = inv[i];
      inv[i] = inv[swapRow];
      inv[swapRow] = tmpInv;
      pivot = a[i][i];
    }

    final invPivot = 1.0 / pivot;
    for (var c = 0; c < n; c++) {
      a[i][c] *= invPivot;
      inv[i][c] *= invPivot;
    }

    for (var r = 0; r < n; r++) {
      if (r == i) {
        continue;
      }
      final factor = a[r][i];
      if (factor.abs() < 1e-12) {
        continue;
      }
      for (var c = 0; c < n; c++) {
        a[r][c] -= factor * a[i][c];
        inv[r][c] -= factor * inv[i][c];
      }
    }
  }

  return inv;
}

int _factorial(int n) {
  if (n <= 1) {
    return 1;
  }
  var out = 1;
  for (var i = 2; i <= n; i++) {
    out *= i;
  }
  return out;
}
