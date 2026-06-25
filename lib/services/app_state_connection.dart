part of 'app_state.dart';

// ── Connection / discovery concern ────────────────────────────────────
// Sensor connect/disconnect, app-lifecycle reconnection, subnet sweep
// discovery, and the IP/subnet helpers that back them.

const List<String> _defaultKnownIps = [
  '10.92.71.8',
  '10.13.199.8',
];
final RegExp _ipv4Pattern = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$');

extension AppStateConnection on AppState {
  Future<void> forgetSavedSensors() async {
    try {
      await dataStore.clearDevices();
    } catch (_) {
      // Best-effort wipe - fall through to in-memory cleanup regardless.
    }
    _recentIps = const [];
    discoveredSensors = const [];
    statusMessage = 'Saved sensors cleared';
    notifyUi();
  }

  Future<void> disconnectForLifecycle() async {
    if (_isLifecycleDisconnecting || _disposed) {
      return;
    }
    _isLifecycleDisconnecting = true;

    _connectDelayTimer?.cancel();
    _cancelDiscovery(notify: false);
    try {
      await client.disconnect();
    } catch (_) {
      // Best-effort close only.
    }

    isConnected = false;
    isConnecting = false;
    isVerifyingConnection = false;
    isBackgrounding = false;
    isScanning = false;
    manualBuffer = const [];
    _syncReferenceFromCurrentIp();
    showConnectScreen = true;
    statusMessage = 'Paused. Reconnecting when app resumes...';

    _isLifecycleDisconnecting = false;
    if (!_disposed) {
      notifyUi();
    }
  }

  Future<void> reconnectAfterResume() async {
    if (_disposed || _isLifecycleDisconnecting) {
      return;
    }
    if (currentIp.trim().isEmpty) {
      return;
    }

    statusMessage = 'Reconnecting to sensor...';
    notifyUi();
    await connect(preferredIp: currentIp, fallbackToKnown: true);
  }

  Future<void> connect({
    String? preferredIp,
    bool fallbackToKnown = false,
  }) async {
    _cancelDiscovery(notify: false);
    isConnecting = true;
    statusMessage = 'Connecting...';
    _connectDelayTimer?.cancel();
    showConnectScreen = true;
    notifyUi();
    try {
      await _waitForDiscoveryDrain();
      client.sendLengthPrefix = sendLengthPrefix;
      final attempts = await _connectionAttempts(
        preferredIp: preferredIp,
        fallbackToKnown: fallbackToKnown,
      );

      Exception? lastError;
      for (final ip in attempts) {
        try {
          await client.disconnect();
          await client.connect(ip, timeout: const Duration(seconds: 4));
          isConnected = true;
          testMode = false;
          scanTabTapCount = 0;
          currentIp = ip;
          _syncReferenceFromCurrentIp();
          backgroundSpectrum = null;
          latestSpectrum = null;
          _cancelDiscovery(notify: false);
          statusMessage = 'Connected (verifying...)';
          isVerifyingConnection = true;
          setTab(0);
          _startConnectDelay();
          _registerDiscoveredSensor(
            DiscoveredSensor(ip: ip, verified: true, fromHistory: true),
            notify: false,
          );
          _reconnectOnResume = false;
          isConnecting = false;
          notifyUi();
          unawaited(_verifyDevice());
          return;
        } catch (error) {
          lastError = error is Exception ? error : Exception(error.toString());
        }
      }
      throw lastError ?? Exception('Unable to connect');
    } catch (error) {
      statusMessage = 'Connection failed: $error';
      isConnected = false;
      showConnectScreen = true;
      _triggerSensorPickerPrompt(startDiscovery: true);
      setTab(0);
    } finally {
      if (isConnecting) {
        isConnecting = false;
        notifyUi();
      }
    }
  }

  void _startConnectDelay() {
    _connectDelayTimer?.cancel();
    _connectDelayTimer = Timer(const Duration(seconds: 2), () {
      showConnectScreen = false;
      if (isConnected) {
        setTab(1);
        return;
      }
      notifyUi();
    });
  }

