import 'dart:async';
import 'dart:developer' as developer;
import 'package:geolocator/geolocator.dart';
import '../models/broadcast.dart';

/// Service for handling location-related functionality
/// Includes permission management, location fetching, and privacy-preserving coarse rounding
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  /// Cached location data to avoid frequent GPS requests
  CoarseLocation? _cachedLocation;
  DateTime? _lastLocationUpdate;
  static const Duration _cacheValidDuration = Duration(minutes: 10);

  /// Check if location services are enabled and user has granted permission
  Future<bool> isLocationAvailable() async {
    try {
      developer.log('[LocationService] 📍 Checking location availability...');

      // Check if location services are enabled on device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log('[LocationService] ❌ Location services are disabled');
        return false;
      }

      // Check current permission status
      LocationPermission permission = await Geolocator.checkPermission();
      developer.log('[LocationService] 📍 Current permission: $permission');

      return permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;
    } catch (e) {
      developer.log(
        '[LocationService] ❌ Error checking location availability: $e',
      );
      return false;
    }
  }

  /// Request location permission from user
  /// Returns true if permission is granted or already available
  Future<bool> requestLocationPermission() async {
    try {
      developer.log('[LocationService] 📍 Requesting location permission...');

      // First check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        developer.log(
          '[LocationService] ❌ Location services disabled - requesting user to enable',
        );

        // Try to open location settings
        try {
          await Geolocator.openLocationSettings();
        } catch (e) {
          developer.log(
            '[LocationService] ⚠️ Could not open location settings: $e',
          );
        }
        return false;
      }

      // Check current permission
      LocationPermission permission = await Geolocator.checkPermission();
      developer.log('[LocationService] 📍 Current permission: $permission');

      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        developer.log(
          '[LocationService] 📍 Permission after request: $permission',
        );
      }

      if (permission == LocationPermission.deniedForever) {
        developer.log(
          '[LocationService] ❌ Location permission denied forever - redirecting to app settings',
        );

        // Open app settings so user can enable manually
        try {
          await Geolocator.openAppSettings();
        } catch (e) {
          developer.log('[LocationService] ⚠️ Could not open app settings: $e');
        }
        return false;
      }

      bool granted =
          permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always;

      developer.log(
        '[LocationService] ${granted ? '✅' : '❌'} Location permission result: $granted',
      );
      return granted;
    } catch (e) {
      developer.log(
        '[LocationService] ❌ Error requesting location permission: $e',
      );
      return false;
    }
  }

  /// Get current coarse location with privacy-preserving rounding
  /// Returns null if location is not available or user hasn't granted permission
  Future<CoarseLocation?> getCurrentCoarseLocation({
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first (unless force refresh)
      if (!forceRefresh && _isCacheValid()) {
        developer.log(
          '[LocationService] 📍 Using cached location: $_cachedLocation',
        );
        return _cachedLocation;
      }

      developer.log('[LocationService] 📍 Getting fresh location...');

      // Ensure we have permission
      bool hasPermission = await isLocationAvailable();
      if (!hasPermission) {
        developer.log(
          '[LocationService] ❌ No location permission, cannot get location',
        );
        return null;
      }

      // Get current position with timeout for responsive UX
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy:
            LocationAccuracy.medium, // Balance between accuracy and battery
        timeLimit: const Duration(seconds: 10), // Don't hang the UI
      );

      developer.log(
        '[LocationService] 📍 Raw position: ${position.latitude}, ${position.longitude}',
      );

      // Create coarse location with privacy rounding
      final coarseLocation = CoarseLocation.fromPrecise(
        position.latitude,
        position.longitude,
        name: await _getLocationName(position.latitude, position.longitude),
      );

      // Cache the result
      _cachedLocation = coarseLocation;
      _lastLocationUpdate = DateTime.now();

      developer.log(
        '[LocationService] ✅ Coarse location obtained: $coarseLocation',
      );
      return coarseLocation;
    } on TimeoutException {
      developer.log('[LocationService] ⏰ Location request timed out');
      return null;
    } catch (e) {
      developer.log('[LocationService] ❌ Error getting current location: $e');
      return null;
    }
  }

  /// Get approximate location name for user display (optional enhancement)
  /// This is a placeholder - in production you might use reverse geocoding
  Future<String?> _getLocationName(double lat, double lng) async {
    try {
      // For now, return a generic location name
      // In production, you could integrate with a reverse geocoding service
      return 'Local Market Area';
    } catch (e) {
      developer.log('[LocationService] ⚠️ Could not get location name: $e');
      return null;
    }
  }

  /// Check if cached location is still valid
  bool _isCacheValid() {
    if (_cachedLocation == null || _lastLocationUpdate == null) {
      return false;
    }

    final timeSinceUpdate = DateTime.now().difference(_lastLocationUpdate!);
    return timeSinceUpdate < _cacheValidDuration;
  }

  /// Calculate distance between two coarse locations in kilometers
  /// Returns null if either location is invalid
  static double? calculateDistance(CoarseLocation? loc1, CoarseLocation? loc2) {
    if (loc1 == null || loc2 == null) return null;

    try {
      double distanceInMeters = Geolocator.distanceBetween(
        loc1.latitude,
        loc1.longitude,
        loc2.latitude,
        loc2.longitude,
      );

      return distanceInMeters / 1000; // Convert to kilometers
    } catch (e) {
      developer.log('[LocationService] ❌ Error calculating distance: $e');
      return null;
    }
  }

  /// Clear cached location data (useful for testing or user logout)
  void clearCache() {
    developer.log('[LocationService] 🗑️ Clearing location cache');
    _cachedLocation = null;
    _lastLocationUpdate = null;
  }

  /// Check if location permission was permanently denied
  Future<bool> isPermissionPermanentlyDenied() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      return permission == LocationPermission.deniedForever;
    } catch (e) {
      developer.log('[LocationService] ❌ Error checking permission status: $e');
      return false;
    }
  }

  /// Get user-friendly location status message
  Future<String> getLocationStatusMessage() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return 'Location services are disabled. Enable in device settings.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      switch (permission) {
        case LocationPermission.denied:
          return 'Location permission needed to tag broadcasts with your market area.';
        case LocationPermission.deniedForever:
          return 'Location permission denied. Enable in app settings to tag broadcasts.';
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          return 'Location services enabled. Your broadcasts can include market area.';
        default:
          return 'Location status unknown.';
      }
    } catch (e) {
      return 'Unable to check location status.';
    }
  }
}
