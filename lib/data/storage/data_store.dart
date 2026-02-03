import 'dart:convert';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/measurement.dart';

class DataStore {
  Database? _db;

  Future<void> init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'spectra.db');
    _db = await openDatabase(
      path,
      version: 2,
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
            results_json TEXT
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
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE measurements ADD COLUMN material_name TEXT');
          await db.execute('ALTER TABLE measurements ADD COLUMN sample_name TEXT');
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
    await _database.insert(
      'devices',
      {
        'id': id,
        'name': name,
        'ip': ip,
        'last_seen': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveModel({
    required String id,
    required String name,
    required String json,
  }) async {
    await _database.insert(
      'models',
      {
        'id': id,
        'name': name,
        'json': json,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveMeasurement(Measurement measurement) async {
    await _database.insert(
      'measurements',
      {
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
        'results_json': measurement.resultsJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveSpectrum(SpectrumBlob blob) async {
    await _database.insert(
      'spectra',
      {
        'id': blob.id,
        'measurement_id': blob.measurementId,
        'kind': blob.kind,
        'length': blob.length,
        'x_blob': blob.xBytes,
        'y_blob': blob.yBytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Measurement>> listMeasurements() async {
    final rows = await _database.query('measurements', orderBy: 'timestamp DESC');
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

  Future<String?> getModelJson(String modelId) async {
    final rows = await _database.query('models', where: 'id = ?', whereArgs: [modelId]);
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
      resultsJson: row['results_json'] as String?,
    );
  }

  String serializeJson(Map<String, dynamic> map) => jsonEncode(map);
}
