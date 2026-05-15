import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

class GhConfig {
  GhConfig({
    this.center,
    this.variance,
    this.centerVector = const <double>[],
    this.varianceVector = const <double>[],
    this.label = 'GH',
    this.decimals = 3,
    this.normalMax,
    this.warningMax,
  });

  final double? center;
  final double? variance;
  final List<double> centerVector;
  final List<double> varianceVector;
  final String label;
  final int decimals;
  final double? normalMax;
  final double? warningMax;

  bool get isScalarValid {
    final centerValue = center;
    final varianceValue = variance;
    return centerValue != null &&
        varianceValue != null &&
        centerValue.isFinite &&
        varianceValue.isFinite &&
        varianceValue > 0;
  }

  bool get isVectorValid {
    final length = safeVectorLength;
    if (length <= 0) {
      return false;
    }
    for (var i = 0; i < length; i++) {
      final centerValue = centerVector[i];
      final varianceValue = varianceVector[i];
      if (!centerValue.isFinite ||
          !varianceValue.isFinite ||
          varianceValue <= 0) {
        return false;
      }
    }
    return true;
  }

  bool get isValid => isScalarValid || isVectorValid;

  int get safeVectorLength {
    if (centerVector.isEmpty || varianceVector.isEmpty) {
      return 0;
    }
    return min(centerVector.length, varianceVector.length);
  }

  factory GhConfig.fromJsonMap(Map<String, dynamic> map) {
    final center = (map['center'] as num?)?.toDouble();
    final variance = (map['variance'] as num?)?.toDouble();
    final centerVectorRaw = _parseFiniteDoubleList(
      map['center_vector'] as List<dynamic>?,
    );
    final varianceVectorRaw = _parseFiniteDoubleList(
      map['variance_vector'] as List<dynamic>?,
    );
    final vectorLength = min(centerVectorRaw.length, varianceVectorRaw.length);
    final centerVector = vectorLength <= 0
        ? const <double>[]
        : centerVectorRaw.sublist(0, vectorLength);
    final varianceVector = vectorLength <= 0
        ? const <double>[]
        : varianceVectorRaw.sublist(0, vectorLength);

    final labelRaw = (map['label'] as String? ?? 'GH').trim();
    final decimalsRaw = (map['decimals'] as num?)?.toInt() ?? 3;
    final normalMaxRaw = (map['normal_max'] as num?)?.toDouble();
    final warningMaxRaw = (map['warning_max'] as num?)?.toDouble();
    final normalMax =
        (normalMaxRaw != null && normalMaxRaw.isFinite && normalMaxRaw >= 0)
        ? normalMaxRaw
        : null;
    var warningMax =
        (warningMaxRaw != null && warningMaxRaw.isFinite && warningMaxRaw >= 0)
        ? warningMaxRaw
        : null;
    if (normalMax != null && warningMax != null && warningMax < normalMax) {
      warningMax = normalMax;
    }

    final parsed = GhConfig(
      center: center,
      variance: variance,
      centerVector: centerVector,
      varianceVector: varianceVector,
      label: labelRaw.isEmpty ? 'GH' : labelRaw,
      decimals: decimalsRaw < 0 ? 0 : (decimalsRaw > 6 ? 6 : decimalsRaw),
      normalMax: normalMax,
      warningMax: warningMax,
    );
    if (!parsed.isValid) {
      throw const FormatException('Invalid GH config');
    }
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      if (isScalarValid) 'center': center,
      if (isScalarValid) 'variance': variance,
      if (isVectorValid) 'center_vector': centerVector,
      if (isVectorValid) 'variance_vector': varianceVector,
      'label': label,
      'decimals': decimals,
      if (normalMax != null) 'normal_max': normalMax,
      if (warningMax != null) 'warning_max': warningMax,
    };
  }
}

class NhConfig {
  NhConfig({
    this.referenceScores = const <double>[],
    this.referenceVectors = const <List<double>>[],
    this.k = 5,
    this.label = 'NH',
    this.decimals = 3,
    this.normalMax,
    this.warningMax,
  });

