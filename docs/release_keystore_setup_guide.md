# MarketSnap Release Keystore Setup Guide

## 🔑 Overview

This guide walks you through setting up release keystore signing for MarketSnap, both for local development and CI/CD deployment via GitHub Actions.

---

## 📋 Current Status

✅ **Debug Keystore:** Working for development  
🔧 **Release Keystore:** Created but needs Firebase console configuration  
✅ **CI/CD Pipeline:** Configured for release keystore deployment  
⚠️ **Firebase Console:** Needs new release SHA-1 fingerprint registration  

---

## 🏠 Local Development Setup

### 1. **Your Release Keystore Details**
- **Location:** `~/marketsnap-release.keystore`
- **Alias:** `marketsnap`
- **Password:** `[REDACTED_PASSWORD]`
- **SHA-1 Fingerprint:** `[REDACTED FOR SECURITY]`

### 2. **Local Configuration Files**
- **Keystore Config:** `android/key.properties` (already created)
- **Environment:** `.env` file updated with release SHA-1

### 3. **Current Build Configuration**
The app currently uses **debug signing** for release builds to ensure compatibility. To switch to release signing:

1. **Update `android/app/build.gradle.kts`:**
   ```kotlin
   release {
       signingConfig = if (keystoreProperties.containsKey("storeFile")) {
           signingConfigs.getByName("release")
       } else {
           signingConfigs.getByName("debug")
       }
       // ... rest of config
   }
   ```

2. **Test the build:**
   ```bash
   flutter build apk --release
   ```

---

## 🔥 Firebase Console Configuration

### **CRITICAL: Add Release SHA-1 to Firebase**

You **MUST** add the new release SHA-1 fingerprint to your Firebase project:

1. **Go to Firebase Console:**
   - Navigate to Project Settings → General
   - Find your Android app

2. **Add SHA-1 Fingerprint:**
   ```
   [Get from: keytool -list -v -keystore ~/marketsnap-release.keystore -alias marketsnap -storepass [REDACTED_PASSWORD] | grep SHA1]
   ```

3. **Download Updated `google-services.json`:**
   - After adding the SHA-1, download the updated config file
   - Replace `android/app/google-services.json`

4. **Update GitHub Secret:**
   - Encode the new file: `base64 -i android/app/google-services.json`
   - Update `GOOGLE_SERVICES_JSON` secret in GitHub

---

## 🚀 GitHub Actions CI/CD Setup

### **Required GitHub Secrets**

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `RELEASE_KEYSTORE_BASE64` | `[base64 encoded keystore]` | Your release keystore file |
| `KEYSTORE_PASSWORD` | `[REDACTED_PASSWORD]` | Keystore password |
| `KEY_ALIAS` | `marketsnap` | Key alias |
| `KEY_PASSWORD` | `[REDACTED_PASSWORD]` | Key password |

### **Get Base64 Encoded Keystore**
```bash
# The base64 encoded keystore is in this file:
cat ~/marketsnap-release-base64.txt
```

### **Pipeline Configuration**
The GitHub Actions workflow is already configured to:
1. ✅ Decode the base64 keystore
2. ✅ Create `key.properties` file
3. ✅ Build signed release APK
4. ✅ Deploy to Firebase App Distribution

---

## 🧪 Testing & Validation

### **Local Testing**
```bash
# Clean build with release signing
flutter clean
flutter build apk --release

# Check the APK signature
jarsigner -verify -verbose -certs build/app/outputs/flutter-apk/app-release.apk
```

### **CI/CD Testing**
1. **Push to main branch** or **trigger workflow manually**
2. **Monitor GitHub Actions** for successful build
3. **Check Firebase App Distribution** for new release

---

## 🔒 Security Best Practices

### **✅ What's Secure:**
- Keystore file is **never committed** to git (`.gitignore` configured)
- Passwords stored as **GitHub Secrets** (encrypted)
- SHA-1 fingerprints **redacted** from documentation
- Environment variables used for **development configuration**

### **⚠️ Important Notes:**
- **Backup your keystore file** securely (you need it for all future releases)
- **Never share keystore passwords** publicly
- **Use different keystores** for debug vs release
- **Keep Firebase console access** restricted

---

## 🐛 Troubleshooting

### **Build Fails with Keystore Error**
```bash
# Verify keystore works
keytool -list -keystore ~/marketsnap-release.keystore -alias marketsnap

# Check key.properties file
cat android/key.properties
```

### **Google Sign-In Issues**
- Ensure release SHA-1 is added to Firebase console
- Download updated `google-services.json`
- Update GitHub secret with new config

### **CI/CD Deployment Issues**
- Check GitHub Secrets are correctly set
- Verify base64 encoding is valid
- Monitor GitHub Actions logs for errors

---

## 📋 Next Steps

1. **🔥 Add release SHA-1 to Firebase console** (CRITICAL)
2. **📱 Test Google Sign-In** with release build
3. **🚀 Deploy via GitHub Actions** to Firebase App Distribution
4. **👥 Share with testers** via Firebase App Distribution groups

---

## 📞 Quick Commands Reference

```bash
# Get SHA-1 fingerprint
keytool -list -v -keystore ~/marketsnap-release.keystore -alias marketsnap -storepass [REDACTED_PASSWORD] | grep SHA1

# Build release APK
flutter build apk --release

# Verify APK signature
jarsigner -verify -verbose build/app/outputs/flutter-apk/app-release.apk

# Encode keystore for GitHub
base64 -i ~/marketsnap-release.keystore

# Test keystore access
keytool -list -keystore ~/marketsnap-release.keystore -alias marketsnap
``` 