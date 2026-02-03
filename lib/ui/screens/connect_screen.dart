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
          bottom: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final minSide = MediaQuery.of(context).size.shortestSide;
              final buttonSize = (minSide * 0.55).clamp(180.0, 220.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: SizedBox(
                  height: constraints.maxHeight,
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.topLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Forespectra',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                                IconButton(
                                  onPressed: () => _showDeviceSheet(context, state),
                                  icon: const Icon(Icons.settings_suggest),
                                ),
                              ],
                            ),
                            Text(
                              'OSU Advanced Forestry Systems Lab',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.muted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: isConnecting ? null : state.connect,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: buttonSize,
                                width: buttonSize,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.transparent,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    width: 2.5,
                                  ),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.power_outlined,
                                        size: 48,
                                        color: AppTheme.muted,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(letterSpacing: 1.2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Text(
                              subtitle,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.muted,
                                  ),
                            ),
                          ],
                        ),
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
      useSafeArea: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (_) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final safeBottom = MediaQuery.of(context).viewPadding.bottom;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20 + bottomInset + safeBottom + 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text('Device Address', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '10.92.71.8',
                  labelText: 'IP address',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Tip: Hotspot 10.92.71.x • USB 192.168.137.2 • Direct 192.168.144.2',
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
          ),
        );
      },
    );
  }
}