  final List<double> referenceScores;
  final List<List<double>> referenceVectors;
  final int k;
  final String label;
  final int decimals;
  final double? normalMax;
  final double? warningMax;

  bool get isScalarValid => referenceScores.isNotEmpty;

  bool get isVectorValid {
    if (referenceVectors.isEmpty) {
      return false;
    }
    for (final vector in referenceVectors) {
      if (vector.isEmpty) {
        return false;
      }
      for (final value in vector) {
        if (!value.isFinite) {
          return false;
        }
      }
    }
    return true;
  }

  bool get isValid => isScalarValid || isVectorValid;

  int get safeK {
    final scalarCount = referenceScores.length;
    final vectorCount = referenceVectors.length;
    final available = scalarCount > 0 ? scalarCount : vectorCount;
    return safeKForCount(available);
  }

  int safeKForCount(int availableCount) {
    if (availableCount <= 0) {
      return 0;
    }
    return min(max(1, k), availableCount);
  }

  factory NhConfig.fromJsonMap(Map<String, dynamic> map) {
    final parsed = _parseFiniteDoubleList(
      map['reference_scores'] as List<dynamic>?,
    );
    final parsedVectors = _parseFiniteDoubleMatrix(
      map['reference_vectors'] as List<dynamic>?,
    );

    final labelRaw = (map['label'] as String? ?? 'NH').trim();
    final kRaw = (map['k'] as num?)?.toInt() ?? 5;
    final decimalsRaw = (map['decimals'] as num?)?.toInt() ?? 3;
    final normalMaxRaw = (map['normal_max'] as num?)?.toDouble();
    final warningMaxRaw = (map['warning_max'] as num?)?.toDouble();
    final normalMax =
        (normalMaxRaw != null && normalMaxRaw.isFinite && normalMaxRaw >= 0)
        ? normalMaxRaw
        : null;
    var warningMax =
        (warningMaxRaw != null && warningMaxRaw.isFinite && warningMaxRaw >= 0)
        ? warningMaxRaw
        : null;
    if (normalMax != null && warningMax != null && warningMax < normalMax) {
      warningMax = normalMax;
    }
    final parsedConfig = NhConfig(
      referenceScores: parsed,
      referenceVectors: parsedVectors,
      k: kRaw,
      label: labelRaw.isEmpty ? 'NH' : labelRaw,
      decimals: decimalsRaw < 0 ? 0 : (decimalsRaw > 6 ? 6 : decimalsRaw),
      normalMax: normalMax,
      warningMax: warningMax,
    );
    if (!parsedConfig.isValid) {
      throw const FormatException('Invalid NH config');
    }
    return parsedConfig;
  }

  Map<String, dynamic> toJson() {
    return {
      if (isScalarValid) 'reference_scores': referenceScores,
      if (isVectorValid) 'reference_vectors': referenceVectors,
      'k': k,
      'label': label,
      'decimals': decimals,
      if (normalMax != null) 'normal_max': normalMax,
      if (warningMax != null) 'warning_max': warningMax,
    };
  }
}

class GhNhConfig {
  GhNhConfig({required this.enabled, required this.space, this.gh, this.nh});

  final bool enabled;
  final String space;
  final GhConfig? gh;
  final NhConfig? nh;

  bool get isPredictionScoreSpace =>
      space.isEmpty || space == 'prediction_score';

  bool get isValid {
    if (!enabled || !isPredictionScoreSpace) {
      return false;
    }
    final hasGh =
        gh != null &&
        (isPredictionScoreSpace ? gh!.isScalarValid : gh!.isVectorValid);
    final hasNh =
        nh != null &&
        (isPredictionScoreSpace ? nh!.isScalarValid : nh!.isVectorValid);
    return hasGh || hasNh;
  }

