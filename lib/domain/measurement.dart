import 'dart:typed_data';

import 'spectrum.dart';

class Measurement {
  Measurement({
    required this.id,
    required this.timestamp,
    required this.deviceId,
    required this.scanTimeMs,
    required this.paramsJson,
    this.materialName,
    this.sampleName,
    this.latitude,
    this.longitude,
    this.modelId,
    this.resultsJson,
  });

  final String id;
  final DateTime timestamp;
  final String deviceId;
  final int scanTimeMs;
  final String paramsJson;
  final String? materialName;
  final String? sampleName;
  final double? latitude;
  final double? longitude;
  final String? modelId;
  final String? resultsJson;
}

class SpectrumBlob {
  SpectrumBlob({
    required this.id,
    required this.measurementId,
    required this.kind,
    required this.length,
    required this.xBytes,
    required this.yBytes,
  });

  final String id;
  final String measurementId;
  final String kind;
  final int length;
  final Uint8List xBytes;
  final Uint8List yBytes;

  Spectrum toSpectrum() {
    return Spectrum(
      x: Float64List.view(xBytes.buffer),
      y: Float64List.view(yBytes.buffer),
    );
  }
}
