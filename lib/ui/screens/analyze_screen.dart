import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../widgets/spectrum_chart.dart';

class AnalyzeScreen extends StatelessWidget {
  const AnalyzeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final bottomInset = MediaQuery.of(context).padding.bottom + 110;
        return SafeArea(
          bottom: false,
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
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.lastResult?.label ?? 'Ready to analyze',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.lastResult == null
                              ? 'Capture a scan and tap Analyze.'
                              : '${state.lastResult!.value.toStringAsFixed(4)} ${state.lastResult!.units}',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: state.latestSpectrum != null && state.currentModel != null
                                ? state.analyze
                                : null,
                            icon: const Icon(Icons.insights),
                            label: const Text('Analyze sample'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: state.importModel,
                          icon: const Icon(Icons.upload_file),
                          label: Text(
                            state.currentModel == null
                                ? 'Load analysis model'
                                : 'Change model (${state.currentModel!.name})',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SpectrumChart(spectrum: state.latestSpectrum, title: 'Spectrum Preview'),
              ],
            ),
          ),
        );
      },
    );
  }
}
