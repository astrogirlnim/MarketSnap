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

# OpenAI API Key for AI Helper Functions
OPENAI_API_KEY=your_openai_api_key_here
AI_FUNCTIONS_ENABLED=false # Set to true to enable AI functions
```

### Firebase Configuration

The Firebase configuration uses a template-based system for security:

#### Template System
- `firebase.json.template` contains the Firebase configuration template with environment variables
- `firebase.json` is generated from the template using your `.env` file variables
- `firebase.json` is gitignored to prevent secrets from being committed

#### Automatic Generation
The `firebase.json` file is automatically generated:
- **During CI/CD**: Using GitHub Secrets via `envsubst`
- **During Local Development**: By `./scripts/dev_emulator.sh` using your `.env` file

#### Manual Generation (if needed)
```bash
# Generate Firebase options file (creates lib/firebase_options.dart)
flutterfire configure --project=marketsnap-app --platforms=android,ios --out=lib/firebase_options.dart

# Generate firebase.json from template (requires .env file)
envsubst < firebase.json.template > firebase.json
```

### Security Features

- ✅ **No hardcoded API keys** in source code
- ✅ **Environment-based configuration** using `flutter_dotenv`
- ✅ **Firebase options auto-generated** using FlutterFire CLI
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
- `.firebaserc` (gitignored)
- `.env` (gitignored - you must create this)

### Initial Firebase Setup

If you are setting up the project for the first time after cloning, you will need to initialize Firebase to connect to the backend and run the local emulators.

1.  **Install Firebase CLI**: If you haven't already, install the Firebase CLI globally:
    ```bash
    npm install -g firebase-tools
    ```
2.  **Login to Firebase**:
    ```bash
    firebase login
    ```
3.  **Initialize Firebase**: In the project root, run the `init` command.
    ```bash
    firebase init
    ```
    -   Select an existing project (`marketsnap-app`).
    -   Choose the following features: **Firestore, Functions, Storage, Emulators**.
    -   When prompted, do **not** overwrite the existing `firestore.rules`, `firestore.indexes.json`, or `storage.rules` files.
    -   Select **TypeScript** for Cloud Functions and enable **ESLint**.
    -   Install `npm` dependencies when prompted.
    -   Download the emulators when prompted.

## CI/CD Pipeline

GitHub Actions workflow configured in `.github/workflows/deploy.yml`:
- **Automated testing** on push/PR to main branch
- **Secure Firebase Authentication**: Uses a service account (`FIREBASE_SERVICE_ACCOUNT_KEY`) for deployment jobs.
- **Efficient PR Validation**: Generates dummy config files for pull request checks to ensure speed and security (no secrets needed).
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

### Camera Testing Development Bypass

For local development and testing of camera functionality, a development bypass is available to skip authentication:

**To Enable Camera Testing Bypass:**
1. The bypass is enabled by default in `lib/main.dart`: `const bool kDevelopmentBypassAuth = kDebugMode && true;`
2. Run the app in debug mode - you'll go directly to the camera preview
3. An orange banner will indicate "DEVELOPMENT MODE - Authentication Bypassed"

**To Test Normal Authentication Flow:**
1. Open `lib/main.dart`
2. Change `kDevelopmentBypassAuth` to `false`
3. Hot restart the app (press `R` in Flutter console)
4. Complete the normal phone/email OTP authentication flow

**Security Notes:**
- ⚠️ The bypass is **ONLY** available in debug mode (`kDebugMode`)
- It will **NEVER** work in release builds
- The bypass is clearly marked with warning banners
- Production builds are completely unaffected

### Running Local Emulators

For backend development and testing, you can run the Firebase Emulator Suite locally. This allows you to test your Cloud Functions, Firestore rules, and other Firebase features without touching production data.

**Quick Start:**
```bash
# Start Firebase emulators with automated setup
./scripts/start_emulators.sh
```

**Manual Setup Steps:**

1.  **Create Environment File**: Before starting, ensure you have a valid `.env` file in the project root. If you don't have one, copy the format from the "Security Implementation" section and fill in your project's details.

2. **Generate `firebase.json`**: The emulators require a `firebase.json` file. Generate it from the template using your `.env` file. This command substitutes the variables in the template with the values from your environment.
    ```bash
    envsubst < firebase.json.template > firebase.json
    ```

3.  **Build Cloud Functions**: The functions are written in TypeScript and must be compiled to JavaScript before the emulators can run them.
    ```bash
    cd functions
    npm install
    npm run build
    cd ..
    ```

4.  **Start Emulators**: Now you can start the emulator suite.
    ```bash
    firebase emulators:start
    ```
    This will start the emulators for Auth, Firestore, Functions, and Storage. You can view the Emulator UI at `http://127.0.0.1:4000`.

### Testing Cloud Functions Locally

Once the emulators are running, you can test your Firestore-triggered functions manually:

1.  **Open Emulator UI**: Navigate to `http://127.0.0.1:4000/` in your browser.
2.  **Go to Firestore**: Click on the "Firestore" tab.
3.  **Create Data**: Manually create documents to trigger your functions. For example, to test `sendFollowerPush`:
    *   Create a `vendors` collection with a document for a test vendor (e.g., `test-vendor-id`).
    *   Create a `snaps` collection.
    *   Add a new document to `snaps`. Make sure the document data contains a `vendorId` field pointing to your test vendor (e.g., `vendorId: "test-vendor-id"`).
4.  **Observe Logs**: As soon as you save the new snap document, the `sendFollowerPush` function will be triggered. You will see its log output directly in the terminal where you ran `firebase emulators:start`. This output will show you the function's execution path and any errors.

### Testing AI Helper Functions (Locally)

The project includes scaffolded Cloud Functions for future AI features (`generateCaption`, `getRecipeSnippet`, `vectorSearchFAQ`). You can test them locally using the emulators.

1.  **Enable AI Functions**: In your root `.env` file, set `AI_FUNCTIONS_ENABLED=true`.
2.  **Add OpenAI Key**: Ensure your `OPENAI_API_KEY` is also set in the `.env` file.
3.  **Start Emulators**: Run `firebase emulators:start` as described above.
4.  **Test with cURL**: Open a new terminal and use `curl` to call the function endpoints.

    ```bash
    # Example for generateCaption
    curl -X POST -H "Content-Type: application/json" \
    -d '{"data": {}}' \
    http://127.0.0.1:5001/marketsnap-app/us-central1/generateCaption
    ```
5.  **Check Logs**: Observe the emulator logs for output confirming the function was triggered and the API key was found.

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
   - Error: `Firebase configuration not found` or `Undefined name 'DefaultFirebaseOptions'`
   - Solution: 
     - Verify all environment variables are set correctly
     - Generate Firebase options file: `flutterfire configure --project=marketsnap-app --platforms=android,ios --out=lib/firebase_options.dart`
     - Ensure `import 'firebase_options.dart';` is present in `main.dart`

3. **HiveService initialization errors**
   - Error: `Too many positional arguments: 0 allowed, but 1 found`
   - Solution: Ensure `hiveService.init()` is called without parameters (the service handles path internally)

4. **Firebase configuration template errors**
   - Error: `firebase.json not found` when running Firebase commands
   - Solution: Generate `firebase.json` from template:
     ```bash
     # Ensure .env file exists with required variables
     envsubst < firebase.json.template > firebase.json
     ```

5. **Platform-specific build issues**
   - Android: Check NDK installation and licenses
   - iOS: Verify Xcode and simulator setup

6. **iOS Build Failure: 'Flutter/Flutter.h' not found or 'Dart compiler exited unexpectedly'**
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
