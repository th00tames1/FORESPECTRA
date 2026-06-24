part of 'app_state.dart';

// ── Models / analysis concern ─────────────────────────────────────────
// Bundled calibration-model loading, selection state, and running the
// selected models against the latest spectrum.

const List<String> _bundledModelAssetPaths = [
  'assets/models/species_model.json',
  'assets/models/moisture_model.json',
  'assets/models/leaves_species_model.json',
  'assets/models/leaves_moisture_model.json',
  'assets/models/soil_water_content_model.json',
  'assets/models/soil_organic_matter_model.json',
];

extension AppStateModels on AppState {
  List<CalibrationModel> get selectedModels {
    return availableModels
        .where((model) => selectedModelIds.contains(model.id))
        .toList(growable: false);
  }

  bool isModelSelected(String modelId) => selectedModelIds.contains(modelId);

  void setSelectedModelIds(Set<String> modelIds) {
    selectedModelIds = Set<String>.from(modelIds);
    _runSelectedModelAnalysis(notify: false);
    notifyUi();
  }

  void toggleModelSelection(String modelId, bool isSelected) {
    if (isSelected) {
      selectedModelIds.add(modelId);
    } else {
      selectedModelIds.remove(modelId);
    }
    _runSelectedModelAnalysis(notify: false);
    notifyUi();
  }

  Future<void> analyze() async {
    _runSelectedModelAnalysis(notify: false);
    notifyUi();
  }

  Future<void> loadBundledModels({bool notify = true}) async {
    try {
      final parsed = <CalibrationModel>[];
      for (final assetPath in _bundledModelAssetPaths) {
        try {
          final jsonText = await rootBundle.loadString(assetPath);
          parsed.add(CalibrationModel.fromJson(jsonText));
        } catch (_) {
          // Ignore invalid bundled model payloads.
        }
      }

      availableModels = parsed;
      final availableIds = parsed.map((model) => model.id).toSet();
      selectedModelIds = selectedModelIds.where(availableIds.contains).toSet();
      _runSelectedModelAnalysis(notify: false);
    } catch (_) {
      availableModels = const [];
      selectedModelIds = <String>{};
      latestAnalysisResults = const [];
    }

    if (notify) {
      notifyUi();
    }
  }

  void _runSelectedModelAnalysis({bool notify = true}) {
    final spectrum = latestSpectrum;
    if (spectrum == null ||
        selectedModelIds.isEmpty ||
        availableModels.isEmpty) {
      latestAnalysisResults = const [];
      if (notify) {
        notifyUi();
      }
      return;
    }

    final outputs = <AnalysisResult>[];
    for (final model in availableModels) {
      if (!selectedModelIds.contains(model.id)) {
        continue;
      }
      try {
        outputs.add(runAnalysis(spectrum, model, thresholds: ghNhThresholds));
      } catch (_) {
        // Ignore model failures for this scan.
      }
    }

    latestAnalysisResults = outputs;
    if (notify) {
      notifyUi();
    }
  }
}
