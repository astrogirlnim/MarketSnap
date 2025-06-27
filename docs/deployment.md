# MarketSnap Deployment Documentation

*Last updated: January 25, 2025*

## 🚀 Deployment Overview

MarketSnap uses a comprehensive CI/CD pipeline built with GitHub Actions to automate testing, building, and deployment across multiple platforms. The pipeline features **parallel execution** of Android APK building and Firebase backend deployment for improved speed and efficiency.

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

#### 2. **Android Build** (`build_android`) - **PARALLEL EXECUTION**
**Purpose:** Build and distribute Android APK.
**Triggers:** Push to main branch only (after validation passes).
**Runtime:** `ubuntu-latest`.
**Authentication:** Authenticates to Firebase using a service account (`FIREBASE_SERVICE_ACCOUNT_KEY` secret).
**Parallelism:** Runs concurrently with `deploy_backend` job.

**Steps:**
- ✅ Checkout code
- ✅ Setup Java 17 & Flutter
- ✅ **Authenticate to Firebase using service account**
- ✅ **Generate real `firebase_options.dart`** using `flutterfire configure`
- ✅ Decode Firebase configuration (`google-services.json`)
- ✅ Install dependencies (`flutter pub get`)
- ✅ Create production `.env` file from secrets
- ✅ Setup release keystore for APK signing
- ✅ Build Android APK (`flutter build apk --release`)
- ✅ Deploy to Firebase App Distribution

#### 3. **Backend Deployment** (`deploy_backend`) - **PARALLEL EXECUTION**
**Purpose:** Deploy Firebase backend services and configure database policies.
**Triggers:** Push to main branch only (after validation passes).
**Runtime:** `ubuntu-latest`.
**Authentication:** Authenticates to Firebase using a service account (`FIREBASE_SERVICE_ACCOUNT_KEY` secret).
**Parallelism:** Runs concurrently with `build_android` job.

**Steps:**
- ✅ Checkout code
- ✅ Setup Node.js & Firebase CLI
- ✅ **Authenticate to Firebase using service account**
- ✅ Generate `firebase.json` from template
- ✅ Setup Firebase project alias
- ✅ Build and deploy Cloud Functions (`npm run build`)
- ✅ Deploy Firestore rules and Storage rules (`firebase deploy`)
- ✅ Configure TTL policies using `gcloud` CLI

#### 4. **iOS Deployment** (`deploy_ios`)
**Status:** Currently commented out (pending certificate setup)
**Purpose:** Build and distribute iOS IPA
**Runtime:** macos-latest (when enabled)

## 🔧 Configuration Details

### Parallel Execution Benefits
- **Previous Architecture:** Sequential execution (Backend → Android Build)
- **Current Architecture:** Parallel execution (Backend || Android Build)
- **Performance Improvement:** ~30-40% reduction in total pipeline time
- **Resource Efficiency:** Better utilization of GitHub Actions runners

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
FIREBASE_PROJECT_ID         # Firebase project identifier
IOS_APP_ID                  # Firebase App Distribution iOS App ID (for flutterfire configure)
RELEASE_KEYSTORE_BASE64     # Android release keystore (base64 encoded)
KEYSTORE_PASSWORD           # Android keystore password
KEY_ALIAS                   # Android key alias
KEY_PASSWORD                # Android key password
OPENAI_API_KEY              # OpenAI API key for AI features (Wicker captions, RAG suggestions)
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
3. **Parallel Execution:** 
   - **Android Build:** APK generation with production configuration
   - **Backend Deploy:** Firebase services and database policy updates
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
- **Parallel Builds:** Concurrent Android APK and backend deployment
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

#### 4. **Parallel Job Dependencies**
```bash
# Both jobs depend only on validate job
# No interdependencies between build_android and deploy_backend
# Race conditions are not a concern due to stateless operations
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
# Trigger deployment pipeline (parallel execution)
git push origin main

# Trigger validation only
git push origin feature-branch
# or create pull request to main
```

## 📊 Performance Metrics

### Build Times (Estimated)
- **Validation Stage:** ~5-8 minutes
- **Android Build (Parallel):** ~8-12 minutes
- **Backend Deploy (Parallel):** ~5-8 minutes
- **Total Pipeline:** ~13-20 minutes (previously ~18-25 minutes)
- **Time Savings:** ~30-40% improvement due to parallel execution

### Optimization Strategies
- **Parallel Jobs:** Android build and backend deployment run concurrently
- **Caching:** Flutter dependencies cached between builds
- **Selective Deployment:** Only main branch triggers builds
- **Resource Efficiency:** Better utilization of GitHub Actions runners

## 🔮 Future Enhancements

### Planned Improvements
1. **iOS Deployment:** Complete certificate setup and enable iOS pipeline
2. **Multi-Environment:** Staging and production deployment branches
3. **Automated Testing:** Integration tests in CI/CD pipeline
4. **Performance Monitoring:** Build time and app performance metrics
5. **Security Scanning:** Dependency vulnerability checks
6. **Matrix Strategy:** Multiple Flutter versions and Android API levels

### Scaling Considerations
- **Self-Hosted Runners:** For larger projects with specific requirements
- **Artifact Management:** Build artifact storage and versioning
- **Cross-Job Dependencies:** Future enhancements may require job orchestration

---

*This deployment documentation reflects the current state of the parallel pipeline architecture. All changes maintain security best practices and follow Flutter deployment guidelines while significantly improving build performance through concurrent execution.* 