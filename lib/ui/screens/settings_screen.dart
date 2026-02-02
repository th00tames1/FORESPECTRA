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
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text('Simple controls for everyday use.',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Device', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          'Keep settings here unless instructed by support.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ExpansionTile(
                    title: const Text('Advanced controls'),
                    subtitle: const Text('For technicians only'),
                    childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
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
}