  factory GhNhConfig.fromJsonMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw const FormatException('Empty GH/NH config');
    }

    final enabled = map['enabled'] != false;
    final spaceRaw = (map['space'] as String? ?? 'prediction_score')
        .trim()
        .toLowerCase();
    final space = spaceRaw.isEmpty ? 'prediction_score' : spaceRaw;

    GhConfig? gh;
    final ghRaw = map['gh'];
    if (ghRaw is Map) {
      try {
        gh = GhConfig.fromJsonMap(Map<String, dynamic>.from(ghRaw));
      } catch (_) {
        gh = null;
      }
    }

    NhConfig? nh;
    final nhRaw = map['nh'];
    if (nhRaw is Map) {
      try {
        nh = NhConfig.fromJsonMap(Map<String, dynamic>.from(nhRaw));
      } catch (_) {
        nh = null;
      }
    }

    return GhNhConfig(enabled: enabled, space: space, gh: gh, nh: nh);
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'space': space,
      if (gh != null) 'gh': gh!.toJson(),
      if (nh != null) 'nh': nh!.toJson(),
    };
  }
}

class FossMetricConfig {
  FossMetricConfig({
    required this.enabled,
    required this.label,
    required this.decimals,
    this.normalMax,
    this.warningMax,
  });

  final bool enabled;
  final String label;
  final int decimals;
  final double? normalMax;
  final double? warningMax;

  bool get hasThreshold =>
      normalMax != null && normalMax!.isFinite && normalMax! >= 0;

  factory FossMetricConfig.fromJsonMap(
    Map<String, dynamic> map, {
    required String fallbackLabel,
  }) {
    final enabled = map['enabled'] != false;
    final labelRaw = (map['label'] as String? ?? fallbackLabel).trim();
    final decimalsRaw = (map['decimals'] as num?)?.toInt() ?? 3;
    final normalMaxRaw = (map['normal_max'] as num?)?.toDouble();
    final warningMaxRaw = (map['warning_max'] as num?)?.toDouble();
    final normalMax =
        (normalMaxRaw != null && normalMaxRaw.isFinite && normalMaxRaw >= 0)
        ? normalMaxRaw
        : null;
    var warningMax =
        (warningMaxRaw != null && warningMaxRaw.isFinite && warningMaxRaw >= 0)
        ? warningMaxRaw
        : null;
    if (normalMax != null && warningMax != null && warningMax < normalMax) {
      warningMax = normalMax;
    }
    return FossMetricConfig(
      enabled: enabled,
      label: labelRaw.isEmpty ? fallbackLabel : labelRaw,
      decimals: decimalsRaw < 0 ? 0 : (decimalsRaw > 6 ? 6 : decimalsRaw),
      normalMax: normalMax,
      warningMax: warningMax,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'label': label,
      'decimals': decimals,
      if (normalMax != null) 'normal_max': normalMax,
      if (warningMax != null) 'warning_max': warningMax,
    };
  }
}

class FossPcaConfig {
  FossPcaConfig({
    required this.mean,
    required this.loadings,
    required this.scoreCenter,
    required this.scoreVariance,
  });

  final List<double> mean;
  final List<List<double>> loadings;
  final List<double> scoreCenter;
  final List<double> scoreVariance;

  int get featureLength => mean.length;

  int get components {
    final available = min(
      loadings.length,
      min(scoreCenter.length, scoreVariance.length),
    );
    return available < 0 ? 0 : available;
  }

  bool get isValid {
    if (mean.isEmpty || loadings.isEmpty) {
      return false;
    }
    if (components <= 0) {
      return false;
    }
    for (var i = 0; i < components; i++) {
      final loading = loadings[i];
      if (loading.length != featureLength) {
        return false;
      }
      final variance = scoreVariance[i];
      final center = scoreCenter[i];
      if (!variance.isFinite || variance <= 0 || !center.isFinite) {
        return false;
      }
      for (final value in loading) {
        if (!value.isFinite) {
          return false;
        }
      }
    }
    for (final value in mean) {
      if (!value.isFinite) {
        return false;
      }
    }
    return true;
  }

