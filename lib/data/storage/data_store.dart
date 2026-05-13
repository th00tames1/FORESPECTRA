import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/measurement.dart';

class StoredModel {
  const StoredModel({
    required this.id,
    required this.name,
    required this.json,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String json;
  final DateTime createdAt;
}

class DataStore {
  Database? _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'spectra.db');
    _db = await openDatabase(
      path,
      version: 5,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE devices(
            id TEXT PRIMARY KEY,
            name TEXT,
            ip TEXT,
            last_seen INTEGER
          );
        ''');
        await db.execute('''
          CREATE TABLE models(
            id TEXT PRIMARY KEY,
            name TEXT,
            json TEXT,
            created_at INTEGER
          );
        ''');
        await db.execute('''
          CREATE TABLE measurements(
            id TEXT PRIMARY KEY,
            device_id TEXT,
            timestamp INTEGER,
            scan_time_ms INTEGER,
            params_json TEXT,
            material_name TEXT,
            sample_name TEXT,
            lat REAL,
            lon REAL,
            model_id TEXT,
            model_ids_json TEXT,
            results_json TEXT,
            analysis_summary TEXT
          );
        ''');
        await db.execute('''
          CREATE TABLE spectra(
            id TEXT PRIMARY KEY,
            measurement_id TEXT,
            kind TEXT,
            length INTEGER,
            x_blob BLOB,
            y_blob BLOB
          );
        ''');
        await db.execute('''
          CREATE TABLE reference_state(
            ip TEXT PRIMARY KEY,
            last_set INTEGER
          );
        ''');
        await db.execute('''
          CREATE TABLE app_settings(
            key TEXT PRIMARY KEY,
            value TEXT
          );
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await db.execute(
              'ALTER TABLE measurements ADD COLUMN material_name TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE measurements ADD COLUMN sample_name TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 3) {
          try {
            await db.execute(
              'ALTER TABLE measurements ADD COLUMN model_ids_json TEXT',
            );
          } catch (_) {}
          try {
            await db.execute(
              'ALTER TABLE measurements ADD COLUMN analysis_summary TEXT',
            );
          } catch (_) {}
        }
        if (oldVersion < 4) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS reference_state(
                ip TEXT PRIMARY KEY,
                last_set INTEGER
              );
            ''');
          } catch (_) {}
        }
        if (oldVersion < 5) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS app_settings(
                key TEXT PRIMARY KEY,
                value TEXT
              );
            ''');
          } catch (_) {}
        }
      },
    );
  }

  Database get _database {
    final db = _db;
    if (db == null) {
      throw StateError('Database not initialized');
    }
    return db;
  }

  Future<void> upsertDevice({
    required String id,
    required String name,
    required String ip,
  }) async {
    await _database.insert('devices', {
      'id': id,
      'name': name,
      'ip': ip,
      'last_seen': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> clearDevices() async {
    await _database.delete('devices');
  }

  Future<void> setReferenceReady(String ip, bool ready) async {
    if (ready) {
      await _database.insert('reference_state', {
        'ip': ip,
        'last_set': DateTime.now().millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } else {
      await _database.delete(
        'reference_state',
        where: 'ip = ?',
        whereArgs: [ip],
      );
    }
  }

  Future<Map<String, String>> loadAllSettings() async {
    final rows = await _database.query('app_settings');
    final result = <String, String>{};
    for (final row in rows) {
      final key = row['key'];
      final value = row['value'];
      if (key is String && value is String) {
        result[key] = value;
      }
    }
    return result;
  }

  Future<void> writeSetting(String key, String value) async {
    await _database.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAllSettings() async {
    await _database.delete('app_settings');
  }

  Future<Map<String, DateTime>> listReferenceReadyEntries() async {
    final rows = await _database.query(
      'reference_state',
      columns: ['ip', 'last_set'],
    );
    final result = <String, DateTime>{};
    for (final row in rows) {
      final ip = row['ip'];
      final ts = row['last_set'];
      if (ip is String && ip.isNotEmpty && ts is int) {
        result[ip] = DateTime.fromMillisecondsSinceEpoch(ts);
      }
    }
    return result;
  }

  Future<List<String>> listRecentDeviceIps({int limit = 12}) async {
    final rows = await _database.query(
      'devices',
      columns: ['ip'],
      where: 'ip IS NOT NULL AND ip != ?',
      whereArgs: [''],
      orderBy: 'last_seen DESC',
      limit: limit,
    );

    final ips = <String>[];
    for (final row in rows) {
      final ip = (row['ip'] as String?)?.trim();
      if (ip != null && ip.isNotEmpty && !ips.contains(ip)) {
        ips.add(ip);
      }
    }
    return ips;
  }

  Future<void> saveModel({
    required String id,
    required String name,
    required String json,
  }) async {
    await _database.insert('models', {
      'id': id,
      'name': name,
      'json': json,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<StoredModel>> listModels() async {
    final rows = await _database.query('models', orderBy: 'created_at DESC');
    return rows
        .map((row) {
          final createdAtRaw = row['created_at'] as int?;
          return StoredModel(
            id: row['id'] as String,
            name: (row['name'] as String?) ?? 'Model',
            json: row['json'] as String,
            createdAt: DateTime.fromMillisecondsSinceEpoch(createdAtRaw ?? 0),
          );
        })
        .toList(growable: false);
  }

  Future<void> saveMeasurement(Measurement measurement) async {
    await _database.insert('measurements', {
      'id': measurement.id,
      'device_id': measurement.deviceId,
      'timestamp': measurement.timestamp.millisecondsSinceEpoch,
      'scan_time_ms': measurement.scanTimeMs,
      'params_json': measurement.paramsJson,
      'material_name': measurement.materialName,
      'sample_name': measurement.sampleName,
      'lat': measurement.latitude,
      'lon': measurement.longitude,
      'model_id': measurement.modelId,
      'model_ids_json': measurement.modelIdsJson,
      'results_json': measurement.resultsJson,
      'analysis_summary': measurement.analysisSummary,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> saveSpectrum(SpectrumBlob blob) async {
    await _database.insert('spectra', {
      'id': blob.id,
      'measurement_id': blob.measurementId,
      'kind': blob.kind,
      'length': blob.length,
      'x_blob': blob.xBytes,
      'y_blob': blob.yBytes,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Measurement>> listMeasurements() async {
    final rows = await _database.query(
      'measurements',
      orderBy: 'timestamp DESC',
    );
    return rows.map(_measurementFromRow).toList();
  }

  Future<List<SpectrumBlob>> getSpectra(String measurementId) async {
    final rows = await _database.query(
      'spectra',
      where: 'measurement_id = ?',
      whereArgs: [measurementId],
    );
    return rows.map((row) {
      return SpectrumBlob(
        id: row['id'] as String,
        measurementId: row['measurement_id'] as String,
        kind: row['kind'] as String,
        length: row['length'] as int,
        xBytes: row['x_blob'] as Uint8List,
        yBytes: row['y_blob'] as Uint8List,
      );
    }).toList();
  }

  Future<void> renameMeasurementSampleName(
    String measurementId,
    String sampleName,
  ) async {
    await _database.update(
      'measurements',
      {'sample_name': sampleName.trim().isEmpty ? null : sampleName.trim()},
      where: 'id = ?',
      whereArgs: [measurementId],
    );
  }

  Future<void> deleteMeasurement(String measurementId) async {
    await _database.delete(
      'spectra',
      where: 'measurement_id = ?',
      whereArgs: [measurementId],
    );
    await _database.delete(
      'measurements',
      where: 'id = ?',
      whereArgs: [measurementId],
    );
  }

  Future<String?> getModelJson(String modelId) async {
    final rows = await _database.query(
      'models',
      where: 'id = ?',
      whereArgs: [modelId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['json'] as String;
  }

  Measurement _measurementFromRow(Map<String, Object?> row) {
    return Measurement(
      id: row['id'] as String,
      deviceId: row['device_id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(row['timestamp'] as int),
      scanTimeMs: row['scan_time_ms'] as int,
      paramsJson: row['params_json'] as String,
      materialName: row['material_name'] as String?,
      sampleName: row['sample_name'] as String?,
      latitude: row['lat'] as double?,
      longitude: row['lon'] as double?,
      modelId: row['model_id'] as String?,
      modelIdsJson: row['model_ids_json'] as String?,
      resultsJson: row['results_json'] as String?,
      analysisSummary: row['analysis_summary'] as String?,
    );
  }

  String serializeJson(Map<String, dynamic> map) => jsonEncode(map);
}
