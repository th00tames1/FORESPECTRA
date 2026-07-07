import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/averaging.dart';
import '../../services/app_state.dart';
import '../../services/i18n.dart';
import 'analyze_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/conn_chip.dart';
import '../widgets/session_card.dart';

class AcquireScreen extends StatefulWidget {
  const AcquireScreen({super.key});

  @override
  State<AcquireScreen> createState() => _AcquireScreenState();
}

class _AcquireScreenState extends State<AcquireScreen> {
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _sampleController = TextEditingController();
  final FocusNode _materialFocus = FocusNode();
  final FocusNode _sampleFocus = FocusNode();
  bool _resultScreenOpen = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    final state = context.read<AppState>();
    _materialController.text = state.materialName;
    _sampleController.text = state.sampleName;
    _initialized = true;
  }

  @override
  void dispose() {
    _materialController.dispose();
    _sampleController.dispose();
    _materialFocus.dispose();
    _sampleFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Don't overwrite while the user is typing - batch-mode sample
        // bumps come through here too and would jump the caret otherwise.
        if (!_sampleFocus.hasFocus &&
            _sampleController.text != state.sampleName) {
          _sampleController.value = TextEditingValue(
            text: state.sampleName,
            selection: TextSelection.collapsed(
              offset: state.sampleName.length,
            ),
          );
        }
        if (!_materialFocus.hasFocus &&
            _materialController.text != state.materialName) {
          _materialController.value = TextEditingValue(
            text: state.materialName,
            selection: TextSelection.collapsed(
              offset: state.materialName.length,
            ),
          );
        }
        final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
        final minSide = MediaQuery.of(context).size.shortestSide;
        final buttonSize = (minSide * 0.58).clamp(190.0, 240.0);
        final isBusy =
            state.isScanning ||
            state.isBackgrounding ||
            state.isVerifyingConnection;
        final canScanTap = (state.isConnected || state.testMode) && !isBusy;
        final canCapture = canScanTap && state.hasBackground;
        final statusColor = state.isConnected
            ? AppTheme.success
            : AppTheme.warning;

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            bottom: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTabletLayout = constraints.maxWidth >= 720;
                // On a tablet with the keyboard down there is a lot of vertical
                // room, so vertically CENTER the content instead of letting it
                // cluster at the top. When the keyboard is up (or on a phone)
                // we top-align; the surrounding SingleChildScrollView then
                // scrolls the focused field into view, so the keyboard can
                // never cause a layout overflow.
                final contentAlignment = (isTabletLayout && keyboardInset == 0)
                    ? Alignment.center
                    : Alignment.topCenter;
                final contentMaxWidth = isTabletLayout ? 640.0 : double.infinity;
                const outerVerticalPadding = 40.0;
                final availableHeight =
                    constraints.maxHeight - keyboardInset - outerVerticalPadding;
                final minHeight = availableHeight > 0 ? availableHeight : 0.0;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: AnimatedPadding(
                    duration: const Duration(milliseconds: 160),
                    padding: EdgeInsets.only(bottom: keyboardInset),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: minHeight),
                        child: Align(
                          alignment: contentAlignment,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: contentMaxWidth),
                            child: _buildContent(
                              context,
                              state,
                              buttonSize,
                              canScanTap,
                              canCapture,
                              isBusy,
                              statusColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppState state,
    double buttonSize,
    bool canScanTap,
    bool canCapture,
    bool isBusy,
    Color statusColor,
  ) {
    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t('scan.title'),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            ConnChip(connected: state.isConnected, testMode: state.testMode),
          ],
        ),
        if (state.testMode && !state.isConnected) ...[
          const SizedBox(height: 12),
          _TestModeBanner(onExit: state.exitTestMode),
        ],
        const SizedBox(height: 16),
        SessionCard(
          rows: [
            SessionRow(
              icon: Icons.layers_outlined,
              label: t('scan.reference'),
              value: state.hasBackground
                  ? t('scan.refSet')
                  : t('scan.referenceNotSet'),
              valueDetail:
                  state.hasBackground && state.referenceAgeLabel != null
                      ? '· ${state.referenceAgeLabel}'
                      : null,
              // Missing reference blocks scanning - flag it in red instead of
              // explaining it in a sentence.
              alert: !state.hasBackground,
              enabled: (state.isConnected || state.testMode) && !isBusy,
              onTap: state.runBackground,
            ),
            SessionRow(
              icon: Icons.psychology_alt_outlined,
              label: t('scan.analysisModels'),
              value: _modelRowValue(state),
              chevron: true,
              onTap: () => _showModelQuickSheet(context, state),
            ),
            SessionRow(
              icon: Icons.repeat,
              label: t('config.scansPerCapture'),
              value: '${state.targetScanCount}',
              valueDetail: state.targetScanCount > 1
                  ? '· ${state.averagingMethod.label}'
                  : null,
              chevron: true,
              onTap: () => state.setTab(3),
            ),
          ],
        ),
      ],
    );

    final canStopScan = state.isScanning && state.continuousMode;
    // Manual stepping (continuous off, multi-scan) mid-session: prompt the
    // next press, e.g. "SCAN 2/5".
    final manualActive = !state.continuousMode &&
        state.targetScanCount > 1 &&
        state.manualBuffer.isNotEmpty;
    final middleSection = Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: canScanTap || canStopScan
                ? () {
                    if (state.isScanning) {
                      if (state.continuousMode) state.requestStopScan();
                      return;
                    }
                    _handleScanTap(context, state);
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: buttonSize,
              width: buttonSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: canCapture ? AppTheme.accent : Colors.transparent,
                border: Border.all(
                  color: canCapture
                      ? AppTheme.accent
                      : Theme.of(context).colorScheme.outline.withValues(alpha: 0.6),
                  width: 2.5,
                ),
                boxShadow: canCapture
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 6,
                        ),
                      ]
                    : null,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        canStopScan ? Icons.stop_rounded : Icons.auto_graph,
                        size: 52,
                        color: canCapture ? Colors.white : AppTheme.muted,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            state.isScanning
                                ? (canStopScan
                                    ? '${t('scan.stop')} ${state.currentScanIndex}/${state.targetScanCount}'
                                    : (state.targetScanCount > 1
                                        ? '${state.currentScanIndex}/${state.targetScanCount}'
                                        : t('scan.scanning')))
                                : (manualActive
                                    ? '${t('scan.scan')} ${state.manualBuffer.length + 1}/${state.targetScanCount}'
                                    : t('scan.scan')),
                            // Action label: larger than titleMedium, kept at
                            // w600 with moderate tracking.
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.8,
                              color: canCapture ? Colors.white : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isBusy)
                    SizedBox(
                      height: buttonSize - 12,
                      width: buttonSize - 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          canCapture ? Colors.white : AppTheme.accent,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final bottomSection = Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _materialController,
                focusNode: _materialFocus,
                textInputAction: TextInputAction.next,
                enabled: state.hasBackground,
                decoration: InputDecoration(
                  // Uppercase specimen-label voice (no-op for Korean). Label
                  // stays small on the border; the example hint fills the
                  // empty field instead of a full-size floating label.
                  labelText: t('scan.material').toUpperCase(),
                  hintText: t('scan.materialHint'),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
                onChanged: state.updateMaterialName,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sampleController,
                focusNode: _sampleFocus,
                enabled: state.hasBackground && !state.batchModeEnabled,
                decoration: InputDecoration(
                  labelText: t('scan.sample').toUpperCase(),
                  hintText: state.batchModeEnabled
                      ? t('scan.sampleAuto')
                      : t('scan.sampleHint'),
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
                onChanged: state.updateSampleName,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Compact switch: the M3 default reads oversized next to the
            // dense fields above.
            Transform.scale(
              scale: 0.8,
              alignment: Alignment.centerLeft,
              child: Switch(
                value: state.batchModeEnabled,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: state.hasBackground
                    ? (v) => _toggleBatchMode(context, state, v)
                    : null,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              t('scan.batchMode'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            if (state.batchModeEnabled)
              Text(
                '${t('scan.next')}: ${state.sampleName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.muted,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  state.isConnected ? Icons.check_circle : Icons.info_outline,
                  color: statusColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    state.statusMessage,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        topSection,
        const SizedBox(height: 36),
        middleSection,
        const SizedBox(height: 36),
        bottomSection,
      ],
    );
  }

  Future<void> _openResultsScreen(BuildContext context) async {
    if (!mounted) {
      return;
    }
    _resultScreenOpen = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const AnalyzeScreen(fromScanFlow: true),
        ),
      );
    } finally {
      _resultScreenOpen = false;
    }
  }

  Future<void> _handleScanTap(BuildContext context, AppState state) async {
    if (!state.hasBackground) {
      await _showReferenceRequiredSheet(context, state);
      return;
    }
    final before = state.captureCount;
    await state.runSpectrum();
    if (!mounted ||
        !context.mounted ||
        _resultScreenOpen ||
        state.captureCount <= before) {
      return;
    }
    await _openResultsScreen(context);
  }

  /// Compact value for the session-card Models row: nothing selected, the
  /// model label(s) when they fit, otherwise a count.
  String _modelRowValue(AppState state) {
    final selected = state.selectedModels;
    if (selected.isEmpty) {
      return t('scan.modelNoneSelected');
    }
    if (selected.length <= 2) {
      return selected.map((m) => m.label).join(', ');
    }
    return '${selected.length} ${t('scan.modelSelectedSuffix')}';
  }

  /// Lightweight per-scan model toggle. Full details (algorithm, metrics,
  /// dataset) live in Config > Models; this sheet is just quick checkboxes.
  Future<void> _showModelQuickSheet(
    BuildContext context,
    AppState state,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (sheetContext) {
        return Consumer<AppState>(
          builder: (context, liveState, _) {
            final models = liveState.availableModels;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                20 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('scan.analysisModels'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t('scan.modelSheetSubtitle'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (models.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        t('scan.modelsNone'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.5,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final model = models[index];
                          final checked =
                              liveState.isModelSelected(model.id);
                          final algo = model.algorithm.isEmpty
                              ? (model.isClassification
                                    ? t('scan.classification')
                                    : t('scan.regression'))
                              : model.algorithm;
                          return CheckboxListTile(
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            title: Text(model.name),
                            subtitle: Text(algo),
                            onChanged: (value) => liveState
                                .toggleModelSelection(model.id, value == true),
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleBatchMode(
    BuildContext context,
    AppState state,
    bool enabled,
  ) async {
    if (!enabled) {
      state.setBatchMode(enabled: false);
      return;
    }
    final result = await showDialog<_BatchSetup>(
      context: context,
      builder: (dialogContext) {
        var prefix = state.sampleName.trim().isEmpty
            ? 'S'
            : state.sampleName.trim();
        var startStr = '1';
        return AlertDialog(
          title: Text(t('scan.batchSetupTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('scan.batchSetupBody'),
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: prefix,
                onChanged: (v) => prefix = v,
                decoration: InputDecoration(
                  labelText: t('scan.samplePrefix'),
                  hintText: t('scan.materialHint'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: startStr,
                keyboardType: TextInputType.number,
                onChanged: (v) => startStr = v,
                decoration: InputDecoration(
                  labelText: t('scan.startNumber'),
                  hintText: '1',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(t('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                _BatchSetup(
                  prefix: prefix.trim(),
                  start: int.tryParse(startStr) ?? 1,
                ),
              ),
              child: Text(t('common.start')),
            ),
          ],
        );
      },
    );
    if (result == null) return;
    state.setBatchMode(
      enabled: true,
      samplePrefix: result.prefix.isEmpty ? 'S' : result.prefix,
      startCounter: result.start,
    );
    final firstName = '${result.prefix.isEmpty ? 'S' : result.prefix}-'
        '${result.start.toString().padLeft(3, '0')}';
    state.updateSampleName(firstName);
  }

  Future<void> _showReferenceRequiredSheet(
    BuildContext context,
    AppState state,
  ) async {
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (sheetContext) {
        final safeBottom = MediaQuery.of(sheetContext).viewPadding.bottom;
        final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            20 + safeBottom + bottomInset + 72,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('scan.referenceRequiredTitle'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                t('scan.referenceRequiredBody'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.muted),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(sheetContext);
                    await state.runBackground();
                  },
                  icon: const Icon(Icons.layers),
                  label: Text(t('scan.setReference')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

}

class _BatchSetup {
  const _BatchSetup({required this.prefix, required this.start});
  final String prefix;
  final int start;
}

/// Banner shown on the Scan screen when the developer test mode (simulated
/// sensor) is active. Tapping it exits back to the Connect screen.
class _TestModeBanner extends StatelessWidget {
  const _TestModeBanner({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onExit,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.warning.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Icon(Icons.science_outlined, size: 18, color: AppTheme.warning),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  t('scan.testMode'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.close, size: 16, color: AppTheme.warning),
            ],
          ),
        ),
      ),
    );
  }
}
