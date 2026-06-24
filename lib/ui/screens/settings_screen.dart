import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

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

                _sectionLabel(context, t('config.backup')),
                _backupCard(context, state),

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
            if (state.showGhNhDiagnostics) ...[
              const SizedBox(height: 4),
              _subHeader(context, t('config.thresholds')),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  t('config.thresholdsHint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _ThresholdField(
                      label: t('config.ghWarning'),
                      value: state.ghWarningThreshold,
                      onChanged: state.updateGhWarningThreshold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThresholdField(
                      label: t('config.ghOutlier'),
                      value: state.ghOutlierThreshold,
                      onChanged: state.updateGhOutlierThreshold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _ThresholdField(
                      label: t('config.nhWarning'),
                      value: state.nhWarningThreshold,
                      onChanged: state.updateNhWarningThreshold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ThresholdField(
                      label: t('config.nhOutlier'),
                      value: state.nhOutlierThreshold,
                      onChanged: state.updateNhOutlierThreshold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: state.continuousMode,
            onChanged: state.updateContinuousMode,
            title: Text(t('config.continuousMode')),
            subtitle: Text(t('config.continuousModeSubtitle')),
          ),
          if (state.continuousMode)
            _sliderField(
              context: context,
              label: t('config.scanInterval'),
              value: state.scanIntervalMs.toDouble(),
              min: 100,
              max: 3000,
              valueLabel: '${state.scanIntervalMs} ms',
              onChanged: (v) => state.updateScanIntervalMs(v.round()),
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
        // Force the card to span the full width like every other settings card
        // (its text content alone would otherwise shrink it to the left).
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Forespectra',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Text(
              'Developed by',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: muted,
              ),
            ),
            const SizedBox(height: 2),
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

  // ─────────────────────────────────────────────────────────────────
  // History backup / restore
  // ─────────────────────────────────────────────────────────────────

  Widget _backupCard(BuildContext context, AppState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.backup_outlined),
              title: Text(t('config.backupExport')),
              subtitle: Text(t('config.backupExportSub')),
              onTap: () => _exportBackup(context, state),
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.restore),
              title: Text(t('config.backupRestore')),
              subtitle: Text(t('config.backupRestoreSub')),
              onTap: () => _restoreBackup(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final path = await state.backupService.exportToFile();
      await Share.shareXFiles(
        [
          XFile(
            path,
            mimeType: 'application/json',
            name: p.basename(path),
          ),
        ],
        subject: 'Forespectra history backup',
      );
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t('backup.exported'))));
    } catch (error) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${t('backup.exportFailed')}: $error')),
        );
    }
  }

  Future<void> _restoreBackup(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = (picked == null || picked.files.isEmpty)
          ? null
          : picked.files.first.path;
      if (path == null) return;
      final result = await state.backupService.importFromFile(path);
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${t('backup.restored')}: ${result.measurementsAdded}',
            ),
          ),
        );
    } on FormatException {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(t('backup.invalidFile'))));
    } catch (error) {
      if (!context.mounted) return;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('${t('backup.restoreFailed')}: $error')),
        );
    }
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

/// Numeric input for a single GH/NH threshold override. Owns its controller so
/// typing is never interrupted by parent rebuilds; an empty field means
/// "use the model's built-in value" (reported back as null).
class _ThresholdField extends StatefulWidget {
  const _ThresholdField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double? value;
  final ValueChanged<double?> onChanged;

  @override
  State<_ThresholdField> createState() => _ThresholdFieldState();
}

class _ThresholdFieldState extends State<_ThresholdField> {
  late final TextEditingController _controller;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(covariant _ThresholdField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect external changes (e.g. Reset to defaults) without clobbering an
    // edit the user is in the middle of typing.
    if (!_focus.hasFocus &&
        double.tryParse(_controller.text.trim()) != widget.value) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _format(double? v) {
    if (v == null) return '';
    // Trim a trailing ".0" so 4.0 shows as "4", without an int round-trip
    // (toInt() saturates for very large doubles).
    final s = v.toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: t('config.thresholdModelDefault'),
        isDense: true,
      ),
      onChanged: (raw) {
        final trimmed = raw.trim();
        if (trimmed.isEmpty) {
          widget.onChanged(null);
          return;
        }
        final parsed = double.tryParse(trimmed);
        if (parsed != null && parsed.isFinite && parsed >= 0) {
          widget.onChanged(parsed);
        }
      },
    );
  }
}