  factory FossPcaConfig.fromJsonMap(Map<String, dynamic> map) {
    final mean = _parseFiniteDoubleList(map['mean'] as List<dynamic>?);
    final loadings = _parseFiniteDoubleMatrix(
      map['loadings'] as List<dynamic>?,
    );
    final scoreCenter = _parseFiniteDoubleList(
      map['score_center'] as List<dynamic>?,
    );
    final scoreVariance = _parseFiniteDoubleList(
      map['score_variance'] as List<dynamic>?,
    );

    final parsed = FossPcaConfig(
      mean: mean,
      loadings: loadings,
      scoreCenter: scoreCenter,
      scoreVariance: scoreVariance,
    );
    if (!parsed.isValid) {
      throw const FormatException('Invalid PCA diagnostics config');
    }
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      'mean': mean,
      'loadings': loadings,
      'score_center': scoreCenter,
      'score_variance': scoreVariance,
    };
  }
}

class FossNhConfig {
  FossNhConfig({
    required this.enabled,
    required this.referenceScores,
    this.k = 5,
    this.label = 'NH',
    this.decimals = 3,
    this.normalMax,
    this.warningMax,
  });

  final bool enabled;
  final List<List<double>> referenceScores;
  final int k;
  final String label;
  final int decimals;
  final double? normalMax;
  final double? warningMax;

  int get dimension =>
      referenceScores.isEmpty ? 0 : referenceScores.first.length;

  bool get isValid {
    if (referenceScores.isEmpty) {
      return false;
    }
    final size = dimension;
    if (size <= 0) {
      return false;
    }
    for (final row in referenceScores) {
      if (row.length != size) {
        return false;
      }
      for (final value in row) {
        if (!value.isFinite) {
          return false;
        }
      }
    }
    return true;
  }

  int safeKForCount(int availableCount) {
    if (availableCount <= 0) {
      return 0;
    }
    return min(max(1, k), availableCount);
  }

  factory FossNhConfig.fromJsonMap(Map<String, dynamic> map) {
    final enabled = map['enabled'] != false;
    final referenceScores = _parseFiniteDoubleMatrix(
      map['reference_scores'] as List<dynamic>?,
    );
    final kRaw = (map['k'] as num?)?.toInt() ?? 5;
    final labelRaw = (map['label'] as String? ?? 'NH').trim();
    final decimalsRaw = (map['decimals'] as num?)?.toInt() ?? 3;
    final normalMaxRaw = (map['normal_max'] as num?)?.toDouble();
    final warningMaxRaw = (map['warning_max'] as num?)?.toDouble();
    final normalMax =
        (normalMaxRaw != null && normalMaxRaw.isFinite && normalMaxRaw >= 0)
        ? normalMaxRaw
        : null;
    var warningMax =
        (warningMaxRaw != null && warningMaxRaw.isFinite && warningMaxRaw >= 0)
        ? warningMaxRaw
        : null;
    if (normalMax != null && warningMax != null && warningMax < normalMax) {
      warningMax = normalMax;
    }

    final parsed = FossNhConfig(
      enabled: enabled,
      referenceScores: referenceScores,
      k: kRaw,
      label: labelRaw.isEmpty ? 'NH' : labelRaw,
      decimals: decimalsRaw < 0 ? 0 : (decimalsRaw > 6 ? 6 : decimalsRaw),
      normalMax: normalMax,
      warningMax: warningMax,
    );
    if (!parsed.isValid) {
      throw const FormatException('Invalid NH diagnostics config');
    }
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'reference_scores': referenceScores,
      'k': k,
      'label': label,
      'decimals': decimals,
      if (normalMax != null) 'normal_max': normalMax,
      if (warningMax != null) 'warning_max': warningMax,
    };
  }
}

class FossGhNhConfig {
  FossGhNhConfig({
    required this.enabled,
    required this.space,
    required this.pca,
    this.gh,
    this.nh,
    this.q,
  });

  final bool enabled;
  final String space;
  final FossPcaConfig pca;
  final FossMetricConfig? gh;
  final FossNhConfig? nh;
  final FossMetricConfig? q;

  bool get isPcaScoreSpace => space.isEmpty || space == 'pca_score';

  bool get isValid {
    if (!enabled || !isPcaScoreSpace || !pca.isValid) {
      return false;
    }
    final hasGh = gh != null && gh!.enabled;
    final hasNh = nh != null && nh!.enabled && nh!.isValid;
    final hasQ = q != null && q!.enabled;
    return hasGh || hasNh || hasQ;
  }

