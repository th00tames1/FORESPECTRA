import 'dart:math';
import 'dart:typed_data';

import 'calibration_model.dart';
import 'preprocess.dart';
import 'spectrum.dart';

class AnalysisResult {
  /// Diagnostic-level string values returned by GH/NH classification.
  /// Kept as strings (not an enum) so JSON serialization stays stable.
  static const levelNormal = 'normal';
  static const levelWarning = 'warning';
  static const levelOutlier = 'outlier';

  AnalysisResult({
    required this.modelId,
    required this.modelName,
    required this.label,
    required this.displayValue,
    required this.units,
    this.numericValue,
    this.rawScore,
    this.gh,
    this.nh,
    this.ghLevel,
    this.nhLevel,
    this.ghLabel = 'GH',
    this.nhLabel = 'NH',
    this.ghDecimals = 3,
    this.nhDecimals = 3,
    this.fossGh,
    this.fossNh,
    this.fossQ,
    this.fossGhLevel,
    this.fossNhLevel,
    this.fossQLevel,
    this.fossGhLabel = 'GH',
    this.fossNhLabel = 'NH',
    this.fossQLabel = 'Q',
    this.fossGhDecimals = 3,
    this.fossNhDecimals = 3,
    this.fossQDecimals = 3,
  });

  final String modelId;
  final String modelName;
  final String label;
  final String displayValue;
  final String units;
  final double? numericValue;
  final double? rawScore;
  final double? gh;
  final double? nh;
  final String? ghLevel;
  final String? nhLevel;
  final String ghLabel;
  final String nhLabel;
  final int ghDecimals;
  final int nhDecimals;
  final double? fossGh;
  final double? fossNh;
  final double? fossQ;
  final String? fossGhLevel;
  final String? fossNhLevel;
  final String? fossQLevel;
  final String fossGhLabel;
  final String fossNhLabel;
  final String fossQLabel;
  final int fossGhDecimals;
  final int fossNhDecimals;
  final int fossQDecimals;

  String get summary => '$label: $displayValue';

  String? get ghDisplayValue =>
      gh == null ? null : _formatDecimal(gh!, ghDecimals);

  String? get nhDisplayValue =>
      nh == null ? null : _formatDecimal(nh!, nhDecimals);

  String? get fossGhDisplayValue =>
      fossGh == null ? null : _formatDecimal(fossGh!, fossGhDecimals);

  String? get fossNhDisplayValue =>
      fossNh == null ? null : _formatDecimal(fossNh!, fossNhDecimals);

  String? get fossQDisplayValue =>
      fossQ == null ? null : _formatDecimal(fossQ!, fossQDecimals);

  String get diagnosticsSummary {
    final parts = <String>[];
    final ghText = ghDisplayValue;
    if (ghText != null) {
      parts.add(_formatDiagnosticPart(ghLabel, ghText, ghLevel));
    }
    final nhText = nhDisplayValue;
    if (nhText != null) {
      parts.add(_formatDiagnosticPart(nhLabel, nhText, nhLevel));
    }
    return parts.join(', ');
  }

  String get fossDiagnosticsSummary {
    final parts = <String>[];
    final ghText = fossGhDisplayValue;
    if (ghText != null) {
      parts.add(_formatDiagnosticPart(fossGhLabel, ghText, fossGhLevel));
    }
    final nhText = fossNhDisplayValue;
    if (nhText != null) {
      parts.add(_formatDiagnosticPart(fossNhLabel, nhText, fossNhLevel));
    }
    final qText = fossQDisplayValue;
    if (qText != null) {
      parts.add(_formatDiagnosticPart(fossQLabel, qText, fossQLevel));
    }
    return parts.join(', ');
  }

