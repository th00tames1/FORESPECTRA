import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/storage/data_store.dart';
import '../domain/measurement.dart';

/// Exports the scan history (measurements + spectra) to a single portable file
/// and restores it by MERGING (only missing records are added, existing ones
/// are kept). Lets users carry history across reinstalls / new phones.
class BackupService {
  BackupService(this._store);

  final DataStore _store;

  static const String _formatTag = 'forespectra-backup';
  static const int _formatVersion = 1;
  static const String fileExtension = 'json';

  /// Writes a backup file to the app documents directory and returns its path.
  Future<String> exportToFile() async {
    final measurements = await _store.listMeasurements();
    final spectra = await _store.listAllSpectra();
    final payload = <String, Object?>{
      'format': _formatTag,
      'version': _formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'measurementCount': measurements.length,
      'measurements': [for (final m in measurements) _measurementToJson(m)],
      'spectra': [for (final s in spectra) _spectrumToJson(s)],
    };
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        'forespectra_history_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
    final path = p.join(dir.path, fileName);
    await File(path).writeAsString(jsonEncode(payload));
    return path;
  }

  /// Reads a backup file and merges it into the database. Throws
  /// [FormatException] if the file is not a Forespectra backup.
  Future<({int measurementsAdded, int spectraAdded})> importFromFile(
    String path,
  ) async {
    final text = await File(path).readAsString();
    Object? decoded;
    try {
      decoded = jsonDecode(text);
    } catch (_) {
      throw const FormatException('File is not a valid Forespectra backup.');
    }
    if (decoded is! Map || decoded['format'] != _formatTag) {
      throw const FormatException('File is not a valid Forespectra backup.');
    }

    final measurements = <Measurement>[];
    final rawMeasurements = decoded['measurements'];
    if (rawMeasurements is List) {
      for (final item in rawMeasurements) {
        if (item is Map) {
          final m = _measurementFromJson(Map<String, dynamic>.from(item));
          if (m != null) measurements.add(m);
        }
      }
    }

    final spectra = <SpectrumBlob>[];
    final rawSpectra = decoded['spectra'];
    if (rawSpectra is List) {
      for (final item in rawSpectra) {
        if (item is Map) {
          final s = _spectrumFromJson(Map<String, dynamic>.from(item));
          if (s != null) spectra.add(s);
        }
      }
    }

    return _store.importBackup(measurements: measurements, spectra: spectra);
  }

  Map<String, Object?> _measurementToJson(Measurement m) => {
    'id': m.id,
    'timestamp': m.timestamp.millisecondsSinceEpoch,
    'deviceId': m.deviceId,
    'scanTimeMs': m.scanTimeMs,
    'paramsJson': m.paramsJson,
    'materialName': m.materialName,
    'sampleName': m.sampleName,
    'latitude': m.latitude,
    'longitude': m.longitude,
    'modelId': m.modelId,
    'modelIdsJson': m.modelIdsJson,
    'resultsJson': m.resultsJson,
    'analysisSummary': m.analysisSummary,
  };

  Measurement? _measurementFromJson(Map<String, dynamic> j) {
    final id = j['id'];
    if (id is! String || id.isEmpty) return null;
    final tsRaw = j['timestamp'];
    final ts = tsRaw is num ? tsRaw.toInt() : null;
    if (ts == null) return null;
    return Measurement(
      id: id,
      timestamp: DateTime.fromMillisecondsSinceEpoch(ts),
      deviceId: (j['deviceId'] as String?) ?? 'unknown',
      scanTimeMs: (j['scanTimeMs'] as num?)?.toInt() ?? 0,
      paramsJson: (j['paramsJson'] as String?) ?? '{}',
      materialName: j['materialName'] as String?,
      sampleName: j['sampleName'] as String?,
      latitude: (j['latitude'] as num?)?.toDouble(),
      longitude: (j['longitude'] as num?)?.toDouble(),
      modelId: j['modelId'] as String?,
      modelIdsJson: j['modelIdsJson'] as String?,
      resultsJson: j['resultsJson'] as String?,
      analysisSummary: j['analysisSummary'] as String?,
    );
  }

  Map<String, Object?> _spectrumToJson(SpectrumBlob s) => {
    'id': s.id,
    'measurementId': s.measurementId,
    'kind': s.kind,
    'length': s.length,
    'x': base64Encode(s.xBytes),
    'y': base64Encode(s.yBytes),
  };

  SpectrumBlob? _spectrumFromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final measurementId = j['measurementId'];
    if (id is! String || id.isEmpty) return null;
    if (measurementId is! String || measurementId.isEmpty) return null;
    final xRaw = j['x'];
    final yRaw = j['y'];
    if (xRaw is! String || yRaw is! String) return null;
    Uint8List xBytes;
    Uint8List yBytes;
    try {
      xBytes = base64Decode(xRaw);
      yBytes = base64Decode(yRaw);
    } catch (_) {
      return null;
    }
    return SpectrumBlob(
      id: id,
      measurementId: measurementId,
      kind: (j['kind'] as String?) ?? 'raw',
      length: (j['length'] as num?)?.toInt() ?? (xBytes.lengthInBytes ~/ 8),
      xBytes: xBytes,
      yBytes: yBytes,
    );
  }
}
