#!/bin/bash

# MarketSnap App Icon Generator
# Generates all required app icon sizes from wicker_blinking.png using macOS sips

set -e  # Exit on error

echo "🥾 MarketSnap App Icon Generator"
echo "================================"

# Paths
SOURCE_IMAGE="assets/images/icons/wicker_blinking.png"
TEMP_DIR="temp_icons"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: Source image not found at $SOURCE_IMAGE"
    exit 1
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

echo "📱 Generating Android icons..."

# Android App Icons (ic_launcher.png)
# mdpi: 48x48px (baseline)
# hdpi: 72x72px (1.5x)
# xhdpi: 96x96px (2x)
# xxhdpi: 144x144px (3x)
# xxxhdpi: 192x192px (4x)

sips -z 48 48 "$SOURCE_IMAGE" --out "$TEMP_DIR/ic_launcher_mdpi.png"
sips -z 72 72 "$SOURCE_IMAGE" --out "$TEMP_DIR/ic_launcher_hdpi.png"
sips -z 96 96 "$SOURCE_IMAGE" --out "$TEMP_DIR/ic_launcher_xhdpi.png"
sips -z 144 144 "$SOURCE_IMAGE" --out "$TEMP_DIR/ic_launcher_xxhdpi.png"
sips -z 192 192 "$SOURCE_IMAGE" --out "$TEMP_DIR/ic_launcher_xxxhdpi.png"

echo "🍎 Generating iOS icons..."

# iOS App Icons - All required sizes for AppIcon.appiconset
sips -z 20 20 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@1x.png"
sips -z 40 40 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@2x.png"
sips -z 60 60 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@3x.png"

sips -z 29 29 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@1x.png"
sips -z 58 58 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@2x.png"
sips -z 87 87 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@3x.png"

sips -z 40 40 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@1x.png"
sips -z 80 80 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@2x.png"
sips -z 120 120 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@3x.png"

sips -z 120 120 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-60x60@2x.png"
sips -z 180 180 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-60x60@3x.png"

sips -z 76 76 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-76x76@1x.png"
sips -z 152 152 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-76x76@2x.png"

sips -z 167 167 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-83.5x83.5@2x.png"

sips -z 1024 1024 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-1024x1024@1x.png"

echo "🌐 Generating Web icons..."

# Web Icons
sips -z 192 192 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-192.png"
sips -z 512 512 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-512.png"
sips -z 192 192 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-maskable-192.png"
sips -z 512 512 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-maskable-512.png"

echo "🖥️ Generating macOS icons..."

# macOS App Icons (same structure as iOS but different sizes)
sips -z 16 16 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_16.png"
sips -z 32 32 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_32.png"
sips -z 64 64 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_64.png"
sips -z 128 128 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_128.png"
sips -z 256 256 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_256.png"
sips -z 512 512 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_512.png"
sips -z 1024 1024 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon_1024.png"

echo "🪟 Generating Windows icon..."

# Windows Icon (we'll generate a 256x256 PNG - ICO conversion would need additional tools)
sips -z 256 256 "$SOURCE_IMAGE" --out "$TEMP_DIR/app_icon.png"

echo "✅ All icons generated in $TEMP_DIR directory"

echo ""
echo "📋 Now copying icons to their respective locations..."

# Copy Android icons
cp "$TEMP_DIR/ic_launcher_mdpi.png" "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_hdpi.png" "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_xhdpi.png" "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_xxhdpi.png" "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_xxxhdpi.png" "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

echo "✅ Android icons updated"

# Copy iOS icons
cp "$TEMP_DIR/Icon-App-20x20@1x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-20x20@2x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-20x20@3x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-29x29@1x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-29x29@2x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-29x29@3x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-40x40@1x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-40x40@2x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-40x40@3x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-60x60@2x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-60x60@3x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-76x76@1x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-76x76@2x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-83.5x83.5@2x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"
cp "$TEMP_DIR/Icon-App-1024x1024@1x.png" "ios/Runner/Assets.xcassets/AppIcon.appiconset/"

echo "✅ iOS icons updated"

# Copy Web icons
cp "$TEMP_DIR/Icon-192.png" "web/icons/"
cp "$TEMP_DIR/Icon-512.png" "web/icons/"
cp "$TEMP_DIR/Icon-maskable-192.png" "web/icons/"
cp "$TEMP_DIR/Icon-maskable-512.png" "web/icons/"

echo "✅ Web icons updated"

# Copy macOS icons
cp "$TEMP_DIR/app_icon_16.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
cp "$TEMP_DIR/app_icon_32.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
cp "$TEMP_DIR/app_icon_64.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
cp "$TEMP_DIR/app_icon_128.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
cp "$TEMP_DIR/app_icon_256.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
cp "$TEMP_DIR/app_icon_512.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
cp "$TEMP_DIR/app_icon_1024.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"

echo "✅ macOS icons updated"

# Copy Windows icon (if directory exists)
if [ -d "windows/runner/resources" ]; then
    cp "$TEMP_DIR/app_icon.png" "windows/runner/resources/app_icon.png"
    echo "✅ Windows icon updated"
fi

# Update main assets icon
cp "$TEMP_DIR/Icon-512.png" "assets/images/icon.png"
echo "✅ Main assets icon updated"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 SUCCESS! App icons have been updated with the wicker basket design!"
echo ""
echo "📱 Updated platforms:"
echo "   • Android (all densities)"
echo "   • iOS (all required sizes)"
echo "   • Web (PWA icons)"
echo "   • macOS (if applicable)"
echo "   • Windows (if applicable)"
echo ""
echo "🚀 Next steps:"
echo "   1. Clean and rebuild your Flutter app: flutter clean && flutter pub get"
echo "   2. Test on device/emulator to see the new icon"  
echo "   3. For iOS, you may need to delete and reinstall the app to see icon changes"
echo "" 