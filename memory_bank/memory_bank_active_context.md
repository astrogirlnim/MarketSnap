# Active Context

*Last Updated: January 25, 2025*

---

## Current Work Focus

**Phase 3.1: Auth & Profile Screens + Design System Implementation + Google Auth**

We have successfully implemented a comprehensive MarketSnap design system and redesigned the authentication experience. Currently troubleshooting Google Auth integration.

1. **Design System Implementation** ✅ **COMPLETED**
   - ✅ Created comprehensive theme system based on `snap_design.md`
   - ✅ Implemented color palette with farmers-market warmth (cornsilk, market blue, harvest orange, etc.)
   - ✅ Built typography system using Inter font with proper hierarchy 
   - ✅ Established 4px grid spacing system for consistency
   - ✅ Created reusable MarketSnap component library
   - ✅ Added support for light/dark themes with automatic switching

2. **Login Screen Redesign** ✅ **COMPLETED**
   - ✅ Redesigned AuthWelcomeScreen to match `login_page.png` reference
   - ✅ Integrated basket character icon from `icon.png` 
   - ✅ Implemented "Sign Up as Vendor" and "Log In" buttons as shown in reference
   - ✅ Added cornsilk background with farmers-market aesthetic
   - ✅ Created responsive layout with proper spacing and accessibility

3. **Authentication Flow Enhancement** ✅ **COMPLETED**
   - ✅ Updated all auth screens (email, phone, OTP) with new design system
   - ✅ Maintained cross-platform iOS/Android compatibility
   - ✅ Enhanced user experience with improved error handling and loading states
   - ✅ Added animated components for better user feedback

4. **Phone/Email OTP Authentication Flow** ✅ **COMPLETED**
   - ✅ Firebase Auth integration with OTP verification implemented
   - ✅ Authentication screens created and updated with new design system
   - ✅ Cross-platform support for iOS and Android with platform-specific handling
   - ✅ Firebase emulator integration working for local development
   - ✅ Network security configuration for Android cleartext HTTP to emulators
   - ✅ iOS-specific crash prevention and fallback mechanisms

5. **Google Authentication Integration** 🔄 **IN PROGRESS**
   - ✅ Google Sign-In dependencies added (`firebase_auth: ^5.6.0`, `google_sign_in: ^6.2.1`)
   - ✅ `signInWithGoogle()` method implemented in AuthService
   - ✅ Google Sign-In button integrated into AuthWelcomeScreen with MarketSnap design
   - ✅ Firebase Console Google Auth provider enabled
   - ✅ SHA-1 fingerprint identified: `[REDACTED FOR SECURITY]`
   - 🔄 **CURRENT ISSUE:** ApiException: 10 (DEVELOPER_ERROR) - SHA-1 not registered in Firebase Console
   - 📋 **NEXT:** Replace google-services.json and GoogleService-Info.plist with updated versions from Firebase Console

6. **Profile Form Implementation** ✅ **COMPLETED**
   - ✅ Vendor profile creation/editing (stall name, market city, avatar upload)
   - ✅ Offline caching validation in Hive
   - ✅ Apply new design system to profile screens

## Recent Changes

- **✅ Google Auth Implementation:** Added Google Sign-In as third authentication option with proper error handling and UI integration
- **✅ Debug SHA-1 Identification:** Found debug keystore SHA-1 fingerprint for Firebase Console registration
- **✅ Firebase Console Configuration:** Enabled Google Auth provider in Firebase Console
- **🔄 Configuration Files:** Downloaded updated google-services.json and GoogleService-Info.plist from Firebase Console
- **✅ Error Analysis:** Identified ApiException: 10 as missing SHA-1 registration issue
- **✅ Production Security Review:** Discovered current GitHub Actions uses debug keystore for release builds (security issue)

## Current Status

**Google Auth Troubleshooting:**
- ✅ Code Implementation: Google Sign-In fully implemented with proper error handling
- ✅ Dependencies: All required packages installed and configured
- ✅ Firebase Console: Google Auth provider enabled, SHA-1 fingerprint identified
- 🔄 **CURRENT STEP:** Replace configuration files with updated versions from Firebase Console
- 📋 **NEXT:** Test Google Sign-In functionality in emulator
- ⚠️ **SECURITY ISSUE:** Production builds currently use debug keystore (needs release keystore setup)