  Future<void> _verifyDevice() async {
    const boardTimeout = Duration(seconds: 6);
    const idTimeout = Duration(seconds: 6);
    isVerifyingConnection = true;
    notifyUi();
    try {
      try {
        final board = await client.checkBoard(timeout: boardTimeout);
        statusMessage = board == 0 || board == 1
            ? 'Connected'
            : 'Connected (board status $board)';
        notifyUi();
      } catch (_) {
        statusMessage = 'Connected (verify timeout)';
        notifyUi();
        return;
      }

      try {
        final id = (await client.readModuleId(timeout: idTimeout)).trim();
        moduleId = id.isEmpty ? null : id;
        if (moduleId != null) {
          await dataStore.upsertDevice(
            id: moduleId!,
            name: 'Si-NIR',
            ip: currentIp,
          );
          await _refreshKnownIps();
          _registerDiscoveredSensor(
            DiscoveredSensor(
              ip: currentIp,
              moduleId: moduleId,
              verified: true,
              fromHistory: true,
            ),
            notify: false,
          );
        }
      } catch (_) {
        statusMessage = 'Connected (ID unavailable)';
      }
    } finally {
      isVerifyingConnection = false;
      notifyUi();
    }
  }

  Future<void> disconnect() async {
    _reconnectOnResume = false;
    _connectDelayTimer?.cancel();
    _cancelDiscovery(notify: false);
    await client.disconnect();
    isConnected = false;
    isVerifyingConnection = false;
    _syncReferenceFromCurrentIp();
    isBackgrounding = false;
    isScanning = false;
    manualBuffer = const [];
    showConnectScreen = true;
    setTab(0);
    statusMessage = 'Disconnected';
    notifyUi();
  }

  void setCurrentIp(String value, {bool notify = true}) {
    final ip = value.trim();
    if (ip.isEmpty) {
      return;
    }
    currentIp = ip;
    _syncReferenceFromCurrentIp();
    _registerDiscoveredSensor(
      DiscoveredSensor(ip: ip, verified: false, fromHistory: true),
      notify: false,
    );
    if (notify) {
      notifyUi();
    }
  }

  Future<void> connectToSensor(DiscoveredSensor sensor) async {
    _cancelDiscovery(notify: false);
    setCurrentIp(sensor.ip, notify: false);
    await connect(preferredIp: sensor.ip, fallbackToKnown: false);
  }

  /// True when there is at least one sensor in the list worth trying to
  /// connect to (discovered now or remembered from a previous session).
  bool get hasConnectableDevice => discoveredSensors.isNotEmpty;

  /// Connect to the best currently-reachable sensor without making the user
  /// pick a specific row: prefer a verified discovered sensor, then any other
  /// listed sensor, then fall back through the known/recent IPs.
  Future<void> connectToBestAvailable() async {
    _cancelDiscovery(notify: false);
    String? preferred;
    for (final sensor in discoveredSensors) {
      if (sensor.verified) {
        preferred = sensor.ip;
        break;
      }
    }
    preferred ??=
        discoveredSensors.isNotEmpty ? discoveredSensors.first.ip : null;
    await connect(preferredIp: preferred, fallbackToKnown: true);
  }

  Future<void> discoverSensors() async {
    if (isDiscovering || isConnecting || isConnected) {
      return;
    }

    final scanId = ++_discoveryRunId;
    final completion = Completer<void>();
    _activeDiscoveryCompletion = completion;

    isDiscovering = true;
    statusMessage = 'Searching for hotspot devices...';
    notifyUi();

    try {
      // Kick mDNS off in parallel with the subnet sweep - until the firmware
      // advertises, this never resolves anything, so we don't block on it.
      // Once it returns empty/throws, skip it for the rest of the session.
      final mdnsFuture = _mdnsAvailable
          ? discoverViaMdns().catchError((_) => <String>[])
          : Future<List<String>>.value(const []);
      unawaited(mdnsFuture.then((ips) {
        if (ips.isEmpty) {
          _mdnsAvailable = false;
          return;
        }
        for (final ip in ips) {
          _registerDiscoveredSensor(
            DiscoveredSensor(ip: ip, verified: false, fromHistory: false),
            notify: false,
          );
        }
        notifyUi();
      }));

      final targets = await _discoveryTargets();
      if (targets.isEmpty) {
        statusMessage = 'No subnet targets found';
        return;
      }

      final foundByIp = <String, DiscoveredSensor>{
        for (final sensor in discoveredSensors) sensor.ip: sensor,
      };

      var cursor = 0;
      String? nextTarget() {
        if (scanId != _discoveryRunId || isConnected || isConnecting) {
          return null;
        }
        if (cursor >= targets.length) {
          return null;
        }
        final ip = targets[cursor];
        cursor += 1;
        return ip;
      }

      Future<void> worker() async {
        while (true) {
          final ip = nextTarget();
          if (ip == null) {
            return;
          }

          final probed = await _probeSensor(ip);
          if (scanId != _discoveryRunId || isConnected || isConnecting) {
            return;
          }
          if (probed == null) {
            continue;
          }

          final existing = foundByIp[ip];
          final shouldReplace =
              existing == null ||
              (!existing.verified && probed.verified) ||
              (existing.moduleId == null && probed.moduleId != null);

          if (!shouldReplace) {
            continue;
          }

          foundByIp[ip] = probed;
          discoveredSensors = _sortedSensors(foundByIp.values.toList());
          notifyUi();
        }
      }

      final workerCount = targets.length < 24 ? targets.length : 24;
      if (workerCount > 0) {
        await Future.wait(List.generate(workerCount, (_) => worker()));
      }

      discoveredSensors = _sortedSensors(foundByIp.values.toList());
      final newCount = discoveredSensors
          .where((sensor) => !sensor.fromHistory)
          .length;
      statusMessage = newCount == 0
          ? 'No new devices found. Select a known IP.'
          : 'Found $newCount device(s). Select one to connect.';
    } catch (error) {
      statusMessage = 'Device search failed: $error';
    } finally {
      if (!completion.isCompleted) {
        completion.complete();
      }
      if (identical(_activeDiscoveryCompletion, completion)) {
        _activeDiscoveryCompletion = null;
      }
      if (scanId == _discoveryRunId) {
        isDiscovering = false;
        notifyUi();
      }
    }
  }

