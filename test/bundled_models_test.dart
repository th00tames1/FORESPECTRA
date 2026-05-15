import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:spectral_app/domain/analyzer.dart';
import 'package:spectral_app/domain/calibration_model.dart';
import 'package:spectral_app/domain/spectrum.dart';

/// Smoke-test that every bundled model parses and produces a finite output
/// when fed a synthetic spectrum on its declared wavelength axis. Doesn't
/// validate accuracy — just that JSON contract + analyzer dispatch are wired.
void main() {
  const assetPaths = [
    'assets/models/species_model.json',
    'assets/models/moisture_model.json',
    'assets/models/leaves_species_model.json',
    'assets/models/leaves_moisture_model.json',
    'assets/models/soil_water_content_model.json',
    'assets/models/soil_organic_matter_model.json',
  ];

  for (final path in assetPaths) {
    test('$path parses and runs', () {
      final jsonText = File(path).readAsStringSync();
      final model = CalibrationModel.fromJson(jsonText);
      // Either a linear-head model (coefficients) or a tree ensemble
      // (trees) must be populated.
      final hasHead = model.coefficients.isNotEmpty ||
          model.coefficientsByClass.isNotEmpty ||
          model.trees.isNotEmpty;
      expect(hasHead, isTrue, reason: '$path: no head or trees');
      expect(model.xAxis.isNotEmpty, isTrue, reason: '$path: empty xAxis');

      final x = Float64List.fromList(model.xAxis);
      // Synthetic flat-ish spectrum so analysis just exercises the pipeline.
      final y = Float64List(x.length);
      for (var i = 0; i < y.length; i++) {
        y[i] = 0.5 + 0.01 * (i % 7);
      }
      final result = runAnalysis(Spectrum(x: x, y: y), model);
      expect(result.displayValue, isNotEmpty);

      if (model.isMultiClass) {
        expect(model.coefficientsByClass.length, model.classes.length);
        for (final c in model.coefficientsByClass) {
          expect(c.length, model.coefficients.length);
        }
        expect(model.interceptsByClass.length, model.classes.length);
      }
    });
  }

  // The four new models carry a GH/NH outlier-diagnostics block.
  const ghNhModels = [
    'assets/models/leaves_species_model.json',
    'assets/models/leaves_moisture_model.json',
    'assets/models/soil_water_content_model.json',
    'assets/models/soil_organic_matter_model.json',
  ];
  for (final path in ghNhModels) {
    test('$path has a valid GH/NH config', () {
      final model = CalibrationModel.fromJson(File(path).readAsStringSync());
      final cfg = model.fossGhNhConfig;
      expect(cfg, isNotNull, reason: '$path: missing gh_nh block');
      expect(cfg!.isValid, isTrue, reason: '$path: gh_nh block invalid');
      expect(cfg.pca.featureLength, model.expectedLength,
          reason: '$path: PCA feature length must match model feature count');
    });
  }
}