  Map<String, dynamic> toJson() => {
    'modelId': modelId,
    'modelName': modelName,
    'value': numericValue ?? displayValue,
    'numericValue': numericValue,
    'displayValue': displayValue,
    'units': units,
    'label': label,
    'rawScore': rawScore,
    'gh': gh,
    'nh': nh,
    'ghLevel': ghLevel,
    'nhLevel': nhLevel,
    'ghLabel': ghLabel,
    'nhLabel': nhLabel,
    'ghDecimals': ghDecimals,
    'nhDecimals': nhDecimals,
    'ghDisplayValue': ghDisplayValue,
    'nhDisplayValue': nhDisplayValue,
    if (fossGh != null) 'fossGh': fossGh,
    if (fossNh != null) 'fossNh': fossNh,
    if (fossQ != null) 'fossQ': fossQ,
    if (fossGhLevel != null) 'fossGhLevel': fossGhLevel,
    if (fossNhLevel != null) 'fossNhLevel': fossNhLevel,
    if (fossQLevel != null) 'fossQLevel': fossQLevel,
    if (fossGh != null) 'fossGhLabel': fossGhLabel,
    if (fossNh != null) 'fossNhLabel': fossNhLabel,
    if (fossQ != null) 'fossQLabel': fossQLabel,
    if (fossGh != null) 'fossGhDecimals': fossGhDecimals,
    if (fossNh != null) 'fossNhDecimals': fossNhDecimals,
    if (fossQ != null) 'fossQDecimals': fossQDecimals,
    if (fossGhDisplayValue != null) 'fossGhDisplayValue': fossGhDisplayValue,
    if (fossNhDisplayValue != null) 'fossNhDisplayValue': fossNhDisplayValue,
    if (fossQDisplayValue != null) 'fossQDisplayValue': fossQDisplayValue,
  };

  String _formatDiagnosticPart(String label, String value, String? level) {
    if (level == null || level.isEmpty) {
      return '$label: $value';
    }
    return '$label: $value [$level]';
  }
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

  final ghNh = _computeFossGhNh(
    scaledSpectrum: processed,
    config: model.fossGhNhConfig,
  );

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
      gh: ghNh.gh,
      nh: ghNh.nh,
      ghLevel: ghNh.ghLevel,
      nhLevel: ghNh.nhLevel,
      ghLabel: ghNh.ghLabel,
      nhLabel: ghNh.nhLabel,
      ghDecimals: ghNh.ghDecimals,
      nhDecimals: ghNh.nhDecimals,
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
    gh: ghNh.gh,
    nh: ghNh.nh,
    ghLevel: ghNh.ghLevel,
    nhLevel: ghNh.nhLevel,
    ghLabel: ghNh.ghLabel,
    nhLabel: ghNh.nhLabel,
    ghDecimals: ghNh.ghDecimals,
    nhDecimals: ghNh.nhDecimals,
  );
}

class _FossGhNhValues {
  const _FossGhNhValues({
    this.gh,
    this.nh,
    this.q,
    this.ghLevel,
    this.nhLevel,
    this.qLevel,
    this.ghLabel = 'GH',
    this.nhLabel = 'NH',
    this.qLabel = 'Q',
    this.ghDecimals = 3,
    this.nhDecimals = 3,
    this.qDecimals = 3,
  });

  final double? gh;
  final double? nh;
  final double? q;
  final String? ghLevel;
  final String? nhLevel;
  final String? qLevel;
  final String ghLabel;
  final String nhLabel;
  final String qLabel;
  final int ghDecimals;
  final int nhDecimals;
  final int qDecimals;
}