  Future<void> loadKnownDevices() async {
    await _refreshKnownIps();
    final knownIps = _orderedUnique([..._recentIps, ..._defaultKnownIps]);
    if (knownIps.isEmpty) {
      return;
    }

    currentIp = knownIps.first;
    _syncReferenceFromCurrentIp();
    discoveredSensors = _sortedSensors(
      knownIps
          .map(
            (ip) =>
                DiscoveredSensor(ip: ip, verified: false, fromHistory: true),
          )
          .toList(),
    );
    notifyUi();
  }

  Future<void> _refreshKnownIps() async {
    try {
      _recentIps = await dataStore.listRecentDeviceIps(limit: 20);
    } catch (_) {
      _recentIps = const [];
    }
  }

  Future<List<String>> _connectionAttempts({
    String? preferredIp,
    bool fallbackToKnown = true,
  }) async {
    await _refreshKnownIps();
    final preferred = preferredIp?.trim() ?? currentIp;
    if (!fallbackToKnown) {
      return _orderedUnique([preferred]);
    }
    // Fold currently-discovered sensors into the fallback chain (verified
    // ones first) so a freshly-found device at an unknown IP is auto-tried.
    final discovered = <String>[
      for (final sensor in discoveredSensors)
        if (sensor.verified) sensor.ip,
      for (final sensor in discoveredSensors) sensor.ip,
    ];
    return _orderedUnique([
      preferred,
      ...discovered,
      ..._recentIps,
      ..._defaultKnownIps,
    ]);
  }

  Future<List<String>> _discoveryTargets() async {
    await _refreshKnownIps();
    final seeds = _orderedUnique([
      currentIp,
      ..._recentIps,
      ..._defaultKnownIps,
    ]);

    final targets = _orderedUnique(seeds);
    final subnets = <String>[];

    // 1. Auto-detect subnets from local non-cellular interfaces (highest priority).
    //    Handles the case where the phone is hosting a hotspot on an unknown
    //    subnet (e.g. 10.96.177.x) or has joined someone else's hotspot.
    for (final subnet in await _detectLocalSubnets()) {
      if (!subnets.contains(subnet)) {
        subnets.add(subnet);
      }
    }

    // 2. Add subnets from current/recent/known IPs, restricted to RFC1918 ranges.
    for (final ip in seeds) {
      final subnet = _subnetOf(ip);
      if (subnet == null || subnets.contains(subnet)) {
        continue;
      }
      if (_isPrivateIpv4(ip)) {
        subnets.add(subnet);
      }
    }

    if (subnets.isEmpty) {
      final currentSubnet = _subnetOf(currentIp);
      if (currentSubnet != null) {
        subnets.add(currentSubnet);
      }
    }

    final cappedSubnets = subnets.take(3).toList();
    for (final subnet in cappedSubnets) {
      for (var host = 1; host <= 254; host += 1) {
        targets.add('$subnet.$host');
      }
    }

    return _orderedUnique(targets);
  }