  factory FossGhNhConfig.fromJsonMap(Map<String, dynamic> map) {
    final enabled = map['enabled'] != false;
    final spaceRaw = (map['space'] as String? ?? 'pca_score')
        .trim()
        .toLowerCase();
    final space = spaceRaw.isEmpty ? 'pca_score' : spaceRaw;

    final pcaRaw = map['pca'];
    if (pcaRaw is! Map) {
      throw const FormatException('Missing PCA diagnostics config');
    }
    final pca = FossPcaConfig.fromJsonMap(Map<String, dynamic>.from(pcaRaw));

    FossMetricConfig? gh;
    final ghRaw = map['gh'];
    if (ghRaw is Map) {
      gh = FossMetricConfig.fromJsonMap(
        Map<String, dynamic>.from(ghRaw),
        fallbackLabel: 'GH',
      );
    }

    FossNhConfig? nh;
    final nhRaw = map['nh'];
    if (nhRaw is Map) {
      nh = FossNhConfig.fromJsonMap(Map<String, dynamic>.from(nhRaw));
    }

    FossMetricConfig? q;
    final qRaw = map['q'];
    if (qRaw is Map) {
      q = FossMetricConfig.fromJsonMap(
        Map<String, dynamic>.from(qRaw),
        fallbackLabel: 'Q',
      );
    }

    final parsed = FossGhNhConfig(
      enabled: enabled,
      space: space,
      pca: pca,
      gh: gh,
      nh: nh,
      q: q,
    );
    if (!parsed.isValid) {
      throw const FormatException('Invalid GH/NH diagnostics config');
    }
    return parsed;
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'space': space,
      'pca': pca.toJson(),
      if (gh != null) 'gh': gh!.toJson(),
      if (nh != null) 'nh': nh!.toJson(),
      if (q != null) 'q': q!.toJson(),
    };
  }
}

List<double> _parseFiniteDoubleList(List<dynamic>? raw) {
  if (raw == null) {
    return const <double>[];
  }
  final parsed = <double>[];
  for (final value in raw) {
    if (value is num) {
      final cast = value.toDouble();
      if (cast.isFinite) {
        parsed.add(cast);
      }
    }
  }
  return parsed;
}

List<List<double>> _parseFiniteDoubleMatrix(List<dynamic>? raw) {
  if (raw == null) {
    return const <List<double>>[];
  }
  final parsed = <List<double>>[];
  for (final row in raw) {
    if (row is! List) {
      continue;
    }
    final values = _parseFiniteDoubleList(List<dynamic>.from(row));
    if (values.isNotEmpty) {
      parsed.add(values);
    }
  }
  return parsed;
}

/// Compact node-array decision tree (regression). Each entry index `i`
/// describes one node. Leaf nodes have `feature[i] == -1`.
class DecisionTreeNodes {
  DecisionTreeNodes({
    required this.feature,
    required this.threshold,
    required this.value,
    required this.left,
    required this.right,
  });

  final Int32List feature;
  final Float64List threshold;
  final Float64List value;
  final Int32List left;
  final Int32List right;

  /// Traverse from root (idx 0) using a standardized spectrum `x`.
  double predict(Float64List x) {
    var idx = 0;
    final maxFeat = x.length;
    while (true) {
      final f = feature[idx];
      if (f < 0) {
        return value[idx];
      }
      final xv = f < maxFeat ? x[f] : 0.0;
      idx = xv <= threshold[idx] ? left[idx] : right[idx];
    }
  }

  static DecisionTreeNodes fromJsonMap(Map<String, dynamic> map) {
    Int32List intList(String key) {
      final raw = (map[key] as List<dynamic>?) ?? const [];
      return Int32List.fromList(raw.map((e) => (e as num).toInt()).toList());
    }
    Float64List doubleList(String key) {
      final raw = (map[key] as List<dynamic>?) ?? const [];
      return Float64List.fromList(
        raw.map((e) => (e as num).toDouble()).toList(),
      );
    }
    return DecisionTreeNodes(
      feature: intList('feature'),
      threshold: doubleList('threshold'),
      value: doubleList('value'),
      left: intList('left'),
      right: intList('right'),
    );
  }
}

