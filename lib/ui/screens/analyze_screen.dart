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
              final outlierBanner = _buildOutlierBanner(
                context,
                state.latestAnalysisResults,
              );
              final middleSection = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (outlierBanner != null) ...[
                    outlierBanner,
                    const SizedBox(height: 12),
                  ],
                  SpectrumChart(
                    spectrum: state.latestSpectrum,
                    title: hasMultiple
                        ? 'Averaged spectrum (${acquired.length} scans, ${state.averagingMethod.label})'
                        : 'Spectrum Preview',
                    axisUnit: state.spectrumAxisUnit,
                    overlays: hasMultiple ? acquired : const [],
                  ),
                  if (hasMultiple) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        'Faded lines: individual scans. Bold line: averaged.',
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
                                        const SnackBar(
                                          content: Text('Saved'),
                                          duration: Duration(
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

  /// Returns a prominent warning banner when any analysis result is flagged as
  /// outlier or warning by the GH/NH diagnostics. Returns null otherwise.
  Widget? _buildOutlierBanner(
    BuildContext context,
    List<AnalysisResult> results,
  ) {
    if (results.isEmpty) return null;
    bool isOutlier = false;
    bool isWarning = false;
    final flagged = <String>[];
    for (final r in results) {
      for (final level in [r.ghLevel, r.nhLevel]) {
        if (level == AnalysisResult.levelOutlier) {
          isOutlier = true;
          flagged.add(r.label);
        } else if (level == AnalysisResult.levelWarning) {
          isWarning = true;
          if (!flagged.contains(r.label)) flagged.add(r.label);
        }
      }
    }
    if (!isOutlier && !isWarning) return null;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isOutlier
        ? const Color(0xFFD03020)
        : const Color(0xFFC97A0F);
    final bg = isOutlier
        ? (isDark ? const Color(0xFF3A1A18) : const Color(0xFFFBE4E4))
        : (isDark ? const Color(0xFF3A2E14) : const Color(0xFFFAF3D9));
    final title = isOutlier
        ? 'Outlier detected'
        : 'Possible drift';
    final body = isOutlier
        ? 'This measurement is unusual versus the calibration set '
              '(${flagged.join(", ")}). Consider re-scanning or '
              'verifying the sample.'
        : 'This measurement is borderline (${flagged.join(", ")}). '
              'Result may be less reliable.';

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isOutlier ? Icons.error_outline : Icons.warning_amber_outlined,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
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
          title: const Text('Confirm Save'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: material,
                onChanged: (value) => material = value,
                decoration: const InputDecoration(labelText: 'Material name'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                initialValue: sample,
                onChanged: (value) => sample = value,
                decoration: const InputDecoration(labelText: 'Sample name'),
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
                _SaveConfirmResult(
                  material: material.trim(),
                  sample: sample.trim(),
                ),
              ),
              child: const Text('Save'),
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
            Text('Analysis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (results.isEmpty)
              Text(
                'No model applied. Select models from the Model button on Scan tab.',
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
