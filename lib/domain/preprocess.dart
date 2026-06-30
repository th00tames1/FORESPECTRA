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
  if (window < 3 || polyorder < 1 || window <= polyorder) {
    return spectrum;
  }

  final safeDerivative = derivativeOrder < 0
      ? 0
      : (derivativeOrder > polyorder ? polyorder : derivativeOrder);

  final centerCoeffs = _savgolCoefficients(
    windowLength: window,
    polyorder: polyorder,
    derivativeOrder: safeDerivative,
  );
  final half = window ~/ 2;
  final n = spectrum.length;

  // Match scipy.signal.savgol_filter's default mode='interp' (used by the
  // trained pipeline): the interior uses the centered kernel, while the first
  // and last `half` samples evaluate the boundary-window polynomial fit at
  // their actual offset instead of reflect-padding the signal. Reflect padding
  // silently diverges from the training pipeline on the edge channels, which
  // then propagate through the global SNV and into the prediction.
  final out = Float64List(n);
  for (var i = 0; i < n; i++) {
    var sum = 0.0;
    if (i < half) {
      // Fit over the first `window` samples; evaluate at position i.
      final coeffs = _savgolCoeffsForOffset(
        windowLength: window,
        polyorder: polyorder,
        derivativeOrder: safeDerivative,
        offset: (i - half).toDouble(),
      );
      for (var j = 0; j < window; j++) {
        sum += coeffs[j] * spectrum.y[j];
      }
    } else if (i >= n - half) {
      // Fit over the last `window` samples; evaluate at position i.
      final start = n - window;
      final coeffs = _savgolCoeffsForOffset(
        windowLength: window,
        polyorder: polyorder,
        derivativeOrder: safeDerivative,
        offset: (i - start - half).toDouble(),
      );
      for (var j = 0; j < window; j++) {
        sum += coeffs[j] * spectrum.y[start + j];
      }
    } else {
      // Interior: centered convolution (offset 0), unchanged.
      for (var j = 0; j < window; j++) {
        sum += centerCoeffs[j] * spectrum.y[i - half + j];
      }
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
  if (spectrum.length == 0) {
    return spectrum;
  }
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
  if (x1 == x0) {
    return spectrum;
  }
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
    if (current.length < 3) {
      // A central difference needs both neighbors; too few points to apply.
      break;
    }
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

List<double> _savgolCoefficients({
  required int windowLength,
  required int polyorder,
  required int derivativeOrder,
}) {
  // Centered kernel (evaluate the fit at the window centre).
  return _savgolCoeffsForOffset(
    windowLength: windowLength,
    polyorder: polyorder,
    derivativeOrder: derivativeOrder,
    offset: 0.0,
  );
}

/// Savitzky-Golay convolution weights that evaluate the `derivativeOrder`-th
/// derivative of the least-squares polynomial fit at position `offset`,
/// measured from the window centre (offset 0 == centred kernel). Edge points
/// use a non-zero offset, reproducing scipy's mode='interp' boundary handling.
List<double> _savgolCoeffsForOffset({
  required int windowLength,
  required int polyorder,
  required int derivativeOrder,
  required double offset,
}) {
  final cacheKey = '$windowLength|$polyorder|$derivativeOrder|$offset';
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

  // Weight of the m-th polynomial term in the derivativeOrder-th derivative
  // evaluated at `offset`:  d^d/dk^d (k^m) |_{k=offset}
  //   = m!/(m-d)! * offset^(m-d)   for m >= d, else 0.
  final dWeights = List<double>.filled(cols, 0);
  for (var m = derivativeOrder; m < cols; m++) {
    var falling = 1.0;
    for (var s = 0; s < derivativeOrder; s++) {
      falling *= (m - s);
    }
    final exponent = m - derivativeOrder;
    final powTerm = exponent == 0 ? 1.0 : pow(offset, exponent).toDouble();
    dWeights[m] = falling * powTerm;
  }

  final coeff = List<double>.filled(rows, 0);
  for (var r = 0; r < rows; r++) {
    var value = 0.0;
    for (var m = 0; m < cols; m++) {
      final weight = dWeights[m];
      if (weight == 0) {
        continue;
      }
      var inner = 0.0;
      for (var l = 0; l < cols; l++) {
        inner += invAta[m][l] * a[r][l];
      }
      value += weight * inner;
    }
    coeff[r] = value;
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
