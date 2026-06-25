part of 'app_state.dart';

// ── Scanning / measurement concern ────────────────────────────────────
// Reference (background) capture, spectrum acquisition, reference-age
// bookkeeping, batch mode, and session persistence.

extension AppStateScanning on AppState {
  /// Tap-counter for the hidden developer test mode. Ten taps on the Scan tab
  /// while disconnected enable a simulated-sensor mode.
  void registerScanTabTap() {
    if (isConnected || testMode) return;
    scanTabTapCount += 1;
    if (scanTabTapCount >= 10) {
      scanTabTapCount = 0;
      testMode = true;
      hasBackground = false;
      latestSpectrum = null;
      acquiredSpectra = const [];
      latestAnalysisResults = const [];
      statusMessage = 'Test mode: simulated sensor (no hardware).';
      setTab(1);
      notifyUi();
    }
  }

  void exitTestMode() {
    if (!testMode) return;
    testMode = false;
    scanTabTapCount = 0;
    hasBackground = false;
    latestSpectrum = null;
    acquiredSpectra = const [];
    manualBuffer = const [];
    latestAnalysisResults = const [];
    statusMessage = 'Disconnected';
    setTab(0);
    notifyUi();
  }

  Future<void> runBackground() async {
    if ((!isConnected && !testMode) || isBackgrounding || isScanning) return;
    // Re-setting the reference starts a fresh capture: drop any half-finished
    // manual session so its scans can't bleed into the next one.
    manualBuffer = const [];
    if (!isConnected && testMode) {
      // Simulated reference capture.
      isBackgrounding = true;
      statusMessage = 'Capturing reference (test mode)...';
      notifyUi();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      hasBackground = true;
      isBackgrounding = false;
      statusMessage = 'Reference captured (test mode)';
      notifyUi();
      return;
    }
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
    if (isScanning || isBackgrounding) return;
    if (!isConnected && !testMode) return;
    if (isConnected) _syncReferenceFromCurrentIp();
    if (!hasBackground) {
      statusMessage = 'Background required. Tap Set reference.';
      notifyUi();
      return;
    }
    final scanTotal = targetScanCount < 1 ? 1 : targetScanCount;
    // Continuous OFF + multi-scan => manual one-tap-per-scan stepping.
    if (!continuousMode && scanTotal > 1) {
      await _captureManualStep(scanTotal);
    } else {
      await _captureAuto(scanTotal);
    }
  }

  /// Auto capture: take all [scanTotal] scans back-to-back (as fast as the
  /// sensor responds) in a single tap. Can be stopped early.
  Future<void> _captureAuto(int scanTotal) async {
    isScanning = true;
    stopScanRequested = false;
    currentScanIndex = 0;
    acquiredSpectra = const [];
    manualBuffer = const [];
    final collected = <Spectrum>[];
    statusMessage = scanTotal == 1
        ? 'Scanning spectrum...'
        : 'Scanning 1/$scanTotal...';
    notifyUi();
    try {
      for (var i = 0; i < scanTotal; i++) {
        if (stopScanRequested) break;
        currentScanIndex = i + 1;
        if (scanTotal > 1) {
          statusMessage = 'Scanning $currentScanIndex/$scanTotal...';
          notifyUi();
        }
        final spectrum = await _acquireSpectrum();
        collected.add(spectrum);
        acquiredSpectra = List.unmodifiable(collected);
      }
      _finalizeCapture(collected);
    } catch (error) {
      acquiredSpectra = const [];
      await _handleScanError(error);
    } finally {
      isScanning = false;
      stopScanRequested = false;
      currentScanIndex = 0;
    }
    notifyUi();
  }

  /// Manual capture: take ONE scan per tap, accumulating until [scanTotal] are
  /// collected, then average + finalize. Lets the operator reposition the probe
  /// and press Scan again for each spot.
  Future<void> _captureManualStep(int scanTotal) async {
    isScanning = true;
    final stepIndex = manualBuffer.length + 1;
    currentScanIndex = stepIndex;
    statusMessage = 'Scanning $stepIndex/$scanTotal...';
    notifyUi();
    try {
      final spectrum = await _acquireSpectrum();
      final collected = [...manualBuffer, spectrum];
      if (collected.length >= scanTotal) {
        manualBuffer = const [];
        _finalizeCapture(collected);
      } else {
        manualBuffer = List.unmodifiable(collected);
        acquiredSpectra = List.unmodifiable(collected);
        statusMessage =
            'Captured ${collected.length}/$scanTotal. Press Scan for the next.';
      }
    } catch (error) {
      manualBuffer = const [];
      acquiredSpectra = const [];
      await _handleScanError(error);
    } finally {
      isScanning = false;
      currentScanIndex = 0;
    }
    notifyUi();
  }