class CalibrationModel {
  CalibrationModel({
    required this.id,
    required this.name,
    required this.coefficients,
    required this.intercept,
    required this.units,
    required this.label,
    required this.expectedLength,
    required this.preprocessSteps,
    required this.xAxis,
    required this.modelType,
    this.scalerMean,
    this.scalerScale,
    this.threshold,
    this.positiveClassIndex,
    this.classes = const [],
    this.axisUnit = '',
    this.ghNhConfig,
    this.fossGhNhConfig,
    this.coefficientsByClass = const [],
    this.interceptsByClass = const [],
    this.trees = const [],
    this.initialValue = 0.0,
    this.treeWeight = 1.0,
  });

  final String id;
  final String name;
  final Float64List coefficients;
  final double intercept;
  final String units;
  final String label;
  final int expectedLength;
  final List<Map<String, dynamic>> preprocessSteps;
  final List<double> xAxis;
  final String modelType;
  final Float64List? scalerMean;
  final Float64List? scalerScale;
  final double? threshold;
  final int? positiveClassIndex;
  final List<String> classes;
  final String axisUnit;
  final GhNhConfig? ghNhConfig;
  final FossGhNhConfig? fossGhNhConfig;
  // Multi-class PLS-DA: per-class linear head. Each entry is a coefficient
  // vector (same length as `coefficients`); paired intercepts in
  // [interceptsByClass]. Argmax over the per-class scores picks the class.
  final List<Float64List> coefficientsByClass;
  final List<double> interceptsByClass;
  // Tree-ensemble regression (RF / GBM): each tree stored as parallel
  // arrays; aggregation is `initialValue + treeWeight * Σ tree.predict(x)`.
  final List<DecisionTreeNodes> trees;
  final double initialValue;
  final double treeWeight;

  bool get isClassification =>
      modelType == 'pls_da_binary' || modelType == 'pls_da_multi';
  bool get isMultiClass => modelType == 'pls_da_multi';
  bool get isTreeEnsemble => modelType == 'tree_ensemble_regression';

  bool get hasStandardScaler =>
      scalerMean != null &&
      scalerScale != null &&
      scalerMean!.length == scalerScale!.length;

  factory CalibrationModel.fromJson(String jsonText) {
    final jsonMap = jsonDecode(jsonText) as Map<String, dynamic>;
    final hasScaler = jsonMap.containsKey('scaler');
    final hasHead =
        jsonMap.containsKey('linear_head') ||
        jsonMap.containsKey('linear_heads') ||
        jsonMap.containsKey('trees');
    if (hasHead && hasScaler) {
      return CalibrationModel._fromDeployJson(jsonMap);
    }
    return CalibrationModel._fromLegacyJson(jsonMap);
  }

