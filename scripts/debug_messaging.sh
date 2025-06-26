#!/bin/bash

echo "🔍 MarketSnap Messaging Debug Script"
echo "======================================"

# Check if emulators are running
echo "1. Checking Firebase Emulators..."
if curl -s http://127.0.0.1:4000/ > /dev/null; then
    echo "✅ Firebase Emulator UI is running"
else
    echo "❌ Firebase Emulator UI is not accessible"
    echo "   Please run: ./scripts/dev_emulator.sh"
    exit 1
fi

if curl -s http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/\(default\)/documents > /dev/null; then
    echo "✅ Firestore Emulator is running"
else
    echo "❌ Firestore Emulator is not accessible"
    exit 1
fi

# Check vendor data
echo ""
echo "2. Checking Vendor Data..."
VENDOR_COUNT=$(curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/vendors" | jq '.documents | length' 2>/dev/null || echo "0")
echo "📊 Total vendors in database: $VENDOR_COUNT"

if [ "$VENDOR_COUNT" -gt 0 ]; then
    echo "👥 Sample vendors:"
    curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/vendors" | jq -r '.documents[] | "   - " + .fields.displayName.stringValue + " (" + (.name | split("/") | last) + ")"' 2>/dev/null || echo "   Error parsing vendor data"
fi

# Check message data
echo ""
echo "3. Checking Message Data..."
MESSAGE_COUNT=$(curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/messages" | jq '.documents | length' 2>/dev/null || echo "0")
echo "💬 Total messages in database: $MESSAGE_COUNT"

if [ "$MESSAGE_COUNT" -gt 0 ]; then
    echo "📝 Sample messages:"
    curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/messages" | jq -r '.documents[] | "   - " + .fields.text.stringValue + " (from: " + .fields.fromUid.stringValue + ")"' 2>/dev/null || echo "   Error parsing message data"
fi

# Check authentication
echo ""
echo "4. Authentication Check..."
echo "🔐 Note: Authentication state can only be checked from within the app"
echo "   Check the Flutter console logs for authentication status"

# Firestore rules check
echo ""
echo "5. Firestore Rules Status..."
if [ -f "firestore.rules" ]; then
    echo "✅ Firestore rules file exists"
    echo "📋 Key rules for messaging:"
    echo "   - Messages collection: Only sender/recipient can read/write"
    echo "   - Vendors collection: Publicly readable"
else
    echo "❌ Firestore rules file not found"
fi

echo ""
echo "🧪 Testing Recommendations:"
echo "1. Check Flutter console for authentication logs"
echo "2. Verify user is signed in before accessing chat"
echo "3. Check if Firebase Auth emulator is also running (port 9099)"
echo "4. Try refreshing the vendor discovery screen"
echo "5. Check network connectivity in emulator"

echo ""
echo "🔗 Useful URLs:"
echo "   - Emulator UI: http://127.0.0.1:4000"
echo "   - Firestore: http://127.0.0.1:4000/firestore"
echo "   - Auth: http://127.0.0.1:4000/auth"

echo ""
echo "Debug complete! 🎉" 