#!/bin/bash

echo "🧪 Adding test data to MarketSnap Firestore emulator (Simple Method)..."
echo "💡 This adds data directly through the admin API"

# Add a few sample snaps with simple timestamps
echo "📱 Adding sample snap 1..."
curl -X POST "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps?documentId=snap1" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "vendorId": {"stringValue": "vendor_1"},
      "vendorName": {"stringValue": "Green Valley Farms"},
      "vendorAvatarUrl": {"stringValue": "https://placehold.co/100/34C759/FFFFFF?text=GV"},
      "mediaUrl": {"stringValue": "https://placehold.co/400x600/34C759/FFFFFF?text=Fresh+Tomatoes"},
      "mediaType": {"stringValue": "photo"},
      "caption": {"stringValue": "Fresh organic tomatoes just picked! 🍅"},
      "createdAt": {"timestampValue": "2025-06-25T19:00:00.000Z"},
      "expiresAt": {"timestampValue": "2025-06-26T19:00:00.000Z"}
    }
  }' \
  -H "Authorization: Bearer owner"

echo "📱 Adding sample snap 2..."
curl -X POST "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps?documentId=snap2" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "vendorId": {"stringValue": "vendor_2"},
      "vendorName": {"stringValue": "Sunrise Bakery"},
      "vendorAvatarUrl": {"stringValue": "https://placehold.co/100/FF9500/FFFFFF?text=SB"},
      "mediaUrl": {"stringValue": "https://placehold.co/400x600/D2691E/FFFFFF?text=Fresh+Bread"},
      "mediaType": {"stringValue": "photo"},
      "caption": {"stringValue": "Warm sourdough just out of the oven! 🍞"},
      "createdAt": {"timestampValue": "2025-06-25T20:00:00.000Z"},
      "expiresAt": {"timestampValue": "2025-06-26T20:00:00.000Z"}
    }
  }' \
  -H "Authorization: Bearer owner"

echo "📱 Adding sample snap 3..."
curl -X POST "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps?documentId=snap3" \
  -H "Content-Type: application/json" \
  -d '{
    "fields": {
      "vendorId": {"stringValue": "vendor_3"},
      "vendorName": {"stringValue": "Mountain Honey Co"},
      "vendorAvatarUrl": {"stringValue": "https://placehold.co/100/FFCC00/000000?text=MH"},
      "mediaUrl": {"stringValue": "https://placehold.co/400x600/FFD700/000000?text=Pure+Honey"},
      "mediaType": {"stringValue": "photo"},
      "caption": {"stringValue": "Pure wildflower honey from our mountain hives 🍯"},
      "createdAt": {"timestampValue": "2025-06-25T18:00:00.000Z"},
      "expiresAt": {"timestampValue": "2025-06-26T18:00:00.000Z"}
    }
  }' \
  -H "Authorization: Bearer owner"

echo ""
echo "✅ Test data added! Check your app:"
echo "   1. Go to Feed tab"
echo "   2. Pull down to refresh"
echo "   3. You should see 3 stories and 3 feed posts"
echo ""
echo "🔍 Verify at: http://127.0.0.1:4000/firestore" 