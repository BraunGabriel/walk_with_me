import 'package:geolocator/geolocator.dart';

/// Wraps location permission handling.
class LocationService {
  /// Requests when-in-use permission. Returns true if location is usable.
  Future<bool> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }
}
