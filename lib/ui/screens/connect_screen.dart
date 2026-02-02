import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../theme/app_theme.dart';

class ConnectScreen extends StatelessWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isConnected = state.isConnected;
        final isConnecting = state.isConnecting;
        final title = isConnected
            ? 'ONLINE'
            : isConnecting
                ? 'CONNECTING...'
                : 'INITIALIZE';
        final subtitle = isConnected
            ? 'Ready to scan'
            : isConnecting
                ? 'Looking for your device'
                : 'Tap to link with the spectrometer';
        return SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minSide = MediaQuery.of(context).size.shortestSide;
              final buttonSize = (minSide * 0.55).clamp(180.0, 220.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('OSU Spectral',
                                  style: Theme.of(context).textTheme.titleLarge),
                              IconButton(
                                onPressed: () => _showDeviceSheet(context, state),
                                icon: const Icon(Icons.settings_suggest),
                              ),
                            ],
                          ),
                          Text('Oregon State University',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.muted,
                                  )),
                        ],
                      ),
                      Column(
                        children: [
                          Center(
                            child: GestureDetector(
                              onTap: isConnecting
                                  ? null
                                  : (isConnected ? state.disconnect : state.connect),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: buttonSize,
                                width: buttonSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                color: isConnected
                                    ? AppTheme.accent
                                    : Colors.transparent,
                                  border: Border.all(
                                    color: isConnected
                                        ? AppTheme.accent
                                        : Colors.white.withValues(alpha: 0.25),
                                    width: 2.5,
                                  ),
                                  boxShadow: isConnected
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.accent.withValues(alpha: 0.4),
                                            blurRadius: 40,
                                            spreadRadius: 6,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isConnected
                                            ? Icons.power_settings_new
                                            : Icons.power_outlined,
                                        size: 48,
                                        color: isConnected ? Colors.white : AppTheme.muted,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              letterSpacing: 1.2,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.muted,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(
                                    isConnected ? Icons.check_circle : Icons.info_outline,
                                    color: isConnected ? AppTheme.success : AppTheme.warning,
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
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => _showDeviceSheet(context, state),
                            child: const Text('Change device'),
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showDeviceSheet(BuildContext context, AppState state) {
    final controller = TextEditingController(text: state.currentIp);
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Device Address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '192.168.137.2',
                  labelText: 'IP address',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: USB 192.168.137.2 • Direct 192.168.144.2',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.muted,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        state.currentIp = controller.text.trim();
                        Navigator.pop(context);
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
