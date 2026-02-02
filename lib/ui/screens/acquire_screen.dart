import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../widgets/spectrum_chart.dart';

class AcquireScreen extends StatelessWidget {
  const AcquireScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final bottomInset = MediaQuery.of(context).padding.bottom + 110;
        return SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      Text('Scan', style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Place the sample and tap Capture.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      SpectrumChart(spectrum: state.latestSpectrum, title: 'Live Preview'),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: state.isConnected ? state.runSpectrum : null,
                          child: const Text('Capture'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          TextButton.icon(
                            onPressed: state.isConnected
                                ? () => _showAdvanced(context, state)
                                : null,
                            icon: const Icon(Icons.tune),
                            label: const Text('Advanced settings'),
                          ),
                          OutlinedButton.icon(
                            onPressed: state.latestSpectrum != null ? state.saveSession : null,
                            icon: const Icon(Icons.save_alt),
                            label: const Text('Save session'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showAdvanced(BuildContext context, AppState state) {
    final params = state.scanParams;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Advanced Scan', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _LabeledField(
                  label: 'Scan time (ms)',
                  child: Slider(
                    value: params.scanTimeMs.toDouble(),
                    min: 10,
                    max: 224,
                    divisions: 100,
                    label: params.scanTimeMs.toString(),
                    onChanged: (value) {
                      state.updateScanTime(value.toInt());
                    },
                  ),
                ),
                _DropdownField<int>(
                  label: 'Resolution preset',
                  value: params.zeroPadding,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('Fast')),
                    DropdownMenuItem(value: 2, child: Text('Balanced')),
                    DropdownMenuItem(value: 3, child: Text('High detail')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    state.updateZeroPadding(value);
                  },
                ),
                _DropdownField<int>(
                  label: 'Data points',
                  value: params.commonWavNum,
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('65')),
                    DropdownMenuItem(value: 2, child: Text('129')),
                    DropdownMenuItem(value: 3, child: Text('257')),
                    DropdownMenuItem(value: 4, child: Text('513')),
                    DropdownMenuItem(value: 5, child: Text('1024')),
                    DropdownMenuItem(value: 6, child: Text('2048')),
                    DropdownMenuItem(value: 7, child: Text('4096')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    state.updateCommonWavNum(value);
                  },
                ),
                _DropdownField<int>(
                  label: 'Optical gain',
                  value: params.opticalGain,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('Automatic')),
                    DropdownMenuItem(value: 1, child: Text('Calculated')),
                    DropdownMenuItem(value: 2, child: Text('External')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    state.updateOpticalGain(value);
                  },
                ),
                _DropdownField<int>(
                  label: 'Smoothing',
                  value: params.apodizationSel,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('None')),
                    DropdownMenuItem(value: 1, child: Text('Soft')),
                    DropdownMenuItem(value: 2, child: Text('Medium')),
                    DropdownMenuItem(value: 3, child: Text('Strong')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    state.updateApodization(value);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: state.isConnected ? state.runBackground : null,
                    icon: const Icon(Icons.layers),
                    label: const Text('Set reference'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          DropdownButtonFormField<T>(
            key: ValueKey(value),
            initialValue: value,
            items: items,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
