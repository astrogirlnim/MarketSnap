# MarketSnap

A cross-platform mobile application built with Flutter and Firebase backend, supporting both iOS and Android platforms.

## Project Overview

MarketSnap is a Flutter application configured with:
- **Cross-platform support**: iOS and Android
- **Firebase backend**: Authentication, Firestore, Storage, and Functions
- **Secure configuration**: Environment-based secret management
- **CI/CD pipeline**: GitHub Actions for automated testing and deployment

## Security Implementation

### Environment Variables Setup

This project uses environment variables to securely manage Firebase configuration and API keys. **You must create a `.env` file** in the root directory with the following variables:

```env
# Firebase API Keys
ANDROID_API_KEY=your_android_api_key_here
IOS_API_KEY=your_ios_api_key_here

# Firebase Project Configuration
FIREBASE_PROJECT_ID=your_project_id_here
FIREBASE_PROJECT_NUMBER=your_project_number_here
FIREBASE_MESSAGING_SENDER_ID=your_sender_id_here
FIREBASE_STORAGE_BUCKET=your_storage_bucket_here

# Firebase App IDs
ANDROID_APP_ID=your_android_app_id_here
IOS_APP_ID=your_ios_app_id_here

# App Bundle/Package Identifiers
APP_BUNDLE_ID=your_bundle_id_here
```

### Security Features

- ✅ **No hardcoded API keys** in source code
- ✅ **Environment-based configuration** using `flutter_dotenv`
- ✅ **Sensitive files excluded** from version control
- ✅ **Firebase configuration** loaded securely at runtime
- ✅ **Clean architecture** following Flutter best practices

## Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Dart SDK
- Android Studio / Xcode for platform-specific development
- Firebase CLI
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd MarketSnap
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Create environment file**
   ```bash
   # Create .env file in the root directory
   # Add your Firebase configuration variables (see Security section above)
   ```

4. **Run the application**
   ```bash
   # For iOS Simulator
   flutter run -d apple_ios_simulator
   
   # For Android Emulator
   flutter run -d emulator-5554
   
   # List available devices
   flutter devices
   ```

## Firebase Setup

The project is configured with Firebase project `marketsnap-app` and includes:

- **Authentication**: User management and secure login
- **Firestore**: NoSQL database for app data
- **Storage**: File and media storage
- **Functions**: Server-side logic
- **Analytics**: App usage tracking

### Firebase Configuration Files

The following files contain Firebase configuration and are managed securely:
- `android/app/google-services.json` (gitignored)
- `ios/Runner/GoogleService-Info.plist` (gitignored)
- `firebase.json` (gitignored)
- `.env` (gitignored - you must create this)

## CI/CD Pipeline

GitHub Actions workflow configured in `.github/workflows/main.yml`:
- **Automated testing** on push/PR to main branch
- **Flutter environment setup** with Java 11
- **Dependency installation** and health checks
- **Unit and widget tests** execution

## Project Structure

```
lib/
├── main.dart              # App entry point with secure Firebase initialization
test/
├── widget_test.dart       # Widget tests
android/                   # Android platform files
ios/                       # iOS platform files
.github/workflows/         # CI/CD pipeline configuration
```

## Development Guidelines

### Security Best Practices

1. **Never commit sensitive data** to version control
2. **Always use environment variables** for configuration
3. **Regularly rotate API keys** and update `.env` file
4. **Review `.gitignore`** before committing changes

### Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test
flutter test test/widget_test.dart
```

### Building

```bash
# Debug build
flutter build apk --debug
flutter build ios --debug

# Release build
flutter build apk --release
flutter build ios --release
```

## Troubleshooting

### Common Issues

1. **Missing .env file**
   - Error: `Exception: Unable to load asset: .env`
   - Solution: Create `.env` file with required variables

2. **Firebase initialization errors**
   - Error: `Firebase configuration not found`
   - Solution: Verify all environment variables are set correctly

3. **Platform-specific build issues**
   - Android: Check NDK installation and licenses
   - iOS: Verify Xcode and simulator setup

### Development Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase for Flutter](https://firebase.google.com/docs/flutter/setup)
- [Flutter Security Best Practices](https://docs.flutter.dev/deployment/security)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes following security guidelines
4. Test thoroughly on both platforms
5. Submit a pull request

## License

This project is private and proprietary.

---

**⚠️ Important**: Remember to create your `.env` file before running the application. The app will not function without proper environment variable configuration.
