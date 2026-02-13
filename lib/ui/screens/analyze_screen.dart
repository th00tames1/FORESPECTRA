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
                SpectrumChart(spectrum: state.latestSpectrum, title: 'Spectrum Preview'),
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
                                  await state.saveSession();
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
}
