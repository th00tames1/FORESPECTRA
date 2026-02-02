import 'dart:typed_data';

import '../core/constants.dart';

class ScanParams {
  ScanParams({
    this.operation = 0,
    this.resolution = 0,
    this.mode = 0,
    this.zeroPadding = 3,
    this.scanTimeMs = 200,
    this.commonWavNum = 3,
    this.opticalGain = 0,
    this.apodizationSel = 0,
    List<int>? generalData,
  }) : generalData = generalData ?? List.filled(40, 0);

  int operation;
  int resolution;
  int mode;
  int zeroPadding;
  int scanTimeMs;
  int commonWavNum;
  int opticalGain;
  int apodizationSel;
  List<int> generalData;

  Uint8List toBytes() {
    final data = ByteData(192);
    final fields = [
      operation,
      resolution,
      mode,
      zeroPadding,
      scanTimeMs,
      commonWavNum,
      opticalGain,
      apodizationSel,
      ...generalData,
    ];
    for (var i = 0; i < fields.length; i++) {
      data.setUint32(i * 4, fields[i], Endian.little);
    }
    return data.buffer.asUint8List();
  }
}

class Operation {
  static const readModuleId = 1;
  static const checkBoard = 2;
  static const runPsd = 3;
  static const runBackground = 4;
  static const runSpectrum = 5;
  static const runGainAdj = 6;
  static const burnGain = 7;
  static const burnSelf = 8;
  static const burnWln = 9;
  static const runSelfCorr = 10;
  static const runWavelengthCorrBg = 11;
  static const runWavelengthCorr = 12;
  static const restoreDefault = 13;
  static const readSoftwareVersion = 14;
  static const setSourceSettings = 22;
  static const setOpticalSettings = 27;
  static const injectExternalWindow = 28;
}

class SpectrumPayload {
  SpectrumPayload({
    required this.wavenumber,
    required this.values,
  });

  final Float64List wavenumber;
  final Float64List values;
}

SpectrumPayload parseSpectrumPayload(Uint8List payload) {
  final data = ByteData.sublistView(payload);
  final status = data.getUint32(0, Endian.little);
  if (status != 0) {
    throw Exception('Device returned status $status');
  }
  final length = data.getUint32(4, Endian.little);
  final offset = 8;
  final psdBytes = payload.sublist(offset, offset + maxPsdLength * 8);
  final wvlBytes = payload.sublist(offset + maxPsdLength * 8);
  final psdData = ByteData.sublistView(psdBytes);
  final wvlData = ByteData.sublistView(wvlBytes);
  final values = Float64List(length);
  final wavenumber = Float64List(length);
  for (var i = 0; i < length; i++) {
    values[i] = psdData.getInt64(i * 8, Endian.little) * psdScale;
    wavenumber[i] = wvlData.getInt64(i * 8, Endian.little) * wavenumberScale;
  }
  return SpectrumPayload(wavenumber: wavenumber, values: values);
}
