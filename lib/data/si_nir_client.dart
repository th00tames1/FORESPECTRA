import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';

import '../core/constants.dart';
import '../domain/spectrum.dart';
import 'si_nir_protocol.dart';

class SiNirClient {
  Socket? _writeSocket;
  Socket? _readSocket;
  StreamQueue<List<int>>? _readQueue;
  final List<int> _readCache = [];
  Future<void> _queue = Future.value();

  bool sendLengthPrefix = false;

  Future<void> connect(String ip,
      {int writePort = defaultWritePort,
      int readPort = defaultReadPort,
      Duration timeout = const Duration(seconds: 4)}) async {
    _writeSocket = await Socket.connect(ip, writePort, timeout: timeout);
    await Future.delayed(const Duration(milliseconds: 100));
    _readSocket = await Socket.connect(ip, readPort, timeout: timeout);
    _readQueue = StreamQueue(_readSocket!);
  }

  bool get isConnected => _writeSocket != null && _readSocket != null;

  Future<void> disconnect() async {
    await _writeSocket?.close();
    await _readSocket?.close();
    await _readQueue?.cancel();
    _readQueue = null;
    _readCache.clear();
    _writeSocket = null;
    _readSocket = null;
  }

  Future<int> checkBoard() => _enqueue(() async {
        final payload = await _sendOperation(Operation.checkBoard);
        return payload.isEmpty ? -1 : payload[0];
      });

  Future<String> readModuleId() => _enqueue(() async {
        final payload = await _sendOperation(Operation.readModuleId);
        final idBytes = payload.takeWhile((value) => value != 0).toList();
        return String.fromCharCodes(idBytes);
      });

  Future<Spectrum> runPsd(ScanParams params) => _enqueue(() async {
        final payload = await _sendOperation(Operation.runPsd, params: params);
        final result = parseSpectrumPayload(payload);
        return Spectrum(x: result.wavenumber, y: result.values);
      });

  Future<Spectrum> runSpectrum(ScanParams params) => _enqueue(() async {
        final payload = await _sendOperation(Operation.runSpectrum, params: params);
        final result = parseSpectrumPayload(payload);
        return Spectrum(x: result.wavenumber, y: result.values);
      });

  Future<int> runBackground(ScanParams params) => _enqueue(() async {
        final payload = await _sendOperation(Operation.runBackground, params: params);
        return payload.isEmpty ? -1 : payload[0];
      });

  Future<int> runGainAdj() => _enqueue(() async {
        final payload = await _sendOperation(Operation.runGainAdj);
        if (payload.isEmpty) {
          return -1;
        }
        return payload[0];
      });

  Future<int> setSourceSettings({
    required int lampsCount,
    required int lampSelect,
    required int t1,
    required int deltaT,
    required int t2c1,
    required int t2c2,
    required int t2max,
  }) =>
      _enqueue(() async {
        final params = ScanParams(operation: Operation.setSourceSettings);
        params.generalData[0] = lampsCount | (lampSelect << 8);
        params.generalData[1] = t1 | (deltaT << 8);
        params.generalData[2] = t2c1 | (t2c2 << 8) | (t2max << 16);
        final payload = await _sendOperation(Operation.setSourceSettings, params: params);
        return payload.isEmpty ? -1 : payload[0];
      });

  Future<int> setOpticalSettings(int gainValue) => _enqueue(() async {
        final params = ScanParams(operation: Operation.setOpticalSettings);
        params.generalData[0] = gainValue;
        final payload = await _sendOperation(Operation.setOpticalSettings, params: params);
        return payload.isEmpty ? -1 : payload[0];
      });

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        final result = await task();
        completer.complete(result);
      } catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  Future<Uint8List> _sendOperation(int operation, {ScanParams? params}) async {
    if (!isConnected) {
      throw Exception('Not connected');
    }
    final request = params ?? ScanParams();
    request.operation = operation;
    final bytes = request.toBytes();
    final writeSocket = _writeSocket!;
    if (sendLengthPrefix) {
      final lengthBytes = ByteData(4)..setUint32(0, bytes.length, Endian.little);
      writeSocket.add(lengthBytes.buffer.asUint8List());
    }
    writeSocket.add(bytes);
    await writeSocket.flush();
    return _readPacket();
  }

  Future<Uint8List> _readPacket() async {
    final lengthBytes = await _readExact(4);
    final length = ByteData.sublistView(lengthBytes).getUint32(0, Endian.little);
    if (length == 0) {
      return Uint8List(0);
    }
    return _readExact(length);
  }

  Future<Uint8List> _readExact(int length) async {
    final queue = _readQueue;
    if (queue == null) {
      throw Exception('Read queue not initialized');
    }
    while (_readCache.length < length) {
      final chunk = await queue.next;
      _readCache.addAll(chunk);
    }
    final data = Uint8List.fromList(_readCache.sublist(0, length));
    _readCache.removeRange(0, length);
    return data;
  }
}
