/// Enum representing the different types of users in MarketSnap
enum UserType {
  /// Vendor users who sell products at farmers markets
  vendor,

  /// Regular users who browse and follow vendors
  regular,
}

/// Extension to provide user-friendly labels for UserType
extension UserTypeExtension on UserType {
  /// Returns a user-friendly display name for the user type
  String get displayName {
    switch (this) {
      case UserType.vendor:
        return 'Vendor';
      case UserType.regular:
        return 'Regular User';
    }
  }

  /// Returns a description of what this user type can do
  String get description {
    switch (this) {
      case UserType.vendor:
        return 'Share your fresh finds and connect with customers';
      case UserType.regular:
        return 'Discover vendors and follow your favorites';
    }
  }

  /// Returns an icon that represents this user type
  String get iconName {
    switch (this) {
      case UserType.vendor:
        return 'storefront';
      case UserType.regular:
        return 'person';
    }
  }

  /// Converts UserType to string for storage
  String toStorageString() {
    return name;
  }

  /// Creates UserType from storage string
  static UserType fromStorageString(String value) {
    switch (value) {
      case 'vendor':
        return UserType.vendor;
      case 'regular':
        return UserType.regular;
      default:
        throw ArgumentError('Invalid UserType value: $value');
    }
  }
}
