# MarketSnap Deployment Documentation

*Last updated: June 24, 2025*

## 🚀 Deployment Overview

MarketSnap uses a comprehensive CI/CD pipeline built with GitHub Actions to automate testing, building, and deployment across multiple platforms.

## 📋 Pipeline Architecture

### Workflow File Location
- `.github/workflows/deploy.yml` - Main CI/CD pipeline configuration

### Pipeline Stages

#### 1. **Validation Stage** (`validate`)
**Purpose:** Code quality assurance and testing.
**Triggers:** All pull requests and pushes to main branch.
**Runtime:** `ubuntu-latest`.
**Authentication:** Does **not** use real credentials. Generates a dummy `firebase_options.dart` to allow `flutter analyze` to pass quickly and securely.

**Steps:**
- ✅ Checkout code
- ✅ Setup Java 17 (Zulu distribution)
- ✅ Setup Flutter (stable channel)
- ✅ Create dummy `firebase_options.dart` and `.env` files
- ✅ Install dependencies (`flutter pub get`)
- ✅ Run Flutter analyzer (`flutter analyze`)
- ✅ Execute unit tests (`flutter test`)

#### 2. **Android Deployment** (`deploy_android`)
**Purpose:** Build and distribute Android APK.
**Triggers:** Push to main branch only (after validation passes).
**Runtime:** `ubuntu-latest`.
**Authentication:** Authenticates to Firebase using a service account (`FIREBASE_SERVICE_ACCOUNT_KEY` secret).

**Steps:**
- ✅ Checkout code
- ✅ Setup Java 17 & Flutter
- ✅ **Authenticate to Firebase using service account**
- ✅ **Generate real `firebase_options.dart`** using `flutterfire configure`
- ✅ Decode Firebase configuration (`google-services.json`)
- ✅ Install dependencies (`flutter pub get`)
- ✅ Create production `.env` file from secrets
- ✅ Build Android APK (`flutter build apk --release`)
- ✅ Deploy to Firebase App Distribution

#### 3. **iOS Deployment** (`deploy_ios`)
**Status:** Currently commented out (pending certificate setup)
**Purpose:** Build and distribute iOS IPA
**Runtime:** macos-latest (when enabled)

## 🔧 Configuration Details

### Build Configuration Changes

#### Android APK vs AAB
- **Previous:** Android App Bundle (AAB) build
- **Current:** Android APK build
- **Reason:** Simplified testing distribution without Google Play Store requirements
- **Build Command:** `flutter build apk --release`
- **Output Path:** `build/app/outputs/flutter-apk/app-release.apk`

#### Java Runtime
- **Version:** Java 17 (upgraded from Java 11)
- **Distribution:** Zulu OpenJDK
- **Compatibility:** Enhanced for latest Android toolchain

### Security Management

#### Required GitHub Secrets
```
ANDROID_APP_ID              # Firebase App Distribution Android App ID
FIREBASE_SERVICE_ACCOUNT_KEY # Firebase service account JSON (base64 encoded)
GOOGLE_SERVICES_JSON        # Android google-services.json (base64 encoded)
DOTENV                      # Production environment variables
```

#### Environment Variables Structure
```env
# Firebase API Keys
ANDROID_API_KEY=<android_api_key>
IOS_API_KEY=<ios_api_key>

# Firebase Project Configuration
FIREBASE_PROJECT_ID=<project_id>
FIREBASE_PROJECT_NUMBER=<project_number>
FIREBASE_MESSAGING_SENDER_ID=<sender_id>
FIREBASE_STORAGE_BUCKET=<storage_bucket>

# Firebase App IDs
ANDROID_APP_ID=<android_app_id>
IOS_APP_ID=<ios_app_id>

# App Bundle/Package Identifiers
APP_BUNDLE_ID=<bundle_id>
```

## 📱 Deployment Targets

### Firebase App Distribution
- **Service:** Firebase App Distribution
- **Target Groups:** `testers`
- **Platform:** Android APK
- **Automation:** GitHub Actions integration

### Distribution Workflow
1. **Code Push:** Developer pushes to main branch
2. **Validation:** Automated testing and code analysis
3. **Build:** APK generation with production configuration
4. **Deploy:** Automatic distribution to Firebase App Distribution
5. **Notification:** Testers receive update notification

## 🛠️ Development vs Production

### Development Environment
- **Emulator Support:** Dual iOS/Android emulator script
- **Hot Reload:** Real-time code updates
- **Local Testing:** `flutter run` with debug builds
- **Firebase:** Development project configuration

### Production Pipeline
- **Automated Testing:** Full test suite execution
- **Release Builds:** Optimized APK generation
- **Secure Configuration:** Encrypted environment variables
- **Firebase:** Production project configuration

## 🔍 Monitoring and Debugging

### Build Logs
- **GitHub Actions:** Complete build logs in workflow runs
- **Firebase Console:** Deployment status and distribution metrics
- **Local Development:** `scripts/flutter_*.log` files

### Common Issues and Solutions

#### 1. **Build Failures**
```bash
# Check Flutter configuration
flutter doctor -v

# Verify environment variables
echo $ANDROID_HOME
echo $JAVA_HOME

# Clean build cache
flutter clean
flutter pub get
```

#### 2. **Firebase Configuration Issues**
```bash
# Verify Firebase setup
firebase projects:list
firebase use <project-id>

# Check service account permissions
# - Firebase App Distribution Admin
# - Firebase Admin SDK
```

#### 3. **Android Build Issues**
```bash
# Check Android SDK installation
sdkmanager --list_installed

# Verify Gradle configuration
cd android && ./gradlew clean

# Check NDK compatibility
flutter config --android-sdk <path>
```

## 🚀 Deployment Commands

### Manual Deployment (Local)
```bash
# Build Android APK
flutter build apk --release

# Build iOS IPA (requires macOS and certificates)
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist

# Firebase App Distribution (manual)
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app <app-id> \
  --groups testers
```

### CI/CD Triggers
```bash
# Trigger deployment pipeline
git push origin main

# Trigger validation only
git push origin feature-branch
# or create pull request to main
```

## 📊 Performance Metrics

### Build Times
- **Validation Stage:** ~5-8 minutes
- **Android Build:** ~10-15 minutes
- **Total Pipeline:** ~15-20 minutes

### Optimization Strategies
- **Caching:** Flutter dependencies cached between builds
- **Parallel Jobs:** Validation runs independently
- **Selective Deployment:** Only main branch triggers builds

## 🔮 Future Enhancements

### Planned Improvements
1. **iOS Deployment:** Complete certificate setup and enable iOS pipeline
2. **Multi-Environment:** Staging and production deployment branches
3. **Automated Testing:** Integration tests in CI/CD pipeline
4. **Performance Monitoring:** Build time and app performance metrics
5. **Security Scanning:** Dependency vulnerability checks

### Scaling Considerations
- **Self-Hosted Runners:** For larger projects with specific requirements
- **Matrix Strategy:** Multiple Flutter versions and Android API levels
- **Artifact Management:** Build artifact storage and versioning

---

*This deployment documentation reflects the current state of the fix-deploy branch improvements. All changes maintain security best practices and follow Flutter deployment guidelines.* 