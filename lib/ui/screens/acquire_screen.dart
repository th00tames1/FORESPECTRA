import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import 'analyze_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/spectrum_chart.dart';

class AcquireScreen extends StatefulWidget {
  const AcquireScreen({super.key});

  @override
  State<AcquireScreen> createState() => _AcquireScreenState();
}

class _AcquireScreenState extends State<AcquireScreen> {
  final TextEditingController _materialController = TextEditingController();
  final TextEditingController _sampleController = TextEditingController();
  int _lastPromptedCapture = 0;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.captureCount > _lastPromptedCapture &&
            !state.isScanning &&
            !_resultScreenOpen) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _lastPromptedCapture = state.captureCount;
            _openResultsScreen(context);
          });
        }

        final bottomInset = MediaQuery.of(context).padding.bottom + 140;
        final minSide = MediaQuery.of(context).size.shortestSide;
        final buttonSize = (minSide * 0.58).clamp(190.0, 240.0);
        final isBusy = state.isScanning || state.isBackgrounding || state.isVerifyingConnection;
        final canCapture = state.isConnected && state.hasBackground && !isBusy;
        final statusColor = state.isConnected ? AppTheme.success : AppTheme.warning;

        return SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Scan', style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 6),
                Text(
                  'Set a reference and press Scan.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _materialController,
                        textInputAction: TextInputAction.next,
                        enabled: state.hasBackground,
                        decoration: const InputDecoration(
                          labelText: 'Material name',
                          hintText: 'e.g. Pine',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: state.updateMaterialName,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _sampleController,
                        enabled: state.hasBackground,
                        decoration: const InputDecoration(
                          labelText: 'Sample name',
                          hintText: 'e.g. Sample A',
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: state.updateSampleName,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (!state.hasBackground)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: Theme.of(context).colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Reference is required before scanning. Tap Set reference first.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (!state.hasBackground) const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: state.isConnected && !isBusy ? state.runBackground : null,
                    icon: const Icon(Icons.layers),
                    label: Text(state.hasBackground ? 'Reference set' : 'Set reference'),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: GestureDetector(
                    onTap: canCapture ? state.runSpectrum : null,
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
                                state.isScanning ? 'SCANNING...' : 'SCAN',
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
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    state.hasBackground
                        ? 'Reference ready for spectrum capture.'
                        : 'Set a reference before capturing a spectrum.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                        ),
                  ),
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
                const SizedBox(height: 16),
                SpectrumChart(
                  spectrum: state.latestSpectrum,
                  title: '',
                ),
              ],
            ),
          ),
        );
      },
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
}
