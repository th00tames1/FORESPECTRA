import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/averaging.dart';
import '../../domain/calibration_model.dart';
import '../../services/app_state.dart';
import '../../services/i18n.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Set<String> _expandedModelIds = <String>{};

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
                  t('config.title'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),

                _sectionLabel(context, t('config.general')),
                _generalCard(context, state),
                const SizedBox(height: 12),
                _displayCard(context, state),

                const SizedBox(height: 24),

                _sectionLabel(context, t('config.models')),
                _modelsCard(context, state),

                const SizedBox(height: 24),

                _sectionLabel(context, t('config.advanced')),
                _advancedCard(context, state),

                const SizedBox(height: 24),

                // Destructive actions are grouped at the bottom so a risky
                // tap can't happen mid-scroll between routine settings.
                _resetCard(context, state),
                const SizedBox(height: 12),
                _savedSensorsCard(context, state),

                const SizedBox(height: 24),

                _sectionLabel(context, t('config.about')),
                _aboutCard(context),
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
              label: t('config.theme'),
              value: state.themeMode,
              items: [
                DropdownMenuItem(
                  value: ThemeMode.light,
                  child: Text(t('config.themeLight')),
                ),
                DropdownMenuItem(
                  value: ThemeMode.dark,
                  child: Text(t('config.themeDark')),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                state.setThemeMode(value);
              },
            ),
            _dropdownField<String>(
              context: context,
              label: t('config.language'),
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
              label: t('config.axisUnit'),
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
              title: Text(t('config.showDiagnostics')),
              subtitle: Text(t('config.showDiagnosticsSubtitle')),
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
          title: Text(t('config.savedSensors')),
          subtitle: Text(t('config.savedSensorsSubtitle')),
          trailing: TextButton.icon(
            onPressed: () => _confirmForgetSensors(context, state),
            icon: const Icon(Icons.delete_outline),
            label: Text(t('common.clear')),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Models card — toggle which models the Scan flow runs, expand each
  // row to see algorithm + CV metrics + dataset info.
  // ─────────────────────────────────────────────────────────────────

  Widget _modelsCard(BuildContext context, AppState state) {
    final models = state.availableModels;
    if (models.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            t('config.modelsNone'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t('config.modelsHint'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...models.map((m) => _modelRow(context, state, m)),
          ],
        ),
      ),
    );
  }

  Widget _modelRow(
    BuildContext context,
    AppState state,
    CalibrationModel model,
  ) {
    final isExpanded = _expandedModelIds.contains(model.id);
    final isSelected = state.isModelSelected(model.id);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline,
            width: 0.6,
          ),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() {
              if (isExpanded) {
                _expandedModelIds.remove(model.id);
              } else {
                _expandedModelIds.add(model.id);
              }
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (v) =>
                        state.toggleModelSelection(model.id, v == true),
                  ),
                  Expanded(
                    child: Text(
                      model.name,
                      style: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: isExpanded
                ? _modelDetails(context, model)
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _modelDetails(BuildContext context, CalibrationModel m) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final rows = <Widget>[];

    void addRow(String label, String? value, {String? note}) {
      if (value == null || value.isEmpty) return;
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelSmall
                    ?.copyWith(color: muted, letterSpacing: 0.4),
              ),
            ),
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                  children: [
                    TextSpan(text: value),
                    if (note != null && note.isNotEmpty)
                      TextSpan(
                        text: '   $note',
                        style: TextStyle(color: muted, fontStyle: FontStyle.italic),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ));
    }

    addRow(t('config.rowAlgorithm'), m.algorithm.isEmpty ? '—' : m.algorithm);
    addRow(t('config.rowClasses'),
        m.classes.isEmpty ? null : m.classes.join(', '));
    addRow(m.metricPrimaryLabel ?? '', m.metricPrimaryValue,
        note: m.metricPrimaryNote);
    addRow(m.metricSecondaryLabel ?? '', m.metricSecondaryValue,
        note: m.metricSecondaryNote);
    addRow(t('config.rowSamples'), m.nSamples?.toString());
    addRow(t('config.rowVersion'),
        m.modelVersion.isEmpty ? null : m.modelVersion);
    addRow(t('config.rowDate'), _formatDate(m.createdAt));

    return Padding(
      padding: const EdgeInsets.fromLTRB(48, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (m.description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                m.description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
              ),
            ),
          ...rows,
        ],
      ),
    );
  }

  String? _formatDate(String iso) {
    if (iso.isEmpty) return null;
    // Keep just YYYY-MM-DD; ISO timestamps look like 2026-02-19T18:24:06.
    final t = iso.indexOf('T');
    return t > 0 ? iso.substring(0, t) : iso;
  }

  // ─────────────────────────────────────────────────────────────────
  // Advanced (measurement)
  // ─────────────────────────────────────────────────────────────────

  Widget _advancedCard(BuildContext context, AppState state) {
    return Card(
      child: ExpansionTile(
        title: Text(t('config.measurementSettings')),
        subtitle: Text(t('config.measurementSubtitle')),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          const SizedBox(height: 6),
          _subHeader(context, t('config.capture')),
          _sliderField(
            context: context,
            label: t('config.scansPerCapture'),
            value: state.targetScanCount.toDouble(),
            min: 1,
            max: 20,
            valueLabel: '${state.targetScanCount}',
            onChanged: (v) => state.updateTargetScanCount(v.round()),
          ),
          _dropdownField<AveragingMethod>(
            context: context,
            label: t('config.combineMethod'),
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
            label: t('config.referenceExpire'),
            value: state.referenceMaxAge,
            items: [
              DropdownMenuItem(
                value: const Duration(minutes: 30),
                child: Text(t('config.expire30min')),
              ),
              DropdownMenuItem(
                value: const Duration(hours: 1),
                child: Text(t('config.expire1h')),
              ),
              DropdownMenuItem(
                value: const Duration(hours: 2),
                child: Text(t('config.expire2h')),
              ),
              DropdownMenuItem(
                value: const Duration(hours: 4),
                child: Text(t('config.expire4h')),
              ),
              DropdownMenuItem(
                value: const Duration(hours: 8),
                child: Text(t('config.expire8h')),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              state.updateReferenceMaxAge(value);
            },
          ),

          const SizedBox(height: 8),
          _subHeader(context, t('config.scanParams')),
          _sliderField(
            context: context,
            label: t('config.scanTimeMs'),
            value: state.scanParams.scanTimeMs.toDouble(),
            min: 10,
            max: 224,
            onChanged: (v) => state.updateScanTime(v.toInt()),
          ),
          _dropdownField<int>(
            context: context,
            label: t('config.resolutionPreset'),
            value: state.scanParams.zeroPadding,
            items: [
              DropdownMenuItem(value: 1, child: Text(t('config.presetFast'))),
              DropdownMenuItem(
                  value: 2, child: Text(t('config.presetBalanced'))),
              DropdownMenuItem(value: 3, child: Text(t('config.presetHigh'))),
            ],
            onChanged: (value) {
              if (value == null) return;
              state.updateZeroPadding(value);
            },
          ),
          _dropdownField<int>(
            context: context,
            label: t('config.dataPoints'),
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
            label: t('config.opticalGainMode'),
            value: state.scanParams.opticalGain,
            items: [
              DropdownMenuItem(value: 0, child: Text(t('config.gainAuto'))),
              DropdownMenuItem(
                  value: 1, child: Text(t('config.gainCalculated'))),
              DropdownMenuItem(value: 2, child: Text(t('config.gainExternal'))),
            ],
            onChanged: (value) {
              if (value == null) return;
              state.updateOpticalGain(value);
            },
          ),
          _dropdownField<int>(
            context: context,
            label: t('config.smoothing'),
            value: state.scanParams.apodizationSel,
            items: [
              DropdownMenuItem(value: 0, child: Text(t('config.smoothNone'))),
              DropdownMenuItem(value: 1, child: Text(t('config.smoothSoft'))),
              DropdownMenuItem(value: 2, child: Text(t('config.smoothMedium'))),
              DropdownMenuItem(value: 3, child: Text(t('config.smoothStrong'))),
            ],
            onChanged: (value) {
              if (value == null) return;
              state.updateApodization(value);
            },
          ),

          const SizedBox(height: 8),
          _subHeader(context, t('config.sourceLamps')),
          _numberField(
            label: t('config.lampsCount'),
            initialValue: state.lampsCount.toString(),
            onChanged: (v) =>
                state.updateLampsCount(int.tryParse(v) ?? state.lampsCount),
          ),
          _numberField(
            label: t('config.lampSelect'),
            initialValue: state.lampSelect.toString(),
            onChanged: (v) =>
                state.updateLampSelect(int.tryParse(v) ?? state.lampSelect),
          ),
          _numberField(
            label: t('config.t1'),
            initialValue: state.t1.toString(),
            onChanged: (v) => state.updateT1(int.tryParse(v) ?? state.t1),
          ),
          _numberField(
            label: t('config.deltaT'),
            initialValue: state.deltaT.toString(),
            onChanged: (v) =>
                state.updateDeltaT(int.tryParse(v) ?? state.deltaT),
          ),
          _numberField(
            label: t('config.t2c1'),
            initialValue: state.t2c1.toString(),
            onChanged: (v) => state.updateT2C1(int.tryParse(v) ?? state.t2c1),
          ),
          _numberField(
            label: t('config.t2c2'),
            initialValue: state.t2c2.toString(),
            onChanged: (v) => state.updateT2C2(int.tryParse(v) ?? state.t2c2),
          ),
          _numberField(
            label: t('config.t2max'),
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
              label: Text(t('config.applySource')),
            ),
          ),

          const SizedBox(height: 12),
          _subHeader(context, t('config.manualGain')),
          _numberField(
            label: t('config.gainValue'),
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
              label: Text(t('config.applyGain')),
            ),
          ),

          const SizedBox(height: 12),
          _subHeader(context, t('config.developer')),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.sendLengthPrefix,
            onChanged: state.updateSendLengthPrefix,
            title: Text(t('config.packetPrefix')),
            subtitle: Text(t('config.packetPrefixSubtitle')),
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
          title: Text(t('config.resetDefaults')),
          subtitle: Text(t('config.resetDefaultsSubtitle')),
          trailing: TextButton.icon(
            onPressed: () => _confirmReset(context, state),
            icon: const Icon(Icons.restart_alt),
            label: Text(t('common.reset')),
          ),
        ),
      ),
    );
  }

  Widget _aboutCard(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final ink = Theme.of(context).colorScheme.onSurface;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Forespectra',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Heechan Jeong',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Advanced Forestry Systems Lab',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: muted,
              ),
            ),
            Text(
              'Oregon State University',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: muted,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '© 2026 Heechan Jeong. All rights reserved.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState state) {
    return _confirmAndRun(
      context: context,
      title: t('config.resetTitle'),
      body: t('config.resetBody'),
      confirmLabel: t('common.reset'),
      action: state.resetSettings,
      doneMessage: t('config.resetDone'),
    );
  }

  Future<void> _confirmForgetSensors(BuildContext context, AppState state) {
    return _confirmAndRun(
      context: context,
      title: t('config.forgetTitle'),
      body: t('config.forgetBody'),
      confirmLabel: t('common.clear'),
      action: state.forgetSavedSensors,
      doneMessage: t('config.forgetDone'),
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
              child: Text(t('common.cancel')),
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
