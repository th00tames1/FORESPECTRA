part of 'app_state.dart';

// ── Scanning / measurement concern ────────────────────────────────────
// Reference (background) capture, spectrum acquisition, reference-age
// bookkeeping, batch mode, and session persistence.

extension AppStateScanning on AppState {
  Future<void> runBackground() async {
    if (!isConnected || isBackgrounding || isScanning) return;
    if (isVerifyingConnection) {
      statusMessage = 'Please wait for connection verification to finish.';
      notifyUi();
      return;
    }
    _cancelDiscovery(notify: false);
    await _waitForDiscoveryDrain();
    statusMessage = 'Running background...';
    isBackgrounding = true;
    notifyUi();
    try {
      final status = await client.runBackground(
        scanParams,
        timeout: const Duration(seconds: 20),
      );
      if (status == 0) {
        _rememberReferenceForCurrentIp(true);
        statusMessage = 'Reference captured';
      } else {
        _rememberReferenceForCurrentIp(false);
        statusMessage = 'Background error $status';
      }
    } catch (error) {
      _rememberReferenceForCurrentIp(false);
      final lost = await _handleConnectionLossIfNeeded(
        error,
        actionLabel: 'Background',
      );
      if (!lost) {
        if (error is TimeoutException) {
          statusMessage =
              'Background timeout. Check sensor power adapter/cable and try again.';
        } else {
          statusMessage = 'Background failed: $error';
        }
      }
    } finally {
      isBackgrounding = false;
    }
    notifyUi();
  }

  Future<void> runSpectrum() async {
    if (!isConnected || isScanning || isBackgrounding) return;
    _syncReferenceFromCurrentIp();
    if (!hasBackground) {
      statusMessage = 'Background required. Tap Set reference.';
      notifyUi();
      return;
    }
    final scanTotal = targetScanCount < 1 ? 1 : targetScanCount;
    isScanning = true;
    currentScanIndex = 0;
    acquiredSpectra = const [];
    final collected = <Spectrum>[];
    statusMessage = scanTotal == 1
        ? 'Scanning spectrum...'
        : 'Scanning 1/$scanTotal...';
    notifyUi();
    try {
      for (var i = 0; i < scanTotal; i++) {
        currentScanIndex = i + 1;
        if (scanTotal > 1) {
          statusMessage = 'Scanning $currentScanIndex/$scanTotal...';
          notifyUi();
        }
        final spectrum = await client.runSpectrum(
          scanParams,
          timeout: const Duration(seconds: 20),
        );
        collected.add(spectrum);
        acquiredSpectra = List.unmodifiable(collected);
      }
      latestSpectrum = collected.length == 1
          ? collected.first
          : averageSpectra(collected, method: averagingMethod);
      _runSelectedModelAnalysis(notify: false);
      statusMessage = scanTotal == 1
          ? 'Ready to Scan'
          : 'Captured $scanTotal scans (${averagingMethod.label})';
      captureCount += 1;
    } catch (error) {
      acquiredSpectra = const [];
      final lost = await _handleConnectionLossIfNeeded(
        error,
        actionLabel: 'Spectrum',
      );
      if (!lost) {
        if (_isLikelyMissingReferenceError(error)) {
          _rememberReferenceForCurrentIp(false);
          statusMessage = 'Reference required. Tap Set reference.';
        } else {
          statusMessage = 'Spectrum failed: $error';
        }
      }
    } finally {
      isScanning = false;
      currentScanIndex = 0;
    }
    notifyUi();
  }

  Future<void> runPsd() async {
    if (!isConnected) return;
    statusMessage = 'Scanning PSD...';
    notifyUi();
    try {
      latestSpectrum = await client.runPsd(
        scanParams,
        timeout: const Duration(seconds: 20),
      );
      _runSelectedModelAnalysis(notify: false);
      statusMessage = 'PSD ready';
    } catch (error) {
      final lost = await _handleConnectionLossIfNeeded(
        error,
        actionLabel: 'PSD',
      );
      if (!lost) {
        statusMessage = 'PSD failed: $error';
      }
    }
    notifyUi();
  }

  Future<void> saveSession() async {
    if (latestSpectrum == null) return;
    final measurementId = _uuid.v4();
    final position = await locationService.getCurrentPosition();
    final selectedResults = latestAnalysisResults;
    final selectedModelIdsOrdered = selectedResults
        .map((result) => result.modelId)
        .toList(growable: false);
    final resultPayload = selectedResults.isEmpty
        ? null
        : {
            'analyses': selectedResults
                .map((result) => result.toJson())
                .toList(),
            'summary': _buildAnalysisSummary(selectedResults),
          };
    final summary = resultPayload == null
        ? null
        : resultPayload['summary'] as String;

    final measurement = Measurement(
      id: measurementId,
      timestamp: DateTime.now(),
      deviceId: moduleId ?? 'unknown',
      scanTimeMs: scanParams.scanTimeMs,
      paramsJson: jsonEncode({
        'scanTimeMs': scanParams.scanTimeMs,
        'zeroPadding': scanParams.zeroPadding,
        'commonWavNum': scanParams.commonWavNum,
        'opticalGain': scanParams.opticalGain,
        'apodizationSel': scanParams.apodizationSel,
      }),
      materialName: materialName.trim().isEmpty ? null : materialName.trim(),
      sampleName: sampleName.trim().isEmpty ? null : sampleName.trim(),
      latitude: position?.latitude,
      longitude: position?.longitude,
      modelId: selectedModelIdsOrdered.isEmpty
          ? null
          : selectedModelIdsOrdered.first,
      modelIdsJson: selectedModelIdsOrdered.isEmpty
          ? null
          : jsonEncode(selectedModelIdsOrdered),
      resultsJson: resultPayload == null ? null : jsonEncode(resultPayload),
      analysisSummary: summary,
    );

    final spectrumId = _uuid.v4();
    final spectrumBlob = SpectrumBlob(
      id: spectrumId,
      measurementId: measurementId,
      kind: 'raw',
      length: latestSpectrum!.length,
      xBytes: latestSpectrum!.x.buffer.asUint8List(),
      yBytes: latestSpectrum!.y.buffer.asUint8List(),
    );

    await dataStore.saveMeasurement(measurement);
    await dataStore.saveSpectrum(spectrumBlob);
    statusMessage = 'Session saved';
    if (batchModeEnabled) {
      advanceBatchSample();
    }
    notifyUi();
  }

