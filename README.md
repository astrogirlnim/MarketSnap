# MarketSnap

A cross-platform mobile application built with Flutter and Firebase backend, supporting both iOS and Android platforms.

## Project Overview

MarketSnap is a Flutter application configured with:
- **Cross-platform support**: iOS and Android
- **Firebase backend**: Authentication, Firestore, Storage, and Functions
- **Secure configuration**: Environment-based secret management
- **CI/CD pipeline**: GitHub Actions for automated testing and deployment
- **Development automation**: Enhanced emulator scripts with dual-platform support
- **Comprehensive documentation**: Business requirements, technical specs, and UI references

## Background Sync (WorkManager)

MarketSnap supports robust background media sync on both Android and iOS using the `workmanager` package:

- **Android**: Background tasks run reliably using WorkManager. Execution is tracked via SharedPreferences and can be verified in-app.
- **iOS**: Background tasks are supported, but iOS imposes strict limitations. Tasks may not execute immediately and cannot use SharedPreferences in the background isolate. **To verify execution, check the console logs for `[Background Isolate]` messages.**

### How to Test Background Sync

#### Android
1. Tap "Schedule One-Time Task" in the app
2. Task will execute in the background (even if the app is backgrounded)
3. Check status in-app or via logs

#### iOS
1. Tap "Schedule One-Time Task" in the app
2. Background the app (swipe up, open another app)
3. Wait 30+ seconds
4. Return to the app
5. **Check the console logs for:**
   - `[Background Isolate] iOS: Background task executed successfully`
   - `[Background Isolate] iOS: Task execution timestamp: ...`

**Note:** iOS may delay or throttle background execution. This is a platform limitation.

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

GitHub Actions workflow configured in `.github/workflows/deploy.yml`:
- **Automated testing** on push/PR to main branch
- **Flutter environment setup** with Java 17
- **Code validation** with Flutter analyzer and tests
- **Android APK builds** for streamlined testing (switched from AAB)
- **Firebase App Distribution** deployment to testers
- **Secure environment management** with encrypted secrets

## Project Structure

```
MarketSnap/
├── .github/workflows/     # CI/CD pipeline configuration
├── android/               # Android platform files with Firebase integration
├── docs/                  # Technical documentation
├── documentation/         # Business requirements and design references
│   ├── BrainLift/        # Product specifications and user stories
│   ├── deployment/       # Deployment and security documentation
│   └── frontend_snapchat_refs/ # UI/UX inspiration materials
├── ios/                   # iOS platform files with enhanced Firebase compatibility
├── lib/                   # Flutter application source code
│   └── main.dart         # App entry point with secure Firebase initialization
├── scripts/               # Development automation tools
│   ├── dev_emulator.sh   # Dual-platform emulator launcher
│   └── README.md         # Scripts documentation
├── test/                  # Testing infrastructure
│   └── widget_test.dart  # Widget tests
└── web/                   # Web platform support
```

*See `docs/file_structure.md` for complete project organization details.*

## Development Workflow

### Enhanced Development Environment

The project includes automated development tools for streamlined cross-platform development:

```bash
# Launch both iOS and Android emulators with hot reload
./scripts/dev_emulator.sh

# This script provides:
# ✅ Prerequisites checking (Flutter, Android SDK, Xcode)
# 🍎 iOS Simulator management
# 🤖 Android Emulator management  
# 📱 Dual-platform app deployment
# 🔄 Hot reload support on both platforms
# 📊 Real-time monitoring and logging
# 🧹 Comprehensive cleanup on exit
```

**Features:**
- **Parallel Development**: Test on both platforms simultaneously
- **Smart Emulator Detection**: Reuses booted simulators when available
- **Enhanced Error Handling**: Robust process management and cleanup
- **Live Logging**: Real-time logs saved to `scripts/flutter_*.log`
- **Hot Reload**: Press `r` in either console to hot reload

### Development Scripts

All development automation is documented in `scripts/README.md` with comprehensive usage instructions.

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

# Release build (APK for testing)
flutter build apk --release
flutter build ios --release

# Note: CI/CD pipeline builds APK (not AAB) for simplified testing distribution
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

4. **iOS Build Failure: 'Flutter/Flutter.h' not found or 'Dart compiler exited unexpectedly'**
   - This project requires two specific modifications to the default iOS project structure.
   - **Symptom 1:** Build fails with `'Flutter/Flutter.h' file not found`.
   - **Symptom 2:** Build succeeds, but the app crashes on launch with `the Dart compiler exited unexpectedly.`
   - **Solution:**
        1.  **Framework Search Paths**: Ensure your `ios/Podfile`'s `post_install` script explicitly adds the Flutter framework to the search paths. This is a non-standard modification required for this project's dependencies to link correctly.
            ```ruby
            post_install do |installer|
              installer.pods_project.targets.each do |target|
                flutter_additional_ios_build_settings(target)
                target.build_configurations.each do |config|
                  config.build_settings['FRAMEWORK_SEARCH_PATHS'] = [
                    '$(inherited)',
                    '${PODS_ROOT}/../Flutter'
                  ]
                end
              end
            end
            ```
        2.  **Profile Configuration**: The `pod install` command may show a warning about the `profile` configuration. To fix this, create a new file at `ios/Flutter/Profile.xcconfig` and add the following lines to it:
            ```
            #include "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"
            #include "Generated.xcconfig"
            ```
        3.  After making these changes, run `flutter clean`, then delete the `ios/Pods`, `ios/Podfile.lock`, and `ios/Runner.xcworkspace` directories and run `flutter pub get` and `pod install` from the `ios` directory.

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
