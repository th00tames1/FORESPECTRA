import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Best-effort current position. Returns null (never throws) when location is
  /// disabled, denied, or unavailable, so a failed/slow GPS read can never block
  /// or crash a measurement save. The whole resolution (including a first-run
  /// permission dialog) is time-bounded so a save can never hang on it.
  Future<Position?> getCurrentPosition() async {
    try {
      return await _resolvePosition().timeout(const Duration(seconds: 12));
    } catch (_) {
      // Timeout, missing platform definitions, transient GPS error, etc.
      return null;
    }
  }

  Future<Position?> _resolvePosition() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return null;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    return Geolocator.getCurrentPosition()
        .timeout(const Duration(seconds: 8));
  }
}
