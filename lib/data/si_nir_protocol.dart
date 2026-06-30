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
    // Size from the actual field count (48 == 192 bytes for the default
    // 40-entry generalData) so a differently-sized generalData can never write
    // past the buffer.
    final data = ByteData(fields.length * 4);
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
  if (payload.length < 8) {
    throw Exception('Truncated spectrum payload');
  }
  final data = ByteData.sublistView(payload);
  final status = data.getUint32(0, Endian.little);
  if (status != 0) {
    throw Exception('Device returned status $status');
  }
  final length = data.getUint32(4, Endian.little);
  const offset = 8;
  final psdRegion = maxPsdLength * 8;
  if (payload.length < offset + psdRegion) {
    throw Exception('Truncated spectrum payload');
  }
  final psdBytes = payload.sublist(offset, offset + psdRegion);
  final wvlBytes = payload.sublist(offset + psdRegion);
  final psdData = ByteData.sublistView(psdBytes);
  final wvlData = ByteData.sublistView(wvlBytes);
  // Clamp to what the payload actually carries so a malformed length or a
  // short wavelength region can never index out of bounds.
  final wvlCapacity = wvlBytes.lengthInBytes ~/ 8;
  var n = length;
  if (n > maxPsdLength) n = maxPsdLength;
  if (n > wvlCapacity) n = wvlCapacity;
  final values = Float64List(n);
  final wavenumber = Float64List(n);
  for (var i = 0; i < n; i++) {
    values[i] = psdData.getInt64(i * 8, Endian.little) * psdScale;
    wavenumber[i] = wvlData.getInt64(i * 8, Endian.little) * wavenumberScale;
  }
  return SpectrumPayload(wavenumber: wavenumber, values: values);
}
