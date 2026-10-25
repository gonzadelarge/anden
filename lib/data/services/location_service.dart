import 'package:geolocator/geolocator.dart';

import '../../core/geo.dart';

enum LocationAccess { granted, notAsked, denied, serviceOff }

/// Approximate position of the phone. Only used on the device, never sent.
abstract class LocationService {
  Future<LocationAccess> access();

  /// Shows the system dialog. Returns true when access was given.
  Future<bool> request();

  /// Position Android already has, if it is not older than [maxAge]. Instant.
  Future<GeoPoint?> lastKnown({required Duration maxAge});

  /// Fresh low-accuracy position (WiFi / cell). Null after [timeout].
  Future<GeoPoint?> current({required Duration timeout});
}

class GeolocatorLocationService implements LocationService {
  @override
  Future<LocationAccess> access() async {
    if (!await Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceOff;
    return switch (await Geolocator.checkPermission()) {
      LocationPermission.always || LocationPermission.whileInUse => LocationAccess.granted,
      LocationPermission.denied => LocationAccess.notAsked,
      _ => LocationAccess.denied,
    };
  }

  @override
  Future<bool> request() async {
    final p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  @override
  Future<GeoPoint?> lastKnown({required Duration maxAge}) async {
    try {
      final p = await Geolocator.getLastKnownPosition();
      if (p == null || DateTime.now().difference(p.timestamp) > maxAge) return null;
      return GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<GeoPoint?> current({required Duration timeout}) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.low, timeLimit: timeout),
      );
      return GeoPoint(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
