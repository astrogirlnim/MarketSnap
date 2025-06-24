# MarketSnap Project File Structure

*Last updated: June 24, 2025*

## 📁 Project Overview

MarketSnap is a cross-platform mobile application built with Flutter and Firebase backend. This document outlines the complete file structure and organization principles.

## 🗂️ Root Directory Structure

```
MarketSnap/
├── .github/           # GitHub workflows and CI/CD pipelines
├── android/           # Android platform-specific files  
├── docs/             # Project documentation
├── documentation/    # Business and design documentation
├── ios/              # iOS platform-specific files
├── lib/              # Flutter application source code
├── linux/            # Linux platform support
├── macos/            # macOS platform support  
├── scripts/          # Development automation scripts
├── test/             # Unit and widget tests
├── web/              # Web platform support
├── windows/          # Windows platform support
├── .env              # Environment variables (gitignored)
├── .gitignore        # Git ignore patterns
├── pubspec.yaml      # Flutter project configuration
└── README.md         # Main project documentation
```

## 📂 Directory Details

### 📋 Documentation Structure (`/docs` and `/documentation`)

**docs/** - Technical documentation
- `file_structure.md` - This file (project structure reference)

**documentation/** - Business and design documentation  
- `BrainLift/` - Product requirements and concepts
  - `MarketSnap_Lite_PRD_v1.1.md` - Product Requirements Document
  - `MarketSnap_Lite_User_Stories.md` - User stories and scenarios
  - `MarketSnap_Lite_Concept_v*.md` - Concept iterations
  - `MarketSnap_BrainLift_Questions.md` - Q&A and clarifications
  - `Roam-Export-*.zip` - Research exports
- `deployment/` - Deployment configuration and secrets
  - `SECREts.md` - Secret management documentation  
- `frontend_snapchat_refs/` - UI/UX reference materials (gitignored)
  - `Snapchat iOS Onboarding/` - Screenshot references for UI design
- `MarketSnap_Lite_MVP_Checklist.md` - Development checklist

### 🚀 Development Scripts (`/scripts`)

**Purpose:** Automation tools for development workflow

- `dev_emulator.sh` - Dual-platform emulator launcher with enhanced error handling
- `README.md` - Scripts documentation and usage instructions

**Key Features:**
- iOS Simulator and Android Emulator management
- Flutter hot reload support on both platforms  
- Comprehensive logging and cleanup
- Prerequisites checking and environment setup

### 🤖 CI/CD Pipeline (`/.github`)

**workflows/**
- `deploy.yml` - Main CI/CD pipeline for testing and deployment

**Pipeline Features:**
- Code validation (analyzer, tests) 
- Android APK builds (switched from AAB)
- Firebase App Distribution deployment
- Secure environment variable management
- iOS deployment (currently commented out)

### 📱 Platform Directories

**android/** - Android platform configuration
- `app/build.gradle.kts` - Build configuration with Firebase integration
- `app/src/main/AndroidManifest.xml` - App permissions and configuration
- `app/google-services.json` - Firebase configuration (gitignored)

**ios/** - iOS platform configuration  
- `Runner.xcodeproj/` - Xcode project configuration
- `Runner/Info.plist` - iOS app configuration
- `Runner/GoogleService-Info.plist` - Firebase configuration (gitignored)  
- `Podfile` - CocoaPods dependencies
- Enhanced Firebase Core compatibility (fixed deployment target)

**lib/** - Flutter application source code
- `main.dart` - Application entry point with Firebase initialization

**test/** - Testing infrastructure
- `widget_test.dart` - Flutter widget tests

### 🔒 Security and Configuration

**Environment Management:**
- `.env` - Environment variables (gitignored, required for Firebase config)
- `firebase.json` - Firebase project configuration (gitignored)
- Platform-specific Firebase config files (gitignored)

**Gitignore Patterns:**
- Firebase configuration files
- Environment variables
- Build artifacts  
- Platform-specific generated files
- Frontend reference materials (`documentation/frontend_snapchat_refs/`)
- Flutter logs and temporary files

## 🎯 File Organization Principles

### 1. **Separation of Concerns**
- Technical docs in `/docs`
- Business docs in `/documentation`  
- Platform-specific code in respective directories
- Shared Flutter code in `/lib`

### 2. **Security First**
- All sensitive configurations gitignored
- Environment-based secret management
- No hardcoded API keys or credentials

### 3. **Cross-Platform Support**
- Dedicated directories for each target platform
- Shared business logic in Flutter layer
- Platform-specific configurations isolated

### 4. **Development Workflow**
- Automated scripts for common tasks
- Comprehensive CI/CD pipeline
- Testing infrastructure in place
- Hot reload and emulator management

## 📊 Current Status

### ✅ Completed Features
- [x] Flutter project bootstrap with Firebase integration
- [x] Cross-platform build configuration (Android/iOS)
- [x] CI/CD pipeline with automated testing
- [x] Development emulator automation  
- [x] Security-first configuration management
- [x] Comprehensive documentation structure

### 🚧 In Progress (MVP Development)
- [ ] Phase 1: Foundation (Flutter 3, Firebase SDKs, local storage)
- [ ] Phase 2: Data Layer (Firestore schema, Cloud Functions)
- [ ] Phase 3: Interface Layer (Auth, camera, feed UI)
- [ ] Phase 4: Implementation Layer (offline sync, AI features)

*See `documentation/MarketSnap_Lite_MVP_Checklist.md` for detailed progress tracking*

## 🔄 Recent Changes (fix-deploy branch)

### CI/CD Improvements
- **APK Build Switch**: Changed from Android App Bundle to APK for simplified testing
- **Pipeline Optimization**: Enhanced build process for faster deployments

### Development Experience  
- **Enhanced Emulator Script**: Improved error handling and iOS/Android dual-platform support
- **Better Logging**: Added comprehensive logging throughout development tools

### Documentation Expansion
- **BrainLift Integration**: Added comprehensive product documentation
- **UI References**: Integrated Snapchat-inspired design references
- **Security Updates**: Enhanced gitignore patterns for sensitive materials

## 🚀 Next Steps

1. **Complete MVP Phase 1**: Foundation setup with local data stores
2. **Implement Authentication**: Firebase Auth with phone/email OTP
3. **Build Camera Interface**: Photo/video capture and review
4. **Add Cloud Functions**: Server-side logic for push notifications
5. **Integrate AI Features**: Caption generation and recipe snippets

---

*This file structure follows clean architecture principles and Flutter best practices. All changes should maintain this organization and update this documentation accordingly.* 