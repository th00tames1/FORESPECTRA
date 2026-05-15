import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/analyzer.dart';
import '../../domain/averaging.dart';
import '../../services/app_state.dart';
import '../../services/i18n.dart';
import '../widgets/spectrum_chart.dart';

class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key, this.fromScanFlow = false});

  final bool fromScanFlow;

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> {
  bool _isSaving = false;
  bool _isClosing = false;

  void _safePop() {
    if (_isClosing) return;
    _isClosing = true;
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fromScanFlow = widget.fromScanFlow;
    return Consumer<AppState>(
      builder: (context, state, _) {
        final media = MediaQuery.of(context);
        final baseBottomPadding = fromScanFlow ? 24.0 : 96.0;
        final bottomInset = media.padding.bottom + baseBottomPadding;
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            bottom: true,
            child: LayoutBuilder(
            builder: (context, constraints) {
              final isTabletLayout = constraints.maxWidth >= 720;
              final useSpreadLayout =
                  isTabletLayout && media.viewInsets.bottom == 0;
              final contentMaxWidth = isTabletLayout ? 760.0 : double.infinity;
              final contentAlignment = Alignment.topCenter;
              final availableHeight = constraints.maxHeight - 20 - bottomInset;
              final minHeight = availableHeight > 0 ? availableHeight : 0.0;

              final topSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t('results.title'),
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ],
              );

              final acquired = state.acquiredSpectra;
              final hasMultiple = acquired.length > 1;
              final middleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SpectrumChart(
                    spectrum: state.latestSpectrum,
                    title: hasMultiple
                        ? '${t('results.averagedSpectrum')} (${acquired.length} ${t('results.scans')}, ${state.averagingMethod.label})'
                        : t('results.spectrumPreview'),
                    axisUnit: state.spectrumAxisUnit,
                    overlays: hasMultiple ? acquired : const [],
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        t('results.fadedLinesHint'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: _AnalysisSummaryCard(
                      results: state.latestAnalysisResults,
                      showDiagnostics: state.showGhNhDiagnostics,
                    ),
                  ),
                ],
              );

              final canInteract = !_isSaving && !_isClosing;
              final actionSection = fromScanFlow
                  ? Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: canInteract
                                ? () {
                                    state.discardLatest();
                                    _safePop();
                                  }
                                : null,
                            child: Text(t('common.cancel')),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed:
                                state.latestSpectrum == null || !canInteract
                                ? null
                                : () async {
                                    final hasNames =
                                        state.materialName.trim().isNotEmpty &&
                                        state.sampleName.trim().isNotEmpty;
                                    String materialOut = state.materialName;
                                    String sampleOut = state.sampleName;
                                    if (!hasNames) {
                                      final confirm =
                                          await _showSaveConfirmDialog(
                                            context,
                                            state,
                                          );
                                      if (confirm == null || !mounted) {
                                        return;
                                      }
                                      materialOut = confirm.material;
                                      sampleOut = confirm.sample;
                                    }
                                    setState(() => _isSaving = true);
                                    state.updateMaterialName(
                                      materialOut,
                                      notify: false,
                                    );
                                    state.updateSampleName(
                                      sampleOut,
                                      notify: false,
                                    );
                                    try {
                                      await state.saveSession();
                                    } finally {
                                      if (mounted) {
                                        setState(() => _isSaving = false);
                                      }
                                    }
                                    if (!context.mounted) {
                                      return;
                                    }
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    _safePop();
                                    messenger
                                      ..hideCurrentSnackBar()
                                      ..showSnackBar(
                                        SnackBar(
                                          content: Text(t('common.saved')),
                                          duration: const Duration(
                                            milliseconds: 1500,
                                          ),
                                        ),
                                      );
                                  },
                            child: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                    ),
                                  )
                                : Text(t('common.save')),
                          ),
                        ),
                      ],
                    )
                  : const SizedBox.shrink();

              final content = useSpreadLayout
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        topSection,
                        SizedBox(height: (minHeight * 0.08).clamp(18.0, 40.0)),
                        middleSection,
                        if (fromScanFlow) ...[
                          SizedBox(
                            height: (minHeight * 0.06).clamp(14.0, 32.0),
                          ),
                          actionSection,
                        ],
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        topSection,
                        const SizedBox(height: 16),
                        middleSection,
                        if (fromScanFlow) ...[
                          const SizedBox(height: 16),
                          actionSection,
                        ],
                      ],
                    );

              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: Align(
                    alignment: contentAlignment,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: content,
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

  Future<_SaveConfirmResult?> _showSaveConfirmDialog(
    BuildContext context,
    AppState state,
  ) async {
    var material = state.materialName;
    var sample = state.sampleName;
    final result = await showDialog<_SaveConfirmResult>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(t('results.confirmSave')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: material,
                onChanged: (value) => material = value,
                decoration: InputDecoration(labelText: t('scan.material')),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: sample,
                onChanged: (value) => sample = value,
                decoration: InputDecoration(labelText: t('scan.sample')),
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
                _SaveConfirmResult(
                  material: material.trim(),
                  sample: sample.trim(),
                ),
              ),
              child: Text(t('common.save')),
            ),
          ],
        );
      },
    );
    return result;
  }
}

class _SaveConfirmResult {
  const _SaveConfirmResult({required this.material, required this.sample});

  final String material;
  final String sample;
}

class _AnalysisSummaryCard extends StatelessWidget {
  const _AnalysisSummaryCard({
    required this.results,
    required this.showDiagnostics,
  });

  final List<AnalysisResult> results;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t('results.analysis'),
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (results.isEmpty)
              Text(
                t('results.noModel'),
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              ...results.map((result) {
                final diagnostics = showDiagnostics
                    ? result.diagnosticsSummary
                    : '';
                final text = diagnostics.isEmpty
                    ? '${result.label}: ${result.displayValue}'
                    : '${result.label}: ${result.displayValue} ($diagnostics)';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
