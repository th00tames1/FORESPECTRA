import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/i18n.dart';
import '../theme/app_theme.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isConnected = state.isConnected;
        final isConnecting = state.isConnecting;
        final isDiscovering = state.isDiscovering;
        final isOnline = isConnected && !isConnecting;
        final outlineColor = Theme.of(context).colorScheme.outline;
        final ringColor = isOnline ? AppTheme.success : outlineColor;
        final fillColor = isOnline ? Colors.white : Colors.transparent;
        final title = isConnected
            ? t('connect.online')
            : isConnecting
                ? t('connect.connecting')
                : t('connect.initialize');
        final subtitle = isConnected
            ? state.isVerifyingConnection
                ? t('connect.verifying')
                : t('connect.readyToScan')
            : isConnecting
                ? t('connect.lookingForDevice')
                : t('connect.tapToLink');
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
                            Text(
                              'Forespectra',
                              style: Theme.of(context).textTheme.headlineMedium,
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
                            SizedBox(
                              height: 72,
                              child: Center(
                                child: AnimatedSwitcher(
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
                                                    t('connect.sensorConnected'),
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
                                                    : '${state.currentIp} | ${t('connect.module')} ${state.moduleId}',
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
                              ),
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
                                      : () async {
                                          await _openSensorPickerSheet(context);
                                        },
                                  icon: isDiscovering
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.radar),
                                  label: Text(
                                    isDiscovering
                                        ? t('connect.searching')
                                        : t('connect.findDevices'),
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
    final appState = context.read<AppState>();
    appState.discoverSensors();
    final action = await showModalBottomSheet<_SensorPickerAction>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      builder: (_) => _SensorPickerSheet(initialIp: appState.currentIp),
    );

    if (action == null) {
      return;
    }
    if (!mounted) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (!mounted) {
      return;
    }
    if (action.sensor != null) {
      await appState.connectToSensor(action.sensor!);
      return;
    }
    final manualIp = action.manualIp?.trim() ?? '';
    if (manualIp.isNotEmpty) {
      appState.setCurrentIp(manualIp);
    }
  }
}

class _SensorPickerAction {
  const _SensorPickerAction.select(this.sensor) : manualIp = null;
  const _SensorPickerAction.manual(this.manualIp) : sensor = null;

  final DiscoveredSensor? sensor;
  final String? manualIp;
}

class _SensorPickerSheet extends StatefulWidget {
  const _SensorPickerSheet({required this.initialIp});

  final String initialIp;

  @override
  State<_SensorPickerSheet> createState() => _SensorPickerSheetState();
}

class _SensorPickerSheetState extends State<_SensorPickerSheet> {
  late final TextEditingController _manualController;

  @override
  void initState() {
    super.initState();
    _manualController = TextEditingController(text: widget.initialIp);
  }

  @override
  void dispose() {
    _manualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, __) {
        final sensors = state.discoveredSensors;
        final isBusy = state.isDiscovering;
        final maxHeight = MediaQuery.of(context).size.height * 0.72;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.of(context).viewPadding.bottom,
          ),
          child: SizedBox(
            height: maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('connect.selectDevice'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  isBusy
                      ? t('connect.searchingHotspot')
                      : t('connect.choosePrompt'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                      ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _manualController,
                  decoration: InputDecoration(
                    labelText: t('connect.addDeviceAddress'),
                    hintText: '10.13.199.8',
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final ip = _manualController.text.trim();
                      if (ip.isEmpty) {
                        return;
                      }
                      Navigator.pop(
                        context,
                        _SensorPickerAction.manual(ip),
                      );
                    },
                    icon: const Icon(Icons.add_link),
                    label: Text(t('connect.addAddress')),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Builder(builder: (context) {
                    final outlineColor =
                        Theme.of(context).colorScheme.outline;
                    final softSurface = Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest;
                    return sensors.isEmpty
                        ? Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: outlineColor),
                            ),
                            child: Text(
                              isBusy
                                  ? t('connect.searchingShort')
                                  : t('connect.noDevices'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.muted),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: outlineColor),
                              color: softSurface,
                            ),
                            child: ListView.separated(
                              itemCount: sensors.length,
                              separatorBuilder: (_, __) => Divider(
                                height: 1,
                                color: outlineColor,
                              ),
                              itemBuilder: (context, index) {
                                final sensor = sensors[index];
                                final subtitleText = sensor.moduleId != null
                                    ? '${t('connect.module')} ${sensor.moduleId}'
                                    : sensor.fromHistory
                                        ? t('connect.savedAddress')
                                        : t('connect.reachableHost');
                                return ListTile(
                                  dense: true,
                                  leading: Icon(
                                    sensor.verified
                                        ? Icons.sensors_outlined
                                        : Icons.history,
                                    color: sensor.verified
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : AppTheme.muted,
                                  ),
                                  title: Text(sensor.ip),
                                  subtitle: Text(subtitleText),
                                  onTap: state.isConnecting
                                      ? null
                                      : () {
                                          Navigator.pop(
                                            context,
                                            _SensorPickerAction.select(
                                                sensor),
                                          );
                                        },
                                );
                              },
                            ),
                          );
                  }),
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
                    label: Text(state.isDiscovering
                        ? t('connect.searchingShort')
                        : t('connect.searchAgain')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