  void discardLatest() {
    latestSpectrum = null;
    acquiredSpectra = const [];
    latestAnalysisResults = const [];
    statusMessage = 'Scan discarded';
    notifyUi();
  }

  Future<void> loadPersistedReferenceState() async {
    try {
      final saved = await dataStore.listReferenceReadyEntries();
      // Drop entries older than 2× the current max-age window — anything
      // beyond that won't be reusable for any plausible threshold setting
      // and just clutters the table.
      final cutoff = DateTime.now().subtract(referenceMaxAge * 2);
      final usable = <String, DateTime>{
        for (final e in saved.entries)
          if (e.value.isAfter(cutoff)) e.key: e.value,
      };
      // Drop entries we pruned from DB so the table doesn't grow forever.
      for (final ip in saved.keys) {
        if (!usable.containsKey(ip)) {
          unawaited(dataStore.setReferenceReady(ip, false));
        }
      }
      _referenceSetAt
        ..clear()
        ..addAll(usable);
      _syncReferenceFromCurrentIp();
    } catch (_) {
      // Best-effort; if persistence fails, fall back to in-memory only.
    }
  }

  Future<bool> _handleConnectionLossIfNeeded(
    Object error, {
    required String actionLabel,
  }) async {
    if (!_isLikelyConnectionError(error)) {
      return false;
    }

    _reconnectOnResume = false;
    try {
      await client.disconnect();
    } catch (_) {
      // Best-effort close only.
    }

    isConnected = false;
    isConnecting = false;
    isVerifyingConnection = false;
    _syncReferenceFromCurrentIp();
    showConnectScreen = true;
    statusMessage = '$actionLabel failed: connection lost. Please reconnect.';
    return true;
  }

  bool _isLikelyConnectionError(Object error) {
    if (error is SocketException) {
      return true;
    }
    final text = error.toString().toLowerCase();
    return text.contains('not connected') ||
        text.contains('connection reset') ||
        text.contains('broken pipe') ||
        text.contains('socket') ||
        text.contains('connection aborted');
  }

  bool _isLikelyMissingReferenceError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('device returned status');
  }

  void _rememberReferenceForCurrentIp(bool ready) {
    final ip = currentIp.trim();
    if (ip.isNotEmpty) {
      if (ready) {
        _referenceSetAt[ip] = DateTime.now();
      } else {
        _referenceSetAt.remove(ip);
      }
      unawaited(dataStore.setReferenceReady(ip, ready));
    }
    hasBackground = ready;
  }

  void _syncReferenceFromCurrentIp() {
    final ip = currentIp.trim();
    if (ip.isEmpty) {
      hasBackground = false;
      return;
    }
    hasBackground = _isReferenceFresh(ip);
  }

  bool _isReferenceFresh(String ip) {
    final setAt = _referenceSetAt[ip];
    if (setAt == null) return false;
    return DateTime.now().difference(setAt) <= referenceMaxAge;
  }

  /// Returns a short label like "12 min ago" or "2 h ago" for the current
  /// IP's stored reference. Null if no reference is on file.
  String? get referenceAgeLabel {
    final setAt = _referenceSetAt[currentIp.trim()];
    if (setAt == null) return null;
    final diff = DateTime.now().difference(setAt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    final hours = diff.inMinutes / 60;
    if (hours < 10) {
      return '${hours.toStringAsFixed(1)} h ago';
    }
    return '${diff.inHours} h ago';
  }

  String _buildAnalysisSummary(List<AnalysisResult> results) {
    if (results.isEmpty) {
      return '';
    }
    return results.map((result) => result.summary).join(', ');
  }

  void updateMaterialName(String value, {bool notify = true}) {
    materialName = value;
    if (notify) {
      notifyUi();
    }
  }

  void updateSampleName(String value, {bool notify = true}) {
    sampleName = value;
    if (notify) {
      notifyUi();
    }
  }

  void setBatchMode({
    required bool enabled,
    String? samplePrefix,
    int? startCounter,
  }) {
    batchModeEnabled = enabled;
    if (samplePrefix != null) batchSamplePrefix = samplePrefix;
    if (startCounter != null) batchSampleCounter = startCounter;
    notifyUi();
  }

  /// Called after a successful save in batch mode to advance the sample id.
  /// Material name stays the same; sample becomes `{prefix}-{counter}`.
  void advanceBatchSample() {
    if (!batchModeEnabled) return;
    batchSampleCounter += 1;
    sampleName = _formatBatchSampleName();
    notifyUi();
  }

  String _formatBatchSampleName() {
    final n = batchSampleCounter.toString().padLeft(3, '0');
    final prefix = batchSamplePrefix.trim().isEmpty
        ? 'S'
        : batchSamplePrefix.trim();
    return '$prefix-$n';
  }
}
