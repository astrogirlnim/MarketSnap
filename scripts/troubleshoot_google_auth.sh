#!/bin/bash

# MarketSnap Google Auth Troubleshooting Script
# This script helps diagnose and fix Google Sign-In issues

echo "🔍 MarketSnap Google Auth Troubleshooting"
echo "========================================="

echo ""
echo "📋 Step 1: Checking current configuration..."

# Check if google-services.json exists and has oauth_client entries
if [ -f "android/app/google-services.json" ]; then
    echo "✅ google-services.json found"
    oauth_clients=$(grep -c "oauth_client" android/app/google-services.json)
    if [ $oauth_clients -gt 0 ]; then
        echo "✅ oauth_client entries found: $oauth_clients"
    else
        echo "❌ No oauth_client entries found in google-services.json"
    fi
else
    echo "❌ google-services.json not found"
fi

# Check if GoogleService-Info.plist exists
if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "✅ GoogleService-Info.plist found"
else
    echo "❌ GoogleService-Info.plist not found"
fi

echo ""
echo "📋 Step 2: Checking SHA-1 fingerprint..."
cd android
./gradlew signingReport | grep -A 2 -B 2 "SHA1:" | head -n 5
cd ..

echo ""
echo "📋 Step 3: Checking connected devices..."
flutter devices

echo ""
echo "📋 Step 4: Checking emulator Google Play Services..."
adb shell "dumpsys package com.google.android.gms | grep versionName" | head -n 1

echo ""
echo "📋 Step 5: Performing clean rebuild..."
echo "🧹 Cleaning Flutter project..."
flutter clean

echo "📦 Getting dependencies..."
flutter pub get

echo "🏗️ Building debug APK..."
flutter build apk --debug

echo ""
echo "📋 Step 6: Installing fresh APK..."
adb install -r build/app/outputs/flutter-apk/app-debug.apk

echo ""
echo "✅ Troubleshooting complete!"
echo ""
echo "🔧 Additional troubleshooting steps:"
echo "1. Try restarting the emulator completely"
echo "2. Update Google Play Services in the emulator"
echo "3. Check internet connectivity in the emulator"
echo "4. Try using a different emulator device"
echo ""
echo "💡 If issue persists, try these emulator commands:"
echo "   adb shell am start -a android.intent.action.VIEW -d 'https://google.com'"
echo "   adb shell pm list packages | grep google"
echo "" 