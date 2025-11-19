import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationStatus {
  LocationStatus({
    required this.serviceEnabled,
    required this.permissionGranted,
    required this.permissionPermanentlyDenied,
  });

  final bool serviceEnabled;
  final bool permissionGranted;
  final bool permissionPermanentlyDenied;

  bool get canRequestPosition => serviceEnabled && permissionGranted;
}

class LocationService {
  LocationService._internal();

  static final LocationService instance = LocationService._internal();

  Position? _cachedPosition;
  DateTime? _lastPositionFetch;

  final Duration _cacheTTL = const Duration(minutes: 5);

  Future<LocationStatus> ensurePermissions({bool requestPermission = true}) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationStatus(
        serviceEnabled: false,
        permissionGranted: false,
        permissionPermanentlyDenied: false,
      );
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }

    final permanentlyDenied = permission == LocationPermission.deniedForever;
    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    return LocationStatus(
      serviceEnabled: serviceEnabled,
      permissionGranted: granted,
      permissionPermanentlyDenied: permanentlyDenied,
    );
  }

  Future<Position?> getCurrentPosition({
    bool forceFresh = false,
    bool allowCachedFallback = true,
    bool allowLowAccuracyRetry = true,
    LocationAccuracy accuracy = LocationAccuracy.high,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final status = await ensurePermissions();

    if (!status.canRequestPosition) {
      // Retornar última posição se já tivermos algo salvo
      if (allowCachedFallback && _cachedPosition != null) {
        return _cachedPosition;
      }
      return _fallbackToLastKnown(forceCache: true);
    }

    if (!forceFresh &&
        _cachedPosition != null &&
        _lastPositionFetch != null &&
        DateTime.now().difference(_lastPositionFetch!) < _cacheTTL) {
      return _cachedPosition;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: accuracy,
      ).timeout(timeout);

      _cachePosition(position);
      return position;
    } on TimeoutException {
      if (allowLowAccuracyRetry) {
        try {
          final fallback = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          ).timeout(const Duration(seconds: 10));
          _cachePosition(fallback);
          return fallback;
        } catch (_) {}
      }
      return _fallbackToLastKnown(forceCache: true);
    } catch (_) {
      return _fallbackToLastKnown(forceCache: true);
    }
  }

  Future<Position?> _fallbackToLastKnown({bool forceCache = false}) async {
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null && (forceCache || _cachedPosition == null)) {
      _cachePosition(lastKnown);
    }
    return lastKnown ?? _cachedPosition;
  }

  void _cachePosition(Position position) {
    _cachedPosition = position;
    _lastPositionFetch = DateTime.now();
  }

  Future<Position?> getLastKnownPosition() => Geolocator.getLastKnownPosition();

  Future<void> openAppSettings() => Geolocator.openAppSettings();

  Future<void> openLocationSettings() => Geolocator.openLocationSettings();
}

