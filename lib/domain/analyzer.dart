import 'dart:math';
import 'dart:typed_data';

import 'calibration_model.dart';
import 'preprocess.dart';
import 'spectrum.dart';

class AnalysisResult {
  AnalysisResult({
    required this.modelId,
    required this.modelName,
    required this.label,
    required this.displayValue,
    required this.units,
    this.numericValue,
    this.rawScore,
  });

  final String modelId;
  final String modelName;
  final String label;
  final String displayValue;
  final String units;
  final double? numericValue;
  final double? rawScore;

  String get summary => '$label: $displayValue';

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'modelName': modelName,
    'value': numericValue ?? displayValue,
    'numericValue': numericValue,
    'displayValue': displayValue,
    'units': units,
    'label': label,
    'rawScore': rawScore,
  };
}

AnalysisResult runAnalysis(Spectrum spectrum, CalibrationModel model) {
  var processed = _alignSpectrumAxisForModel(spectrum, model);
  if (model.xAxis.isNotEmpty && model.xAxis.length == model.expectedLength) {
    processed = resampleSpectrum(processed, model.xAxis);
  }
  if (model.preprocessSteps.isNotEmpty) {
    processed = applyPreprocessing(processed, model.preprocessSteps);
  }
  if (model.hasStandardScaler) {
    processed = applyStandardScaling(
      processed,
      model.scalerMean!,
      model.scalerScale!,
    );
  }

  final length = min(processed.y.length, model.coefficients.length);
  var score = model.intercept;
  for (var i = 0; i < length; i++) {
    score += processed.y[i] * model.coefficients[i];
  }

  if (model.isClassification) {
    final threshold = model.threshold ?? 0.5;
    final positiveIndex = model.positiveClassIndex ?? 1;
    final classes = model.classes;

    String predictedLabel;
    if (classes.isEmpty) {
      predictedLabel = score >= threshold ? 'Positive' : 'Negative';
    } else {
      final fallbackNegative = positiveIndex == 0 ? 1 : 0;
      final candidate = score >= threshold ? positiveIndex : fallbackNegative;
      final safeIndex = candidate < 0
          ? 0
          : (candidate >= classes.length ? classes.length - 1 : candidate);
      predictedLabel = _humanizeClassLabel(classes[safeIndex]);
    }

    return AnalysisResult(
      modelId: model.id,
      modelName: model.name,
      label: model.label,
      displayValue: predictedLabel,
      units: '',
      numericValue: null,
      rawScore: score,
    );
  }

  return AnalysisResult(
    modelId: model.id,
    modelName: model.name,
    label: model.label,
    displayValue: _formatNumeric(score, model.units),
    units: model.units,
    numericValue: score,
    rawScore: score,
  );
}

Spectrum resampleSpectrum(Spectrum spectrum, List<double> targetX) {
  final source = _sortSpectrumByX(spectrum);
  final newY = List<double>.filled(targetX.length, 0);
  for (var i = 0; i < targetX.length; i++) {
    newY[i] = interpolate(source.x, source.y, targetX[i]);
  }
  return Spectrum(
    x: Float64List.fromList(targetX),
    y: Float64List.fromList(newY),
  );
}

Spectrum _alignSpectrumAxisForModel(Spectrum spectrum, CalibrationModel model) {
  final sorted = _sortSpectrumByX(spectrum);
  if (model.xAxis.isEmpty || sorted.length < 2) {
    return sorted;
  }

  final sourceMin = sorted.x.first;
  final sourceMax = sorted.x.last;
  final targetMin = model.xAxis.reduce(min);
  final targetMax = model.xAxis.reduce(max);
  final sourceMid = (sourceMin + sourceMax) / 2.0;
  final targetMid = (targetMin + targetMax) / 2.0;

  final axisUnit = model.axisUnit.toLowerCase();
  final targetLooksNm = targetMax < 3000;
  final shouldConvertCmInvToNm =
      axisUnit == 'nm' ||
      axisUnit == 'nanometer' ||
      axisUnit == 'nanometers' ||
      (axisUnit.isEmpty &&
          targetLooksNm &&
          sourceMid > 3000 &&
          targetMid < 3000);

  if (!shouldConvertCmInvToNm) {
    return sorted;
  }

  final convertedX = Float64List(sorted.length);
  for (var i = 0; i < sorted.length; i++) {
    final x = sorted.x[i];
    if (!x.isFinite || x <= 0) {
      return sorted;
    }
    convertedX[i] = 10000000.0 / x;
  }

  return _sortSpectrumByX(Spectrum(x: convertedX, y: sorted.y));
}

Spectrum applyStandardScaling(
  Spectrum spectrum,
  Float64List mean,
  Float64List scale,
) {
  final length = min(spectrum.y.length, min(mean.length, scale.length));
  final y = Float64List(length);
  final x = Float64List(length);
  for (var i = 0; i < length; i++) {
    final denominator = scale[i] == 0 ? 1.0 : scale[i];
    y[i] = (spectrum.y[i] - mean[i]) / denominator;
    x[i] = spectrum.x[i];
  }
  return Spectrum(x: x, y: y);
}

double interpolate(List<double> xs, List<double> ys, double x) {
  if (xs.isEmpty || ys.isEmpty) {
    return 0;
  }
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

Spectrum _sortSpectrumByX(Spectrum spectrum) {
  if (spectrum.length < 2) {
    return spectrum;
  }
  var ascending = true;
  for (var i = 1; i < spectrum.length; i++) {
    if (spectrum.x[i] < spectrum.x[i - 1]) {
      ascending = false;
      break;
    }
  }
  if (ascending) {
    return spectrum;
  }

  final pairs = List<List<double>>.generate(
    spectrum.length,
    (i) => <double>[spectrum.x[i], spectrum.y[i]],
  );
  pairs.sort((a, b) => a[0].compareTo(b[0]));

  return Spectrum(
    x: Float64List.fromList(pairs.map((e) => e[0]).toList(growable: false)),
    y: Float64List.fromList(pairs.map((e) => e[1]).toList(growable: false)),
  );
}

String _formatNumeric(double value, String units) {
  final raw = value.toStringAsFixed(2);
  if (units.isEmpty) {
    return raw;
  }
  if (units == '%') {
    return '$raw%';
  }
  return '$raw $units';
}

String _humanizeClassLabel(String raw) {
  final normalized = raw.replaceAll('_', ' ').trim();
  if (normalized.isEmpty) {
    return raw;
  }
  final spaced = normalized
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return spaced;
}
