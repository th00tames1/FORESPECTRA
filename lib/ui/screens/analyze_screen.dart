import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/analyzer.dart';
import '../../services/app_state.dart';
import '../widgets/spectrum_chart.dart';

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({super.key, this.fromScanFlow = false});

  final bool fromScanFlow;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final media = MediaQuery.of(context);
        final baseBottomPadding = fromScanFlow ? 24.0 : 96.0;
        final bottomInset = media.padding.bottom + baseBottomPadding;
        return SafeArea(
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTabletLayout = constraints.maxWidth >= 720;
              final useSpreadLayout = isTabletLayout && media.viewInsets.bottom == 0;
              final contentMaxWidth = isTabletLayout ? 760.0 : double.infinity;
              final contentAlignment = Alignment.topCenter;
              final availableHeight = constraints.maxHeight - 20 - bottomInset;
              final minHeight = availableHeight > 0 ? availableHeight : 0.0;

              final topSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Results',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Turn your scan into a simple readout.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );

              final middleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SpectrumChart(
                    spectrum: state.latestSpectrum,
                    title: 'Spectrum Preview',
                    axisUnit: state.spectrumAxisUnit,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _AnalysisSummaryCard(results: state.latestAnalysisResults),
                  ),
                ],
              );

              final actionSection = fromScanFlow
                  ? Row(
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
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
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
                    )
                  : const SizedBox.shrink();

              final content = useSpreadLayout
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        topSection,
                        SizedBox(height: (minHeight * 0.08).clamp(18.0, 40.0)),
                        middleSection,
                        if (fromScanFlow) ...[
                          SizedBox(height: (minHeight * 0.06).clamp(14.0, 32.0)),
                          actionSection,
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        topSection,
                        const SizedBox(height: 16),
                        middleSection,
                        if (fromScanFlow) ...[
                          const SizedBox(height: 16),
                          actionSection,
                        ],
                      ],
                    );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Align(
                    alignment: contentAlignment,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: content,
                    ),
                  ),
                ),
              );
            },
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
  const _SaveConfirmResult({required this.material, required this.sample});

  final String material;
  final String sample;
}

class _AnalysisSummaryCard extends StatelessWidget {
  const _AnalysisSummaryCard({required this.results});

  final List<AnalysisResult> results;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Analysis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (results.isEmpty)
              Text(
                'No model applied. Select models from the Model button on Scan tab.',
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...results.map(
                (result) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${result.label}: ${result.displayValue}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
