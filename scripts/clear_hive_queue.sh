#!/bin/bash

echo "🧹 Clearing Hive Queue and Testing Upload"
echo "========================================"

echo "📱 This script will help clear the local Hive queue"
echo "   The queue is stored locally in the app, so we need to:"
echo "   1. Stop the Flutter app"
echo "   2. Clear app data (or just restart)"
echo "   3. Restart the app"
echo ""

echo "⚠️  Manual Steps Required:"
echo "   1. Stop the Flutter app (Ctrl+C in the terminal where it's running)"
echo "   2. Run: flutter clean && flutter run --debug"
echo "   3. Login again and try posting a new photo"
echo ""

echo "🔧 Current emulator status:"
curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    count = len(data.get('documents', []))
    print(f'   Current snaps in Firestore: {count}')
except:
    print('   Error checking Firestore')
"

echo ""
echo "🚀 After restarting the app:"
echo "   1. Take a NEW photo (don't use old ones)"
echo "   2. Apply a filter if desired"
echo "   3. Add a caption"
echo "   4. Tap 'Post'"
echo "   5. Check the feed tab" 