**File Replacement Required:**
- 📱 **Android:** Replace `android/app/google-services.json` with downloaded version
- 🍎 **iOS:** Replace `ios/Runner/GoogleService-Info.plist` with downloaded version

## Next Steps

1. ✅ ~~Implement Google Auth code~~ **DONE**
2. ✅ ~~Enable Google Auth in Firebase Console~~ **DONE** 
3. ✅ ~~Identify debug SHA-1 fingerprint~~ **DONE**
4. 🔄 **CURRENT:** Replace Firebase configuration files with updated versions
5. 📋 **NEXT:** Test Google Sign-In in emulator after configuration update
6. 📋 **NEXT:** Set up production release keystore for GitHub Actions
7. 📋 **NEXT:** Apply design system to camera capture screens

## Critical Issues Identified

### **Production Security Issue:**
- **Problem:** GitHub Actions builds release APKs with debug keystore
- **Risk:** Debug keystores are public and insecure
- **Impact:** Google Play Store will reject debug-signed apps
- **Solution Required:** Create production release keystore and update GitHub Actions pipeline

### **Google Auth Configuration:**
- **Problem:** ApiException: 10 (DEVELOPER_ERROR) 
- **Cause:** SHA-1 fingerprint not registered in Firebase Console
- **Solution:** Replace configuration files with updated versions from Firebase Console

---

## Technical Implementation Details

- **Google Auth Service:** `signInWithGoogle()` method in AuthService with proper error handling
- **UI Integration:** Google Sign-In button in AuthWelcomeScreen using MarketSnap design system
- **Error Handling:** Comprehensive error messages for Google Sign-In failures
- **Cross-Platform:** Works on both Android and iOS (bypasses Firebase Auth emulator as expected)
- **Security:** Uses secure Google OAuth2 flow via google_sign_in package

## Known Issues / Notes

- **Google Auth:** Currently failing with ApiException: 10 due to missing SHA-1 registration
- **Production Security:** Release builds use debug keystore (critical security issue)
- **Emulator Behavior:** Google Sign-In bypasses Firebase Auth emulator (expected behavior)
- **Configuration Files:** Need to be replaced with updated versions from Firebase Console

## Project Status Overview

- **✅ Phase 1 - Foundation:** Complete
- **✅ Phase 2 - Data Layer:** Complete  
- **✅ Phase 3.1 - Auth & Profile Screens:** Complete (Auth + comprehensive design system + profile forms)
- **🔄 Phase 3 - Interface Layer:** In Progress (Capture screens next, then story reel & feed)
- **📋 Phase 4 - Implementation Layer:** Pending

## Design System Highlights

- **Color Palette:** Market Blue (#007AFF), Harvest Orange (#FF9500), Leaf Green (#34C759), Cornsilk (#FFF6D9), Seed Brown (#C8B185)
- **Typography:** Inter font family with 6 distinct styles (Display, H1, H2, Body-LG, Body, Caption, Label)
- **Spacing:** 4px grid system with semantic spacing constants
- **Components:** 10+ branded components including buttons, inputs, cards, status messages, loading indicators
- **Accessibility:** 48x48px minimum touch targets, 4.5:1 contrast ratios, proper semantic markup
- **Themes:** Light/dark mode support with automatic system detection

## Known Issues / Notes

- iOS phone authentication disabled in simulator due to platform limitations (proper user messaging in place)
- Firebase emulators must be running for local development
- All authentication flows tested and working with new design system
- Asset organization completed with proper file structure for icons and backgrounds

## 2024-07 Emulator Auth Flow Update

- Firestore emulator port changed to 8081 to resolve port conflict
- All Firebase emulators (auth, firestore, storage) running on:
  - Auth: 9099
  - Firestore: 8081
  - Storage: 9199
- Google, email, and phone number sign-in are all supported in the emulator environment
- Sign out flow improved: button added to camera screen, with confirmation and error handling
- Troubleshooting: Always restart both emulators and app after port changes to avoid stuck sign out or failed sign in
- Emulator UI at http://localhost:4000/ shows test phone/SMS codes for phone auth
- All flows tested and working as of July 2024



