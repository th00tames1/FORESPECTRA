import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/averaging.dart';
import '../../services/app_state.dart';
import '../../services/i18n.dart';

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
                Text(
                  'Config',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),

                // ── General settings ─────────────────────────────────
                _sectionLabel(context, 'General'),
                _generalCard(context, state),
                const SizedBox(height: 12),
                _displayCard(context, state),
                const SizedBox(height: 12),
                _savedSensorsCard(context, state),

                const SizedBox(height: 24),

                // ── Advanced (measurement) ───────────────────────────
                _sectionLabel(context, 'Advanced'),
                _advancedCard(context, state),

                const SizedBox(height: 24),

                // ── Reset ────────────────────────────────────────────
                _resetCard(context, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // General cards
  // ─────────────────────────────────────────────────────────────────

  Widget _generalCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dropdownField<ThemeMode>(
              context: context,
              label: 'Theme',
              value: state.themeMode,
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
            _dropdownField<String>(
              context: context,
              label: 'Language',
              value: state.locale,
              items: const [
                DropdownMenuItem(value: AppLocale.en, child: Text('English')),
                DropdownMenuItem(value: AppLocale.ko, child: Text('한국어')),
              ],
              onChanged: (value) {
                if (value == null) return;
                state.setLocale(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _displayCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dropdownField<String>(
              context: context,
              label: 'Spectrum axis unit',
              value: state.spectrumAxisUnit,
              items: const [
                DropdownMenuItem(value: 'DN', child: Text('DN')),
                DropdownMenuItem(value: 'cm^-1', child: Text('cm⁻¹')),
                DropdownMenuItem(value: 'nm', child: Text('nm')),
              ],
              onChanged: (value) {
                if (value == null) return;
                state.updateSpectrumAxisUnit(value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: state.showGhNhDiagnostics,
              onChanged: state.updateShowGhNhDiagnostics,
              title: const Text('Show GH/NH diagnostics'),
              subtitle: const Text(
                'Display model diagnostics next to predictions.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedSensorsCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Saved sensors'),
          subtitle: const Text(
            'Clear stored device IPs from the picker.',
          ),
          trailing: TextButton.icon(
            onPressed: () => _confirmForgetSensors(context, state),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Clear'),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Advanced (measurement)
  // ─────────────────────────────────────────────────────────────────

  Widget _advancedCard(BuildContext context, AppState state) {
    return Card(
      child: ExpansionTile(
        title: const Text('Measurement settings'),
        subtitle: const Text('Capture, scan, and device parameters'),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const SizedBox(height: 6),
          _subHeader(context, 'Capture'),
          _sliderField(
            context: context,
            label: 'Scans per capture',
            value: state.targetScanCount.toDouble(),
            min: 1,
            max: 20,
            valueLabel: '${state.targetScanCount}',
            onChanged: (v) => state.updateTargetScanCount(v.round()),
          ),
          _dropdownField<AveragingMethod>(
            context: context,
            label: 'Combine method',
            value: state.averagingMethod,
            items: AveragingMethod.values
                .map(
                  (m) => DropdownMenuItem(value: m, child: Text(m.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value == null) return;
              state.updateAveragingMethod(value);
            },
          ),
          _dropdownField<Duration>(
            context: context,
            label: 'Reference auto-expire',
            value: state.referenceMaxAge,
            items: const [
              DropdownMenuItem(
                value: Duration(minutes: 30),
                child: Text('30 min'),
              ),
              DropdownMenuItem(
                value: Duration(hours: 1),
                child: Text('1 hour'),
              ),
              DropdownMenuItem(
                value: Duration(hours: 2),
                child: Text('2 hours'),
              ),
              DropdownMenuItem(
                value: Duration(hours: 4),
                child: Text('4 hours'),
              ),
              DropdownMenuItem(
                value: Duration(hours: 8),
                child: Text('8 hours'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              state.updateReferenceMaxAge(value);
            },
          ),

          const SizedBox(height: 8),
          _subHeader(context, 'Scan parameters'),
          _sliderField(
            context: context,
            label: 'Scan time (ms)',
            value: state.scanParams.scanTimeMs.toDouble(),
            min: 10,
            max: 224,
            onChanged: (v) => state.updateScanTime(v.toInt()),
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
          _dropdownField<int>(
            context: context,
            label: 'Optical gain mode',
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
          _subHeader(context, 'Source / lamps'),
          _numberField(
            label: 'Lamps count',
            initialValue: state.lampsCount.toString(),
            onChanged: (v) =>
                state.updateLampsCount(int.tryParse(v) ?? state.lampsCount),
          ),
          _numberField(
            label: 'Lamp select',
            initialValue: state.lampSelect.toString(),
            onChanged: (v) =>
                state.updateLampSelect(int.tryParse(v) ?? state.lampSelect),
          ),
          _numberField(
            label: 'T1',
            initialValue: state.t1.toString(),
            onChanged: (v) => state.updateT1(int.tryParse(v) ?? state.t1),
          ),
          _numberField(
            label: 'Delta T',
            initialValue: state.deltaT.toString(),
            onChanged: (v) =>
                state.updateDeltaT(int.tryParse(v) ?? state.deltaT),
          ),
          _numberField(
            label: 'T2 C1',
            initialValue: state.t2c1.toString(),
            onChanged: (v) => state.updateT2C1(int.tryParse(v) ?? state.t2c1),
          ),
          _numberField(
            label: 'T2 C2',
            initialValue: state.t2c2.toString(),
            onChanged: (v) => state.updateT2C2(int.tryParse(v) ?? state.t2c2),
          ),
          _numberField(
            label: 'T2 max',
            initialValue: state.t2max.toString(),
            onChanged: (v) =>
                state.updateT2Max(int.tryParse(v) ?? state.t2max),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  state.isConnected ? state.applySourceSettings : null,
              icon: const Icon(Icons.tune),
              label: const Text('Apply source settings'),
            ),
          ),

          const SizedBox(height: 12),
          _subHeader(context, 'Manual optical gain'),
          _numberField(
            label: 'Gain value',
            initialValue: state.opticalGainValue.toString(),
            onChanged: (v) => state.updateOpticalGainValue(
              int.tryParse(v) ?? state.opticalGainValue,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed:
                  state.isConnected ? state.applyOpticalSettings : null,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Apply gain'),
            ),
          ),

          const SizedBox(height: 12),
          _subHeader(context, 'Developer'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.sendLengthPrefix,
            onChanged: state.updateSendLengthPrefix,
            title: const Text('Enable packet prefix'),
            subtitle: const Text('Use only if support requests it.'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Reset
  // ─────────────────────────────────────────────────────────────────

  Widget _resetCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Reset to defaults'),
          subtitle: const Text(
            'Restore all preferences. Saved sensors and history are kept.',
          ),
          trailing: TextButton.icon(
            onPressed: () => _confirmReset(context, state),
            icon: const Icon(Icons.restart_alt),
            label: const Text('Reset'),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) {
    return _confirmAndRun(
      context: context,
      title: 'Reset all settings?',
      body: 'Theme, display options, and all measurement parameters will be '
          'restored to their defaults. Saved sensors, scan history, and '
          'models are not affected.',
      confirmLabel: 'Reset',
      action: state.resetSettings,
      doneMessage: 'Settings restored to defaults',
    );
  }

  Future<void> _confirmForgetSensors(BuildContext context, AppState state) {
    return _confirmAndRun(
      context: context,
      title: 'Clear saved sensors?',
      body: 'All stored device IPs will be removed from the picker. The '
          'current connection is unaffected. Discovery will find them '
          'again next time.',
      confirmLabel: 'Clear',
      action: state.forgetSavedSensors,
      doneMessage: 'Saved sensors cleared',
    );
  }

  Future<void> _confirmAndRun({
    required BuildContext context,
    required String title,
    required String body,
    required String confirmLabel,
    required Future<void> Function() action,
    required String doneMessage,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await action();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(doneMessage),
          duration: const Duration(milliseconds: 1500),
        ),
      );
  }

  // ─────────────────────────────────────────────────────────────────
  // Reusable field widgets
  // ─────────────────────────────────────────────────────────────────

  Widget _subHeader(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall,
      ),
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
    String? valueLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              const Spacer(),
              Text(
                valueLabel ?? value.toStringAsFixed(0),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: 100,
            label: valueLabel ?? value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
