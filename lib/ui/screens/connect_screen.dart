import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../theme/app_theme.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  int _lastPromptSignal = 0;
  bool _isSensorSheetOpen = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.sensorPickerPromptSignal != _lastPromptSignal) {
          _lastPromptSignal = state.sensorPickerPromptSignal;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _isSensorSheetOpen) {
              return;
            }
            _openSensorPickerSheet(context);
          });
        }

        final isConnected = state.isConnected;
        final isConnecting = state.isConnecting;
        final isDiscovering = state.isDiscovering;
        final isOnline = isConnected && !isConnecting;
        final ringColor = isOnline
            ? AppTheme.success
            : Colors.white.withValues(alpha: 0.25);
        final fillColor = isOnline
            ? AppTheme.success.withValues(alpha: 0.15)
            : Colors.transparent;
        final title = isConnected
            ? 'ONLINE'
            : isConnecting
                ? 'CONNECTING...'
                : 'INITIALIZE';
        final subtitle = isConnected
            ? state.isVerifyingConnection
                ? 'Connected. Verifying sensor...'
                : 'Ready to scan'
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
                                  color: fillColor,
                                  border: Border.all(
                                    color: ringColor,
                                    width: 2.5,
                                  ),
                                  boxShadow: isOnline
                                      ? [
                                          BoxShadow(
                                            color: AppTheme.success.withValues(alpha: 0.35),
                                            blurRadius: 36,
                                            spreadRadius: 2,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOnline ? Icons.check_circle_rounded : Icons.power_outlined,
                                        size: 48,
                                        color: isOnline ? AppTheme.success : AppTheme.muted,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              letterSpacing: 1.2,
                                              color: isOnline ? AppTheme.success : null,
                                            ),
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
                            const SizedBox(height: 10),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              child: isOnline
                                  ? Container(
                                      key: const ValueKey('online-pill'),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(999),
                                        color: AppTheme.success.withValues(alpha: 0.14),
                                        border: Border.all(
                                          color: AppTheme.success.withValues(alpha: 0.55),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: 16,
                                                color: AppTheme.success,
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Sensor Connected',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(color: AppTheme.success),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            state.moduleId == null
                                                ? state.currentIp
                                                : '${state.currentIp} | Module ${state.moduleId}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(color: AppTheme.muted),
                                          ),
                                        ],
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: isConnecting || isDiscovering
                                      ? null
                                      : () => state.requestSensorPicker(startDiscovery: true),
                                  icon: isDiscovering
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.radar),
                                  label: Text(
                                    isDiscovering ? 'Searching for devices...' : 'Find devices',
                                  ),
                                ),
                              ),
                            ],
                          ),
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

  Future<void> _openSensorPickerSheet(BuildContext context) async {
    _isSensorSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardTheme.color,
        builder: (_) {
          return Consumer<AppState>(
            builder: (context, state, __) {
              final sensors = state.discoveredSensors;
              final isBusy = state.isDiscovering;
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  20 + MediaQuery.of(context).viewPadding.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Device',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBusy
                          ? 'Searching hotspot network...'
                          : 'Choose a saved or discovered sensor IP.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.muted,
                          ),
                    ),
                    const SizedBox(height: 12),
                    if (sensors.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Text(
                          isBusy ? 'Searching...' : 'No devices found yet.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppTheme.muted),
                        ),
                      )
                    else
                      Container(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.45,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          color: Colors.white.withValues(alpha: 0.02),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: sensors.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                          itemBuilder: (context, index) {
                            final sensor = sensors[index];
                            final subtitleText = sensor.moduleId != null
                                ? 'Module ${sensor.moduleId}'
                                : sensor.fromHistory
                                    ? 'Saved address'
                                    : 'Reachable host';
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                sensor.verified ? Icons.sensors_outlined : Icons.history,
                                color: sensor.verified
                                    ? Theme.of(context).colorScheme.primary
                                    : AppTheme.muted,
                              ),
                              title: Text(sensor.ip),
                              subtitle: Text(subtitleText),
                              onTap: state.isConnecting
                                  ? null
                                  : () async {
                                      Navigator.pop(context);
                                      await state.connectToSensor(sensor);
                                    },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: state.isDiscovering ? null : state.discoverSensors,
                        icon: state.isDiscovering
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh),
                        label: Text(state.isDiscovering ? 'Searching...' : 'Search again'),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    } finally {
      _isSensorSheetOpen = false;
    }
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
              20 + bottomInset + safeBottom + 32,
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
                'Tip: Hotspot 10.92.71.x or 10.13.199.x • USB 192.168.137.2 • Direct 192.168.144.2',
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
                        state.setCurrentIp(controller.text.trim());
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
