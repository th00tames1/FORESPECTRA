import 'dart:convert';
import 'dart:typed_data';

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

  bool get isClassification => modelType == 'pls_da_binary';

  bool get hasStandardScaler =>
      scalerMean != null &&
      scalerScale != null &&
      scalerMean!.length == scalerScale!.length;

  factory CalibrationModel.fromJson(String jsonText) {
    final jsonMap = jsonDecode(jsonText) as Map<String, dynamic>;
    final isDeployModel =
        jsonMap.containsKey('linear_head') && jsonMap.containsKey('scaler');
    if (isDeployModel) {
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

    final coeffs = _asDoubleList(linearHead['coef'] as List<dynamic>?);
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

    return CalibrationModel(
      id: id,
      name: name,
      coefficients: Float64List.fromList(coeffs),
      intercept: (linearHead['intercept'] as num?)?.toDouble() ?? 0,
      units: units,
      label: label,
      expectedLength: coeffs.length,
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
