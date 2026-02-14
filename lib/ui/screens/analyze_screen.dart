import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../widgets/spectrum_chart.dart';

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({
    super.key,
    this.fromScanFlow = false,
  });

  final bool fromScanFlow;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final bottomInset = MediaQuery.of(context).padding.bottom + 140;
        return SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Results', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Turn your scan into a simple readout.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                SpectrumChart(
                  spectrum: state.latestSpectrum,
                  title: 'Spectrum Preview',
                  axisUnit: state.spectrumAxisUnit,
                ),
                if (fromScanFlow) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            state.discardLatest();
                            Navigator.pop(context);
                          },
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: state.latestSpectrum == null
                              ? null
                              : () async {
                                  final confirm = await _showSaveConfirmDialog(
                                    context,
                                    state,
                                  );
                                  if (confirm == null) {
                                    return;
                                  }
                                  state.updateMaterialName(
                                    confirm.material,
                                    notify: false,
                                  );
                                  state.updateSampleName(
                                    confirm.sample,
                                    notify: false,
                                  );
                                  await state.saveSession();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  final messenger = ScaffoldMessenger.of(context);
                                  Navigator.of(context).pop();
                                  messenger
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      const SnackBar(
                                        content: Text('Saved'),
                                        duration: Duration(milliseconds: 1500),
                                      ),
                                    );
                                },
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_SaveConfirmResult?> _showSaveConfirmDialog(
    BuildContext context,
    AppState state,
  ) async {
    var material = state.materialName;
    var sample = state.sampleName;
    final result = await showDialog<_SaveConfirmResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Save'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: material,
                onChanged: (value) => material = value,
                decoration: const InputDecoration(labelText: 'Material name'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: sample,
                onChanged: (value) => sample = value,
                decoration: const InputDecoration(labelText: 'Sample name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _SaveConfirmResult(
                  material: material.trim(),
                  sample: sample.trim(),
                ),
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    return result;
  }
}

class _SaveConfirmResult {
  const _SaveConfirmResult({
    required this.material,
    required this.sample,
  });

  final String material;
  final String sample;
}
