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

  factory CalibrationModel.fromJson(String jsonText) {
    final jsonMap = jsonDecode(jsonText) as Map<String, dynamic>;
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
      xAxis: (jsonMap['xAxis'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          [],
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
    };
  }
}
