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
                            state.setTab(1);
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
                                  final shouldSave = await _showSaveConfirmDialog(
                                    context,
                                    state,
                                  );
                                  if (!shouldSave) {
                                    return;
                                  }
                                  await state.saveSession();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        const SnackBar(
                                          content: Text('Saved'),
                                          duration: Duration(milliseconds: 1500),
                                        ),
                                      );
                                  }
                                  state.setTab(1);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
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

  Future<bool> _showSaveConfirmDialog(BuildContext context, AppState state) async {
    final materialController = TextEditingController(text: state.materialName);
    final sampleController = TextEditingController(text: state.sampleName);
    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Confirm Save'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: materialController,
                decoration: const InputDecoration(labelText: 'Material name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: sampleController,
                decoration: const InputDecoration(labelText: 'Sample name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    state.updateMaterialName(materialController.text.trim());
    state.updateSampleName(sampleController.text.trim());
    materialController.dispose();
    sampleController.dispose();
    return shouldSave == true;
  }
}
