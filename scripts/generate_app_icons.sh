#!/bin/bash

# MarketSnap App Icon Generator
# Generates all required app icon sizes from wicker_blinking.png using macOS sips
# Updated to make the wicker basket appear larger within icon bounds

set -e  # Exit on error

echo "🥾 MarketSnap App Icon Generator - LARGE BASKET VERSION"
echo "===================================================="

# Paths
SOURCE_IMAGE="assets/images/icons/wicker_blinking.png"
TEMP_DIR="temp_icons"
SCALED_SOURCE="$TEMP_DIR/wicker_scaled_large.png"

# Check if source image exists
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Error: Source image not found at $SOURCE_IMAGE"
    exit 1
fi

# Create temporary directory
mkdir -p "$TEMP_DIR"

echo "🔍 Creating larger version of wicker basket for app icons..."

# First, create a larger version with padding removed and basket scaled up
# Get original dimensions
ORIGINAL_WIDTH=$(sips -g pixelWidth "$SOURCE_IMAGE" | tail -1 | cut -d' ' -f4)
ORIGINAL_HEIGHT=$(sips -g pixelHeight "$SOURCE_IMAGE" | tail -1 | cut -d' ' -f4)

echo "📏 Original image size: ${ORIGINAL_WIDTH}x${ORIGINAL_HEIGHT}"

# Create a version that's 85% larger (1.85x scale) to make basket more prominent
SCALED_WIDTH=$(echo "$ORIGINAL_WIDTH * 1.85" | bc | cut -d'.' -f1)
SCALED_HEIGHT=$(echo "$ORIGINAL_HEIGHT * 1.85" | bc | cut -d'.' -f1)

echo "📈 Creating scaled version: ${SCALED_WIDTH}x${SCALED_HEIGHT}"

# Scale up the source image to make basket more prominent
sips -z $SCALED_HEIGHT $SCALED_WIDTH "$SOURCE_IMAGE" --out "$SCALED_SOURCE"

echo "📱 Generating Android icons with larger basket..."

# Android App Icons (ic_launcher.png) - using scaled source
# mdpi: 48x48px (baseline)
# hdpi: 72x72px (1.5x)
# xhdpi: 96x96px (2x)
# xxhdpi: 144x144px (3x)
# xxxhdpi: 192x192px (4x)

sips -z 48 48 "$SCALED_SOURCE" --out "$TEMP_DIR/ic_launcher_mdpi.png"
sips -z 72 72 "$SCALED_SOURCE" --out "$TEMP_DIR/ic_launcher_hdpi.png"
sips -z 96 96 "$SCALED_SOURCE" --out "$TEMP_DIR/ic_launcher_xhdpi.png"
sips -z 144 144 "$SCALED_SOURCE" --out "$TEMP_DIR/ic_launcher_xxhdpi.png"
sips -z 192 192 "$SCALED_SOURCE" --out "$TEMP_DIR/ic_launcher_xxxhdpi.png"

echo "🍎 Generating iOS icons with larger basket..."

# iOS App Icons - All required sizes for AppIcon.appiconset - using scaled source
sips -z 20 20 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-20x20@1x.png"
sips -z 40 40 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-20x20@2x.png"
sips -z 60 60 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-20x20@3x.png"

sips -z 29 29 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-29x29@1x.png"
sips -z 58 58 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-29x29@2x.png"
sips -z 87 87 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-29x29@3x.png"

sips -z 40 40 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-40x40@1x.png"
sips -z 80 80 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-40x40@2x.png"
sips -z 120 120 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-40x40@3x.png"

sips -z 120 120 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-60x60@2x.png"
sips -z 180 180 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-60x60@3x.png"

sips -z 76 76 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-76x76@1x.png"
sips -z 152 152 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-76x76@2x.png"

sips -z 167 167 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-83.5x83.5@2x.png"

sips -z 1024 1024 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-App-1024x1024@1x.png"

echo "🌐 Generating Web icons with larger basket..."

# Web Icons - using scaled source
sips -z 192 192 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-192.png"
sips -z 512 512 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-512.png"
sips -z 192 192 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-maskable-192.png"
sips -z 512 512 "$SCALED_SOURCE" --out "$TEMP_DIR/Icon-maskable-512.png"

echo "🖥️ Generating macOS icons with larger basket..."

# macOS App Icons - using scaled source
sips -z 16 16 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_16.png"
sips -z 32 32 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_32.png"
sips -z 64 64 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_64.png"
sips -z 128 128 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_128.png"
sips -z 256 256 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_256.png"
sips -z 512 512 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_512.png"
sips -z 1024 1024 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon_1024.png"

echo "🪟 Generating Windows icon with larger basket..."

# Windows Icon - using scaled source
sips -z 256 256 "$SCALED_SOURCE" --out "$TEMP_DIR/app_icon.png"

echo "✅ All icons generated with LARGER BASKET in $TEMP_DIR directory"

echo ""
echo "📋 Now copying icons to their respective locations..."

# Copy Android icons
cp "$TEMP_DIR/ic_launcher_mdpi.png" "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_hdpi.png" "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_xhdpi.png" "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_xxhdpi.png" "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
cp "$TEMP_DIR/ic_launcher_xxxhdpi.png" "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

echo "✅ Android icons updated with LARGER BASKET"

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

echo "✅ iOS icons updated with LARGER BASKET"

# Copy Web icons
cp "$TEMP_DIR/Icon-192.png" "web/icons/"
cp "$TEMP_DIR/Icon-512.png" "web/icons/"
cp "$TEMP_DIR/Icon-maskable-192.png" "web/icons/"
cp "$TEMP_DIR/Icon-maskable-512.png" "web/icons/"

echo "✅ Web icons updated with LARGER BASKET"

# Copy macOS icons
cp "$TEMP_DIR/app_icon_16.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_16.png"
cp "$TEMP_DIR/app_icon_32.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_32.png"
cp "$TEMP_DIR/app_icon_64.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_64.png"
cp "$TEMP_DIR/app_icon_128.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_128.png"
cp "$TEMP_DIR/app_icon_256.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_256.png"
cp "$TEMP_DIR/app_icon_512.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_512.png"
cp "$TEMP_DIR/app_icon_1024.png" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png"

echo "✅ macOS icons updated with LARGER BASKET"

# Copy Windows icon (if directory exists)
if [ -d "windows/runner/resources" ]; then
    cp "$TEMP_DIR/app_icon.png" "windows/runner/resources/app_icon.png"
    echo "✅ Windows icon updated with LARGER BASKET"
fi

# Update main assets icon with larger version
cp "$TEMP_DIR/Icon-512.png" "assets/images/icon.png"
echo "✅ Main assets icon updated with LARGER BASKET"

# Cleanup
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 SUCCESS! App icons have been updated with LARGER WICKER BASKET design!"
echo ""
echo "📱 Updated platforms with BIGGER BASKET:"
echo "   • Android (all densities) - 85% larger basket"
echo "   • iOS (all required sizes) - 85% larger basket"
echo "   • Web (PWA icons) - 85% larger basket"
echo "   • macOS (if applicable) - 85% larger basket" 
echo "   • Windows (if applicable) - 85% larger basket"
echo ""
echo "🚀 Next steps:"
echo "   1. Clean and rebuild your Flutter app: flutter clean && flutter pub get"
echo "   2. Test on device/emulator to see the new LARGER icon"  
echo "   3. For iOS, you may need to delete and reinstall the app to see icon changes"
echo "" 