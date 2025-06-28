import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a text broadcast message from a vendor
/// Includes optional coarse location data for filtering
class Broadcast {
  final String id;
  final String vendorUid;
  final String vendorName;
  final String vendorAvatarUrl;
  final String stallName;
  final String message;
  final DateTime createdAt;
  final DateTime expiresAt;

  // Optional location data (coarse rounded to 0.1° precision)
  final double? latitude;
  final double? longitude;
  final String?
  locationName; // Human readable location (e.g., "Springfield Farmers Market")

  const Broadcast({
    required this.id,
    required this.vendorUid,
    required this.vendorName,
    required this.vendorAvatarUrl,
    required this.stallName,
    required this.message,
    required this.createdAt,
    required this.expiresAt,
    this.latitude,
    this.longitude,
    this.locationName,
  });

  /// Creates Broadcast from Firestore document
  factory Broadcast.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Broadcast(
      id: doc.id,
      vendorUid: data['vendorUid'] ?? '',
      vendorName: data['vendorName'] ?? 'Unknown Vendor',
      vendorAvatarUrl: data['vendorAvatarUrl'] ?? '',
      stallName: data['stallName'] ?? '',
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      expiresAt:
          (data['expiresAt'] as Timestamp? ??
                  Timestamp.fromDate(
                    DateTime.now().add(const Duration(hours: 24)),
                  ))
              .toDate(),
      latitude: data['latitude']?.toDouble(),
      longitude: data['longitude']?.toDouble(),
      locationName: data['locationName'],
    );
  }

  /// Converts Broadcast to Firestore document data
  Map<String, dynamic> toFirestore() {
    return {
      'vendorUid': vendorUid,
      'vendorName': vendorName,
      'vendorAvatarUrl': vendorAvatarUrl,
      'stallName': stallName,
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (locationName != null) 'locationName': locationName,
    };
  }

  /// Returns true if this broadcast has location data
  bool get hasLocation => latitude != null && longitude != null;

  /// Calculates distance in kilometers to another lat/lng point
  /// Uses Haversine formula for accurate distance calculation
  double? distanceToKm(double? otherLat, double? otherLng) {
    if (!hasLocation || otherLat == null || otherLng == null) return null;

    const double earthRadiusKm = 6371.0;
    final lat1Rad = latitude! * (3.14159265359 / 180);
    final lat2Rad = otherLat * (3.14159265359 / 180);
    final deltaLatRad = (otherLat - latitude!) * (3.14159265359 / 180);
    final deltaLngRad = (otherLng - longitude!) * (3.14159265359 / 180);

    final a =
        sin(deltaLatRad / 2) * sin(deltaLatRad / 2) +
        cos(lat1Rad) *
            cos(lat2Rad) *
            sin(deltaLngRad / 2) *
            sin(deltaLngRad / 2);
    final c = 2 * asin(sqrt(a));

    return earthRadiusKm * c;
  }

  /// Creates a copy with updated fields
  Broadcast copyWith({
    String? id,
    String? vendorUid,
    String? vendorName,
    String? vendorAvatarUrl,
    String? stallName,
    String? message,
    DateTime? createdAt,
    DateTime? expiresAt,
    double? latitude,
    double? longitude,
    String? locationName,
  }) {
    return Broadcast(
      id: id ?? this.id,
      vendorUid: vendorUid ?? this.vendorUid,
      vendorName: vendorName ?? this.vendorName,
      vendorAvatarUrl: vendorAvatarUrl ?? this.vendorAvatarUrl,
      stallName: stallName ?? this.stallName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
    );
  }

  /// Updates this broadcast's cached profile data
  Broadcast updateProfileData({
    required String vendorName,
    required String vendorAvatarUrl,
    required String stallName,
  }) {
    return copyWith(
      vendorName: vendorName,
      vendorAvatarUrl: vendorAvatarUrl,
      stallName: stallName,
    );
  }

  @override
  String toString() {
    return 'Broadcast(id: $id, vendorUid: $vendorUid, message: ${message.length > 20 ? "${message.substring(0, 20)}..." : message}, hasLocation: $hasLocation)';
  }
}

/// Helper class for location data with coarse rounding
class CoarseLocation {
  final double latitude;
  final double longitude;
  final String? name;

  const CoarseLocation({
    required this.latitude,
    required this.longitude,
    this.name,
  });

  /// Rounds coordinates to 0.1° precision (roughly 11km precision)
  /// This provides coarse location while preserving vendor privacy
  static CoarseLocation fromPrecise(double lat, double lng, {String? name}) {
    // Round to 0.1 degree precision (roughly 11km at equator)
    final roundedLat = (lat * 10).round() / 10;
    final roundedLng = (lng * 10).round() / 10;

    return CoarseLocation(
      latitude: roundedLat,
      longitude: roundedLng,
      name: name,
    );
  }

  @override
  String toString() {
    return 'CoarseLocation(lat: $latitude, lng: $longitude, name: $name)';
  }
}