  Future<List<String>> _detectLocalSubnets() async {
    final detected = <String>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      // Exclude cellular/PPP interfaces - we only want Wi-Fi / Wi-Fi tether / USB tether.
      final cellularPattern = RegExp(
        r'(rmnet|ccmni|pdp_ip|ppp|cellular)',
        caseSensitive: false,
      );
      for (final iface in interfaces) {
        if (cellularPattern.hasMatch(iface.name)) {
          continue;
        }
        for (final addr in iface.addresses) {
          final ip = addr.address;
          if (!_isValidIpv4(ip) || !_isPrivateIpv4(ip)) {
            continue;
          }
          final subnet = _subnetOf(ip);
          if (subnet != null && !detected.contains(subnet)) {
            detected.add(subnet);
          }
        }
      }
    } catch (_) {
      // Best-effort only; platform may restrict interface enumeration.
    }
    return detected;
  }

  bool _isPrivateIpv4(String value) {
    final ip = value.trim();
    if (!_isValidIpv4(ip)) {
      return false;
    }
    final parts = ip.split('.');
    final a = int.tryParse(parts[0]);
    final b = int.tryParse(parts[1]);
    if (a == null || b == null) {
      return false;
    }
    if (a == 10) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    if (a == 192 && b == 168) return true;
    return false;
  }

  Future<DiscoveredSensor?> _probeSensor(String ip) async {
    final probe = SiNirClient()..sendLengthPrefix = sendLengthPrefix;
    try {
      await probe.connect(ip, timeout: const Duration(milliseconds: 280));
      return DiscoveredSensor(
        ip: ip,
        moduleId: null,
        verified: false,
        fromHistory: false,
      );
    } catch (_) {
      return null;
    } finally {
      await probe.disconnect();
    }
  }

  void _registerDiscoveredSensor(
    DiscoveredSensor sensor, {
    bool notify = true,
  }) {
    final byIp = <String, DiscoveredSensor>{
      for (final item in discoveredSensors) item.ip: item,
    };
    final existing = byIp[sensor.ip];
    if (existing == null) {
      byIp[sensor.ip] = sensor;
    } else {
      byIp[sensor.ip] = DiscoveredSensor(
        ip: sensor.ip,
        moduleId: sensor.moduleId ?? existing.moduleId,
        verified: existing.verified || sensor.verified,
        fromHistory: existing.fromHistory && sensor.fromHistory,
      );
    }
    discoveredSensors = _sortedSensors(byIp.values.toList());
    if (notify) {
      notifyUi();
    }
  }

  List<DiscoveredSensor> _sortedSensors(List<DiscoveredSensor> sensors) {
    final sorted = [...sensors];
    sorted.sort((a, b) {
      if (a.verified != b.verified) {
        return a.verified ? -1 : 1;
      }
      if (a.fromHistory != b.fromHistory) {
        return a.fromHistory ? 1 : -1;
      }
      return a.ip.compareTo(b.ip);
    });
    return sorted;
  }

  String? _subnetOf(String ip) {
    if (!_isValidIpv4(ip)) {
      return null;
    }
    final parts = ip.split('.');
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }

  bool _isValidIpv4(String value) {
    final ip = value.trim();
    if (!_ipv4Pattern.hasMatch(ip)) {
      return false;
    }
    final parts = ip.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return false;
      }
    }
    return true;
  }

  List<String> _orderedUnique(Iterable<String> values) {
    final seen = <String>{};
    final ordered = <String>[];
    for (final raw in values) {
      final ip = raw.trim();
      if (!_isValidIpv4(ip)) {
        continue;
      }
      if (seen.add(ip)) {
        ordered.add(ip);
      }
    }
    return ordered;
  }

  void requestSensorPicker({bool startDiscovery = false}) {
    _triggerSensorPickerPrompt(startDiscovery: startDiscovery);
    notifyUi();
  }

  void _triggerSensorPickerPrompt({bool startDiscovery = false}) {
    sensorPickerPromptSignal += 1;
    if (startDiscovery) {
      Future.microtask(() {
        unawaited(discoverSensors());
      });
    }
  }

  void _cancelDiscovery({bool notify = true}) {
    _discoveryRunId += 1;
    if (!isDiscovering) {
      return;
    }
    isDiscovering = false;
    if (notify) {
      notifyUi();
    }
  }

  Future<void> _waitForDiscoveryDrain() async {
    final completion = _activeDiscoveryCompletion;
    if (completion == null) {
      return;
    }
    try {
      await completion.future.timeout(const Duration(milliseconds: 900));
    } catch (_) {
      // Best-effort wait only.
    }
  }
}
