#!/bin/bash

# MarketSnap Test Data Setup Script
# Adds minimal data to Firestore emulator for testing Story Reel & Feed

echo "🧪 Adding test data to MarketSnap Firestore emulator..."

# Check if Firebase emulators are running
if ! curl -s http://127.0.0.1:8080 > /dev/null; then
    echo "❌ Error: Firestore emulator not running on port 8080"
    echo "💡 Start emulators first: firebase emulators:start"
    exit 1
fi

echo "✅ Firestore emulator detected on port 8080"

# Function to add a snap to Firestore
add_snap() {
    local vendor_id="$1"
    local vendor_name="$2"
    local vendor_avatar="$3"
    local media_url="$4"
    local media_type="$5"
    local caption="$6"
    local hours_ago="$7"
    
    # Calculate timestamps
    local created_at=$(date -u -v-${hours_ago}H +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "${hours_ago} hours ago" +"%Y-%m-%dT%H:%M:%S.000Z")
    local expires_at=$(date -u -v-$((hours_ago-24))H +"%Y-%m-%dT%H:%M:%S.000Z" 2>/dev/null || date -u -d "$((hours_ago-24)) hours ago" +"%Y-%m-%dT%H:%M:%S.000Z")
    
    echo "📱 Adding snap: $vendor_name - $caption"
    
    curl -s -X POST "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps" \
      -H "Content-Type: application/json" \
      -d "{
        \"fields\": {
          \"vendorId\": {\"stringValue\": \"$vendor_id\"},
          \"vendorName\": {\"stringValue\": \"$vendor_name\"},
          \"vendorAvatarUrl\": {\"stringValue\": \"$vendor_avatar\"},
          \"mediaUrl\": {\"stringValue\": \"$media_url\"},
          \"mediaType\": {\"stringValue\": \"$media_type\"},
          \"caption\": {\"stringValue\": \"$caption\"},
          \"createdAt\": {\"timestampValue\": \"$created_at\"},
          \"expiresAt\": {\"timestampValue\": \"$expires_at\"}
        }
      }" > /dev/null
    
    if [ $? -eq 0 ]; then
        echo "  ✅ Added successfully"
    else
        echo "  ❌ Failed to add"
    fi
}

echo ""
echo "🌱 Adding sample vendor snaps..."

# Vendor 1: Green Valley Farms (Fresh produce vendor)
add_snap "vendor_1" \
         "Green Valley Farms" \
         "https://placehold.co/100/34C759/FFFFFF?text=GV" \
         "https://placehold.co/400x600/34C759/FFFFFF?text=Fresh+Tomatoes" \
         "photo" \
         "Fresh organic tomatoes just picked! 🍅" \
         "2"

add_snap "vendor_1" \
         "Green Valley Farms" \
         "https://placehold.co/100/34C759/FFFFFF?text=GV" \
         "https://placehold.co/400x600/228B22/FFFFFF?text=Lettuce+Harvest" \
         "photo" \
         "Crispy lettuce ready for your salad! 🥬" \
         "4"

# Vendor 2: Sunrise Bakery (Baked goods vendor)
add_snap "vendor_2" \
         "Sunrise Bakery" \
         "https://placehold.co/100/FF9500/FFFFFF?text=SB" \
         "https://placehold.co/400x600/D2691E/FFFFFF?text=Fresh+Bread" \
         "photo" \
         "Warm sourdough just out of the oven! 🍞" \
         "1"

add_snap "vendor_2" \
         "Sunrise Bakery" \
         "https://placehold.co/100/FF9500/FFFFFF?text=SB" \
         "https://placehold.co/400x600/8B4513/FFFFFF?text=Croissants" \
         "photo" \
         "Buttery croissants - only 3 left! ⏰" \
         "6"

# Vendor 3: Mountain Honey Co (Honey and preserves)
add_snap "vendor_3" \
         "Mountain Honey Co" \
         "https://placehold.co/100/FFCC00/000000?text=MH" \
         "https://placehold.co/400x600/FFD700/000000?text=Pure+Honey" \
         "photo" \
         "Pure wildflower honey from our mountain hives 🍯" \
         "3"

# Vendor 4: Coastal Flowers (Flower vendor)
add_snap "vendor_4" \
         "Coastal Flowers" \
         "https://placehold.co/100/FF69B4/FFFFFF?text=CF" \
         "https://placehold.co/400x600/FF1493/FFFFFF?text=Sunflowers" \
         "photo" \
         "Bright sunflowers to brighten your day! 🌻" \
         "5"

# Vendor 5: Farm Fresh Eggs (Egg vendor with a video)
add_snap "vendor_5" \
         "Farm Fresh Eggs" \
         "https://placehold.co/100/8B4513/FFFFFF?text=FF" \
         "https://placehold.co/400x600/DEB887/000000?text=Fresh+Eggs+Video" \
         "video" \
         "Our happy chickens laying fresh eggs daily! 🐔🥚" \
         "8"

echo ""
echo "🎉 Test data setup complete!"
echo ""
echo "📋 What was added:"
echo "   • 6 sample snaps from 5 different vendors"
echo "   • Mix of photos and 1 video"
echo "   • Variety of captions and timestamps"
echo "   • Placeholder images with vendor colors"
echo ""
echo "🔍 To view the data:"
echo "   • Open Firestore UI: http://127.0.0.1:4000/firestore"
echo "   • Check 'snaps' collection"
echo ""
echo "📱 To test in your app:"
echo "   • Navigate to the Feed tab"
echo "   • Pull down to refresh"
echo "   • You should see stories and feed posts"
echo ""
echo "💡 Tip: If feed is empty, check that Firestore port is 8080 in your app" 