_FossGhNhValues _computeFossGhNh({
  required Spectrum scaledSpectrum,
  required FossGhNhConfig? config,
}) {
  if (config == null || !config.isValid || !config.isPcaScoreSpace) {
    return const _FossGhNhValues();
  }

  final values = scaledSpectrum.y;
  final pca = config.pca;
  if (values.length < pca.featureLength) {
    return const _FossGhNhValues();
  }

  final centered = List<double>.filled(pca.featureLength, 0);
  for (var i = 0; i < pca.featureLength; i++) {
    centered[i] = values[i] - pca.mean[i];
  }

  final components = pca.components;
  if (components <= 0) {
    return const _FossGhNhValues();
  }

  final scores = List<double>.filled(components, 0);
  for (var c = 0; c < components; c++) {
    final loading = pca.loadings[c];
    var dot = 0.0;
    for (var i = 0; i < pca.featureLength; i++) {
      dot += centered[i] * loading[i];
    }
    scores[c] = dot;
  }

  double? gh;
  String? ghLevel;
  var ghLabel = 'GH';
  var ghDecimals = 3;
  final ghConfig = config.gh;
  if (ghConfig != null && ghConfig.enabled) {
    ghLabel = ghConfig.label;
    ghDecimals = ghConfig.decimals;
    var sum = 0.0;
    var valid = 0;
    for (var i = 0; i < components; i++) {
      final variance = pca.scoreVariance[i];
      final center = pca.scoreCenter[i];
      if (!variance.isFinite || variance <= 0 || !center.isFinite) {
        continue;
      }
      final delta = scores[i] - center;
      sum += (delta * delta) / variance;
      valid += 1;
    }
    if (valid > 0 && sum.isFinite && sum >= 0) {
      gh = sqrt(sum);
      ghLevel = _classifyGhWarningOutlierLevel(
        gh,
        warningMin: ghConfig.normalMax,
        outlierMin: ghConfig.warningMax,
      );
    }
  }

  double? nh;
  String? nhLevel;
  var nhLabel = 'NH';
  var nhDecimals = 3;
  final nhConfig = config.nh;
  if (nhConfig != null && nhConfig.enabled && nhConfig.isValid) {
    nhLabel = nhConfig.label;
    nhDecimals = nhConfig.decimals;
    final dimension = min(components, nhConfig.dimension);
    if (dimension > 0) {
      final distances = <double>[];
      for (final ref in nhConfig.referenceScores) {
        var sum = 0.0;
        var used = 0;
        for (var i = 0; i < dimension; i++) {
          final variance = pca.scoreVariance[i];
          if (!variance.isFinite || variance <= 0) {
            continue;
          }
          final delta = scores[i] - ref[i];
          sum += (delta * delta) / variance;
          used += 1;
        }
        if (used > 0 && sum.isFinite && sum >= 0) {
          distances.add(sqrt(sum));
        }
      }
      distances.sort();
      final k = nhConfig.safeKForCount(distances.length);
      if (k > 0 && distances.length >= k) {
        var sum = 0.0;
        for (var i = 0; i < k; i++) {
          sum += distances[i];
        }
        nh = sum / k;
        nhLevel = _classifyDiagnosticLevel(
          nh,
          normalMax: nhConfig.normalMax,
          warningMax: nhConfig.warningMax,
        );
      }
    }
  }

  double? q;
  String? qLevel;
  var qLabel = 'Q';
  var qDecimals = 3;
  final qConfig = config.q;
  if (qConfig != null && qConfig.enabled) {
    qLabel = qConfig.label;
    qDecimals = qConfig.decimals;
    var residual = 0.0;
    for (var i = 0; i < pca.featureLength; i++) {
      var reconstructed = pca.mean[i];
      for (var c = 0; c < components; c++) {
        reconstructed += scores[c] * pca.loadings[c][i];
      }
      final delta = values[i] - reconstructed;
      residual += delta * delta;
    }
    if (residual.isFinite && residual >= 0) {
      q = residual;
      qLevel = _classifyDiagnosticLevel(
        q,
        normalMax: qConfig.normalMax,
        warningMax: qConfig.warningMax,
      );
    }
  }

  return _FossGhNhValues(
    gh: gh,
    nh: nh,
    q: q,
    ghLevel: ghLevel,
    nhLevel: nhLevel,
    qLevel: qLevel,
    ghLabel: ghLabel,
    nhLabel: nhLabel,
    qLabel: qLabel,
    ghDecimals: ghDecimals,
    nhDecimals: nhDecimals,
    qDecimals: qDecimals,
  );
}

String? _classifyDiagnosticLevel(
  double? value, {
  double? normalMax,
  double? warningMax,
}) {
  if (value == null || !value.isFinite) {
    return null;
  }
  if (normalMax == null || !normalMax.isFinite || normalMax < 0) {
    return null;
  }
  if (value <= normalMax) {
    return AnalysisResult.levelNormal;
  }
  final safeWarning =
      (warningMax != null && warningMax.isFinite && warningMax >= normalMax)
      ? warningMax
      : null;
  if (safeWarning != null && value <= safeWarning) {
    return AnalysisResult.levelWarning;
  }
  return AnalysisResult.levelOutlier;
}

String? _classifyGhWarningOutlierLevel(
  double? value, {
  double? warningMin,
  double? outlierMin,
}) {
  if (value == null || !value.isFinite) {
    return null;
  }
  if (warningMin == null || !warningMin.isFinite || warningMin < 0) {
    return null;
  }
  final safeOutlier =
      (outlierMin != null && outlierMin.isFinite && outlierMin >= warningMin)
      ? outlierMin
      : null;
  if (safeOutlier != null && value > safeOutlier) {
    return AnalysisResult.levelOutlier;
  }
  if (value > warningMin) {
    return AnalysisResult.levelWarning;
  }
  return null;
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

String _formatDecimal(double value, int decimals) {
  final safeDecimals = decimals < 0 ? 0 : (decimals > 6 ? 6 : decimals);
  return value.toStringAsFixed(safeDecimals);
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
  final cleaned = spaced.replaceAll('?', '').trim();
  if (cleaned == 'Cherry Laurel') {
    return 'Laurel';
  }
  if (cleaned == 'Pacific Rhododendron') {
    return 'Rhododendron';
  }
  return cleaned;
}
