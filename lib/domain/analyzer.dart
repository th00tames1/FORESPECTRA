import 'dart:math';
import 'dart:typed_data';

import 'calibration_model.dart';
import 'preprocess.dart';
import 'spectrum.dart';

class AnalysisResult {
  AnalysisResult({
    required this.value,
    required this.units,
    required this.label,
  });

  final double value;
  final String units;
  final String label;

  Map<String, dynamic> toJson() => {
        'value': value,
        'units': units,
        'label': label,
      };
}

AnalysisResult runAnalysis(Spectrum spectrum, CalibrationModel model) {
  var processed = spectrum;
  if (model.preprocessSteps.isNotEmpty) {
    processed = applyPreprocessing(processed, model.preprocessSteps);
  }
  if (model.xAxis.isNotEmpty && model.xAxis.length == model.expectedLength) {
    processed = resampleSpectrum(processed, model.xAxis);
  }
  final length = min(processed.y.length, model.coefficients.length);
  var score = model.intercept;
  for (var i = 0; i < length; i++) {
    score += processed.y[i] * model.coefficients[i];
  }
  return AnalysisResult(value: score, units: model.units, label: model.label);
}

Spectrum resampleSpectrum(Spectrum spectrum, List<double> targetX) {
  final newY = List<double>.filled(targetX.length, 0);
  for (var i = 0; i < targetX.length; i++) {
    newY[i] = interpolate(spectrum.x, spectrum.y, targetX[i]);
  }
  return Spectrum(
    x: Float64List.fromList(targetX),
    y: Float64List.fromList(newY),
  );
}

double interpolate(List<double> xs, List<double> ys, double x) {
  if (x <= xs.first) {
    return ys.first;
  }
  if (x >= xs.last) {
    return ys.last;
  }
  for (var i = 0; i < xs.length - 1; i++) {
    if (x >= xs[i] && x <= xs[i + 1]) {
      final t = (x - xs[i]) / (xs[i + 1] - xs[i]);
      return ys[i] + t * (ys[i + 1] - ys[i]);
    }
  }
  return ys.last;
}
