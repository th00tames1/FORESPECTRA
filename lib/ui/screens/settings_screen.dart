import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Config', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Control device and scan settings.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text('Theme', style: Theme.of(context).textTheme.labelLarge),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<ThemeMode>(
                            key: ValueKey(state.themeMode),
                            initialValue: state.themeMode,
                            items: const [
                              DropdownMenuItem(
                                value: ThemeMode.light,
                                child: Text('Light mode'),
                              ),
                              DropdownMenuItem(
                                value: ThemeMode.dark,
                                child: Text('Dark mode'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              state.setThemeMode(value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text('Advanced controls'),
                    subtitle: const Text('Scan + device settings'),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      const SizedBox(height: 6),
                      Text('Scan settings',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _sliderField(
                        context: context,
                        label: 'Scan time (ms)',
                        value: state.scanParams.scanTimeMs.toDouble(),
                        min: 10,
                        max: 224,
                        onChanged: (value) => state.updateScanTime(value.toInt()),
                      ),
                      _dropdownField<int>(
                        context: context,
                        label: 'Resolution preset',
                        value: state.scanParams.zeroPadding,
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
                      _dropdownField<int>(
                        context: context,
                        label: 'Data points',
                        value: state.scanParams.commonWavNum,
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
                      _dropdownField<String>(
                        context: context,
                        label: 'Spectrum plot axis',
                        value: state.spectrumAxisUnit,
                        items: const [
                          DropdownMenuItem(value: 'DN', child: Text('DN')),
                          DropdownMenuItem(value: 'cm^-1', child: Text('cm^-1')),
                          DropdownMenuItem(value: 'nm', child: Text('nm')),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          state.updateSpectrumAxisUnit(value);
                        },
                      ),
                      _dropdownField<int>(
                        context: context,
                        label: 'Optical gain',
                        value: state.scanParams.opticalGain,
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
                      _dropdownField<int>(
                        context: context,
                        label: 'Smoothing',
                        value: state.scanParams.apodizationSel,
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
                      SwitchListTile(
                        value: state.sendLengthPrefix,
                        onChanged: state.updateSendLengthPrefix,
                        title: const Text('Enable packet prefix'),
                        subtitle: const Text('Use only if support requests it.'),
                      ),
                      const SizedBox(height: 8),
                      Text('Source settings',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _numberField(
                        label: 'Lamps count',
                        initialValue: state.lampsCount.toString(),
                        onChanged: (value) => state.lampsCount = int.tryParse(value) ?? state.lampsCount,
                      ),
                      _numberField(
                        label: 'Lamp select',
                        initialValue: state.lampSelect.toString(),
                        onChanged: (value) => state.lampSelect = int.tryParse(value) ?? state.lampSelect,
                      ),
                      _numberField(
                        label: 'T1',
                        initialValue: state.t1.toString(),
                        onChanged: (value) => state.t1 = int.tryParse(value) ?? state.t1,
                      ),
                      _numberField(
                        label: 'Delta T',
                        initialValue: state.deltaT.toString(),
                        onChanged: (value) => state.deltaT = int.tryParse(value) ?? state.deltaT,
                      ),
                      _numberField(
                        label: 'T2 C1',
                        initialValue: state.t2c1.toString(),
                        onChanged: (value) => state.t2c1 = int.tryParse(value) ?? state.t2c1,
                      ),
                      _numberField(
                        label: 'T2 C2',
                        initialValue: state.t2c2.toString(),
                        onChanged: (value) => state.t2c2 = int.tryParse(value) ?? state.t2c2,
                      ),
                      _numberField(
                        label: 'T2 max',
                        initialValue: state.t2max.toString(),
                        onChanged: (value) => state.t2max = int.tryParse(value) ?? state.t2max,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: state.isConnected ? state.applySourceSettings : null,
                        icon: const Icon(Icons.tune),
                        label: const Text('Apply source settings'),
                      ),
                      const SizedBox(height: 12),
                      Text('Optical gain', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      _numberField(
                        label: 'Gain value',
                        initialValue: state.opticalGainValue.toString(),
                        onChanged: (value) =>
                            state.opticalGainValue = int.tryParse(value) ?? state.opticalGainValue,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: state.isConnected ? state.applyOpticalSettings : null,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Apply gain'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _numberField({
    required String label,
    required String initialValue,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initialValue,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label),
        onChanged: onChanged,
      ),
    );
  }

  Widget _dropdownField<T>({
    required BuildContext context,
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
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

  Widget _sliderField({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: 100,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
