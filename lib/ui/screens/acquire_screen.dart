import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import 'analyze_screen.dart';
import '../theme/app_theme.dart';

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
        // Don't overwrite while the user is typing — batch-mode sample
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
        final canScanTap = state.isConnected && !isBusy;
        final canCapture = canScanTap && state.hasBackground;
        final statusColor = state.isConnected
            ? AppTheme.success
            : AppTheme.warning;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'scan_model_fab',
            onPressed: () => _showModelPickerSheet(context, state),
            icon: const Icon(Icons.psychology_alt_outlined),
            label: const Text('Model'),
          ),
          body: SafeArea(
            bottom: true,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isTabletLayout = constraints.maxWidth >= 720;
                final useSpreadLayout = isTabletLayout && keyboardInset == 0;
                final contentAlignment = Alignment.topCenter;
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
                              useSpreadLayout,
                              minHeight,
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
    bool useSpreadLayout,
    double availableHeight,
  ) {
    final topSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Scan', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: state.isConnected && !isBusy ? state.runBackground : null,
            icon: const Icon(Icons.layers),
            label: Text(
              state.hasBackground
                  ? (state.referenceAgeLabel != null
                        ? 'Reference set (${state.referenceAgeLabel})'
                        : 'Reference set')
                  : 'Set reference',
            ),
          ),
        ),
      ],
    );

    final middleSection = Column(
      children: [
        Center(
          child: GestureDetector(
            onTap: canScanTap ? () => _handleScanTap(context, state) : null,
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
                        Icons.auto_graph,
                        size: 52,
                        color: canCapture ? Colors.white : AppTheme.muted,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        state.isScanning
                            ? (state.targetScanCount > 1
                                ? '${state.currentScanIndex}/${state.targetScanCount}'
                                : 'SCANNING...')
                            : 'SCAN',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          letterSpacing: 1.2,
                          color: canCapture ? Colors.white : null,
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
                decoration: const InputDecoration(
                  labelText: 'Material name',
                  hintText: 'e.g. Pine',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  labelText: 'Sample name',
                  hintText: state.batchModeEnabled
                      ? 'Auto-generated'
                      : 'e.g. Sample A',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
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
            Switch(
              value: state.batchModeEnabled,
              onChanged: state.hasBackground
                  ? (v) => _toggleBatchMode(context, state, v)
                  : null,
            ),
            const SizedBox(width: 4),
            Text(
              'Batch mode',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            if (state.batchModeEnabled)
              Text(
                'Next: ${state.sampleName}',
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

    if (useSpreadLayout) {
      final upperGap = (availableHeight * 0.10).clamp(36.0, 64.0);
      final lowerGap = (availableHeight * 0.08).clamp(32.0, 56.0);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          topSection,
          SizedBox(height: upperGap),
          middleSection,
          SizedBox(height: lowerGap),
          bottomSection,
        ],
      );
    }

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
          title: const Text('Start batch mode'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Material stays fixed; sample auto-increments after each save.',
                style: Theme.of(dialogContext).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: prefix,
                onChanged: (v) => prefix = v,
                decoration: const InputDecoration(
                  labelText: 'Sample prefix',
                  hintText: 'e.g. Pine',
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: startStr,
                keyboardType: TextInputType.number,
                onChanged: (v) => startStr = v,
                decoration: const InputDecoration(
                  labelText: 'Start number',
                  hintText: '1',
                ),
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
                _BatchSetup(
                  prefix: prefix.trim(),
                  start: int.tryParse(startStr) ?? 1,
                ),
              ),
              child: const Text('Start'),
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
                'Reference is required before scanning.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Set reference to proceed.',
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
                  label: const Text('Set reference'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showModelPickerSheet(
    BuildContext context,
    AppState state,
  ) async {
    final selected = Set<String>.from(state.selectedModelIds);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final models = state.availableModels;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                20 + MediaQuery.of(context).viewPadding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Apply Models',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select models to run after each scan.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  if (models.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 12),
                      child: Text(
                        'No bundled models available.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.45,
                      ),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: models.length,
                        itemBuilder: (context, index) {
                          final model = models[index];
                          final checked = selected.contains(model.id);
                          return CheckboxListTile(
                            value: checked,
                            contentPadding: EdgeInsets.zero,
                            title: Text(model.name),
                            subtitle: Text(
                              '${model.label} • ${model.isClassification ? 'Classification' : 'Regression'}',
                            ),
                            onChanged: (value) {
                              setModalState(() {
                                if (value == true) {
                                  selected.add(model.id);
                                } else {
                                  selected.remove(model.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(selected.clear);
                          },
                          child: const Text('Clear all'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            state.setSelectedModelIds(selected);
                            Navigator.pop(sheetContext);
                          },
                          icon: const Icon(Icons.check),
                          label: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
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