  factory CalibrationModel._fromLegacyJson(Map<String, dynamic> jsonMap) {
    final coeffs = (jsonMap['coefficients'] as List<dynamic>)
        .map((e) => (e as num).toDouble())
        .toList();
    return CalibrationModel(
      id: jsonMap['id'] as String,
      name: jsonMap['name'] as String,
      coefficients: Float64List.fromList(coeffs),
      intercept: (jsonMap['intercept'] as num).toDouble(),
      units: jsonMap['units'] as String? ?? '',
      label: jsonMap['label'] as String? ?? 'Result',
      expectedLength: jsonMap['expectedLength'] as int? ?? coeffs.length,
      preprocessSteps: (jsonMap['preprocess'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      xAxis:
          (jsonMap['xAxis'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
      modelType: 'legacy_linear',
      scalerMean: null,
      scalerScale: null,
      threshold: null,
      positiveClassIndex: null,
      classes: const [],
      axisUnit: '',
      ghNhConfig: null,
      fossGhNhConfig: null,
    );
  }

  factory CalibrationModel._fromDeployJson(Map<String, dynamic> jsonMap) {
    final linearHead = Map<String, dynamic>.from(
      (jsonMap['linear_head'] as Map?) ?? const <String, dynamic>{},
    );
    final scaler = Map<String, dynamic>.from(
      (jsonMap['scaler'] as Map?) ?? const <String, dynamic>{},
    );
    final preprocess = Map<String, dynamic>.from(
      (jsonMap['preprocessing'] as Map?) ?? const <String, dynamic>{},
    );

    // Tree-ensemble regression: parse the per-tree node arrays.
    final treesRaw = (jsonMap['trees'] as List<dynamic>?) ?? const [];
    final trees = <DecisionTreeNodes>[
      for (final t in treesRaw)
        if (t is Map) DecisionTreeNodes.fromJsonMap(Map<String, dynamic>.from(t)),
    ];
    final initialValue =
        (jsonMap['initial_value'] as num?)?.toDouble() ?? 0.0;
    final treeWeight = (jsonMap['tree_weight'] as num?)?.toDouble() ?? 1.0;

    final headsRaw = (jsonMap['linear_heads'] as List<dynamic>?) ?? const [];
    final coefficientsByClass = <Float64List>[];
    final interceptsByClass = <double>[];
    for (final h in headsRaw) {
      if (h is Map) {
        final cMap = Map<String, dynamic>.from(h);
        final coef = _asDoubleList(cMap['coef'] as List<dynamic>?);
        coefficientsByClass.add(Float64List.fromList(coef));
        interceptsByClass.add((cMap['intercept'] as num?)?.toDouble() ?? 0);
      }
    }
    // Fall back to the binary linear_head if linear_heads is absent.
    // For tree ensembles `coefficients` is empty — analyzer routes by type.
    final coeffs = coefficientsByClass.isNotEmpty
        ? coefficientsByClass.first.toList()
        : _asDoubleList(linearHead['coef'] as List<dynamic>?);
    final xAxis = _asDoubleList(jsonMap['wavenumbers'] as List<dynamic>?);
    final scalerMean = _asDoubleList(scaler['mean'] as List<dynamic>?);
    final scalerScale = _asDoubleList(scaler['scale'] as List<dynamic>?);

    final modelType = (jsonMap['model_type'] as String? ?? 'linear').trim();
    final target = (jsonMap['target'] as String?)?.trim();
    final rawLabel = (jsonMap['label'] as String?)?.trim();
    final axisUnit =
        (jsonMap['axis_unit'] as String? ??
                jsonMap['x_axis_unit'] as String? ??
                '')
            .trim();

    GhNhConfig? ghNhConfig;
    final ghNhRaw = Map<String, dynamic>.from(
      (jsonMap['gh_nh'] as Map?) ?? const <String, dynamic>{},
    );
    if (ghNhRaw.isNotEmpty) {
      final hasPcaConfig = ghNhRaw['pca'] is Map;
      if (!hasPcaConfig) {
        try {
          final parsed = GhNhConfig.fromJsonMap(ghNhRaw);
          if (parsed.isValid) {
            ghNhConfig = parsed;
          }
        } catch (_) {
          ghNhConfig = null;
        }
      }
    }

    FossGhNhConfig? fossGhNhConfig;
    final ghNhHasPca = ghNhRaw['pca'] is Map;
    if (ghNhHasPca) {
      try {
        final parsed = FossGhNhConfig.fromJsonMap(ghNhRaw);
        if (parsed.isValid) {
          fossGhNhConfig = parsed;
        }
      } catch (_) {
        fossGhNhConfig = null;
      }
    }

    if (fossGhNhConfig == null) {
      final fossGhNhRaw = Map<String, dynamic>.from(
        (jsonMap['foss_gh_nh'] as Map?) ?? const <String, dynamic>{},
      );
      if (fossGhNhRaw.isNotEmpty) {
        try {
          final parsed = FossGhNhConfig.fromJsonMap(fossGhNhRaw);
          if (parsed.isValid) {
            fossGhNhConfig = parsed;
          }
        } catch (_) {
          fossGhNhConfig = null;
        }
      }
    }

    final label = rawLabel != null && rawLabel.isNotEmpty
        ? rawLabel
        : modelType == 'pls_da_binary'
        ? 'Species'
        : (target != null && target.isNotEmpty ? target : 'Result');

    final unitsRaw = (jsonMap['units'] as String? ?? '').trim();
    final units = unitsRaw.isNotEmpty
        ? unitsRaw
        : (target != null && target.toLowerCase().contains('moisture')
              ? '%'
              : '');

    final modelName = ((jsonMap['name'] as String?) ?? '').trim();
    final preprocName = (preprocess['name'] as String? ?? '').trim();
    final fallbackName = modelType == 'pls_da_binary'
        ? '$label model'
        : '$label regression model';
    final name = modelName.isNotEmpty ? modelName : fallbackName;

    final generatedId = _safeId(
      [
        modelType,
        target ?? '',
        jsonMap['positive_class_label']?.toString() ?? '',
        preprocName,
      ].join('_'),
    );
    final explicitId = (jsonMap['id'] as String?)?.trim();
    final id = explicitId != null && explicitId.isNotEmpty
        ? explicitId
        : generatedId;

    final preprocessSteps = <Map<String, dynamic>>[];
    final useSg = preprocess['use_sg'] == true;
    final useSnv = preprocess['use_snv'] == true;
    if (useSg) {
      preprocessSteps.add({
        'type': 'savitzky_golay',
        'window': (preprocess['sg_window_length'] as num?)?.toInt() ?? 11,
        'polyorder': (preprocess['sg_polyorder'] as num?)?.toInt() ?? 2,
        'derivative': (preprocess['sg_derivative'] as num?)?.toInt() ?? 0,
      });
    }
    if (useSnv) {
      preprocessSteps.add({'type': 'snv'});
    }

    final classes = (jsonMap['classes'] as List<dynamic>? ?? const <dynamic>[])
        .map((e) => e.toString())
        .toList(growable: false);

    final expectedLength = coeffs.isNotEmpty
        ? coeffs.length
        : (scalerMean.isNotEmpty ? scalerMean.length : xAxis.length);

    return CalibrationModel(
      id: id,
      name: name,
      coefficients: Float64List.fromList(coeffs),
      intercept: coefficientsByClass.isNotEmpty
          ? interceptsByClass.first
          : (linearHead['intercept'] as num?)?.toDouble() ?? 0,
      units: units,
      label: label,
      expectedLength: expectedLength,
      preprocessSteps: preprocessSteps,
      xAxis: xAxis,
      modelType: modelType,
      scalerMean: scalerMean.isEmpty ? null : Float64List.fromList(scalerMean),
      scalerScale: scalerScale.isEmpty
          ? null
          : Float64List.fromList(scalerScale),
      threshold: (jsonMap['threshold'] as num?)?.toDouble(),
      positiveClassIndex: (jsonMap['positive_class_index'] as num?)?.toInt(),
      classes: classes,
      axisUnit: axisUnit,
      ghNhConfig: ghNhConfig,
      fossGhNhConfig: fossGhNhConfig,
      coefficientsByClass: coefficientsByClass,
      interceptsByClass: interceptsByClass,
      trees: trees,
      initialValue: initialValue,
      treeWeight: treeWeight,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'coefficients': coefficients.toList(),
      'intercept': intercept,
      'units': units,
      'label': label,
      'expectedLength': expectedLength,
      'preprocess': preprocessSteps,
      'xAxis': xAxis,
      'modelType': modelType,
      'scalerMean': scalerMean?.toList(),
      'scalerScale': scalerScale?.toList(),
      'threshold': threshold,
      'positiveClassIndex': positiveClassIndex,
      'classes': classes,
      'axisUnit': axisUnit,
      if (fossGhNhConfig != null) 'gh_nh': fossGhNhConfig!.toJson(),
      if (fossGhNhConfig == null && ghNhConfig != null)
        'gh_nh': ghNhConfig!.toJson(),
    };
  }

  static List<double> _asDoubleList(List<dynamic>? raw) {
    if (raw == null) {
      return const <double>[];
    }
    return raw.map((e) => (e as num).toDouble()).toList(growable: false);
  }

  static String _safeId(String raw) {
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (normalized.isEmpty) {
      return 'model_default';
    }
    return normalized;
  }
}
