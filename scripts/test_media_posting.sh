#!/bin/bash

echo "🧪 Testing Media Posting Functionality"
echo "======================================="

# Check initial snap count
echo "📊 Checking initial snap count..."
INITIAL_COUNT=$(curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('documents', [])))" 2>/dev/null || echo "0")
echo "Initial snaps: $INITIAL_COUNT"

# Wait a moment for any background uploads to complete
echo "⏳ Waiting 5 seconds for background uploads..."
sleep 5

# Check final snap count
echo "📊 Checking final snap count..."
FINAL_COUNT=$(curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('documents', [])))" 2>/dev/null || echo "0")
echo "Final snaps: $FINAL_COUNT"

# Calculate difference
DIFF=$((FINAL_COUNT - INITIAL_COUNT))

if [ $DIFF -gt 0 ]; then
    echo "✅ SUCCESS: $DIFF new snap(s) detected!"
    echo "📱 Media posting is working correctly"
elif [ $DIFF -eq 0 ]; then
    echo "⚠️  WARNING: No new snaps detected"
    echo "📱 This could indicate a posting issue or no new media was posted"
else
    echo "❌ ERROR: Snap count decreased by $((DIFF * -1))"
    echo "📱 This suggests data corruption or cleanup occurred"
fi

echo ""
echo "🔍 Recent snaps:"
curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/snaps" | python3 -c "
import sys, json
from datetime import datetime
data = json.load(sys.stdin)
docs = data.get('documents', [])
for doc in sorted(docs, key=lambda x: x.get('fields', {}).get('createdAt', {}).get('timestampValue', ''), reverse=True)[:5]:
    fields = doc.get('fields', {})
    vendor_name = fields.get('vendorName', {}).get('stringValue', 'Unknown')
    media_type = fields.get('mediaType', {}).get('stringValue', 'unknown')
    caption = fields.get('caption', {}).get('stringValue', 'No caption')[:30]
    created_at = fields.get('createdAt', {}).get('timestampValue', 'Unknown time')
    print(f'- {vendor_name}: {media_type} - \"{caption}\" ({created_at})')
" 2>/dev/null || echo "Error fetching snap details"

echo ""
echo "🧪 Test complete!" 