  /// Average the collected scans into latestSpectrum, run analysis, and count
  /// the capture (so the Results screen opens). Empty input = cancelled.
  void _finalizeCapture(List<Spectrum> collected) {
    if (collected.isEmpty) {
      statusMessage = 'Scan cancelled';
      return;
    }
    final n = collected.length;
    final combined = n == 1
        ? collected.first
        : averageSpectra(collected, method: averagingMethod);
    if (combined == null) {
      // Empty/malformed data: don't count the capture or open Results.
      acquiredSpectra = const [];
      statusMessage = 'Spectrum failed: empty data';
      return;
    }
    acquiredSpectra = List.unmodifiable(collected);
    latestSpectrum = combined;
    _runSelectedModelAnalysis(notify: false);
    statusMessage = n == 1
        ? 'Ready to Scan'
        : 'Captured $n scans (${averagingMethod.label})';
    captureCount += 1;
  }

  Future<void> _handleScanError(Object error) async {
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
  }

  /// Request that an in-progress auto capture finish early. Whatever scans have
  /// been collected so far are averaged and saved as usual.
  void requestStopScan() {
    if (!isScanning || stopScanRequested) return;
    stopScanRequested = true;
    statusMessage = 'Finishing capture...';
    notifyUi();
  }

  /// Acquire one spectrum: from the real sensor when connected, otherwise a
  /// synthetic one (test mode).
  Future<Spectrum> _acquireSpectrum() async {
    if (isConnected) {
      return client.runSpectrum(
        scanParams,
        timeout: const Duration(seconds: 20),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
    return _syntheticSpectrum();
  }

  /// A plausible synthetic NIR reflectance spectrum (test mode only). Includes
  /// a baseline, a couple of absorption-like dips, and a little run-to-run
  /// noise so averaging and the GH/NH diagnostics have something to chew on.
  Spectrum _syntheticSpectrum() {
    const n = 256;
    final rnd = Random();
    final x = Float64List(n);
    final y = Float64List(n);
    for (var i = 0; i < n; i++) {
      // Wavenumber sweep ~4000–7400 cm^-1 (≈ 1350–2500 nm).
      final wavenumber = 4000.0 + (7400.0 - 4000.0) * i / (n - 1);
      final nm = 1.0e7 / wavenumber;
      var value = 0.55 +
          0.12 * sin((nm - 1400.0) / 210.0) -
          0.18 * exp(-pow((nm - 1940.0) / 60.0, 2).toDouble()) -
          0.10 * exp(-pow((nm - 2100.0) / 50.0, 2).toDouble()) +
          (rnd.nextDouble() - 0.5) * 0.01;
      if (value < 0.02) value = 0.02;
      if (value > 0.98) value = 0.98;
      x[i] = wavenumber;
      y[i] = value;
    }
    return Spectrum(x: x, y: y);
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

    // When this capture averaged multiple scans, also persist every individual
    // scan (kind 'scan') alongside the averaged 'raw' blob, so the raw repeats
    // are recoverable later. Single-scan captures need no extra rows.
    final scans = acquiredSpectra;
    if (scans.length > 1) {
      for (var i = 0; i < scans.length; i++) {
        final scan = scans[i];
        await dataStore.saveSpectrum(
          SpectrumBlob(
            id: _uuid.v4(),
            measurementId: measurementId,
            kind: 'scan_${(i + 1).toString().padLeft(2, '0')}',
            length: scan.length,
            xBytes: scan.x.buffer.asUint8List(),
            yBytes: scan.y.buffer.asUint8List(),
          ),
        );
      }
    }

    statusMessage = 'Session saved';
    if (batchModeEnabled) {
      advanceBatchSample();
    }
    notifyUi();
  }

  void discardLatest() {
    latestSpectrum = null;
    acquiredSpectra = const [];
    manualBuffer = const [];
    latestAnalysisResults = const [];
    statusMessage = 'Scan discarded';
    notifyUi();
  }

  Future<void> loadPersistedReferenceState() async {
    try {
      final saved = await dataStore.listReferenceReadyEntries();
      // Drop entries older than 2× the current max-age window - anything
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
    manualBuffer = const [];
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
    // In test mode the simulated reference is managed by runBackground /
    // exitTestMode, not by IP freshness - never let an IP change clobber it.
    if (testMode) return;
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
