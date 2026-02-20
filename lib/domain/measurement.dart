import 'dart:typed_data';
import 'dart:math' as math;

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
    this.modelIdsJson,
    this.resultsJson,
    this.analysisSummary,
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
  final String? modelIdsJson;
  final String? resultsJson;
  final String? analysisSummary;
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
    final count = math.min(
      length,
      math.min(
        xBytes.lengthInBytes ~/ Float64List.bytesPerElement,
        yBytes.lengthInBytes ~/ Float64List.bytesPerElement,
      ),
    );
    if (count <= 0) {
      return Spectrum(x: Float64List(0), y: Float64List(0));
    }
    return Spectrum(
      x: _decodeFloat64(xBytes, count),
      y: _decodeFloat64(yBytes, count),
    );
  }

  Float64List _decodeFloat64(Uint8List source, int count) {
    final safeCount = math.min(
      count,
      source.lengthInBytes ~/ Float64List.bytesPerElement,
    );
    final out = Float64List(safeCount);
    final data = ByteData.sublistView(source);
    for (var i = 0; i < safeCount; i += 1) {
      out[i] = data.getFloat64(i * Float64List.bytesPerElement, Endian.little);
    }
    return out;
  }
}
