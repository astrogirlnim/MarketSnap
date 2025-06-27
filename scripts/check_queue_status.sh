#!/bin/bash

# Simple script to check pending media queue status
echo "🔍 Checking Offline Media Queue Status"
echo "=================================="

# Check if there are any pending media files in temp directory
TEMP_DIR="/tmp"
PENDING_DIR="$TEMP_DIR/pending_uploads"

echo "📂 Checking pending uploads directory: $PENDING_DIR"

if [ -d "$PENDING_DIR" ]; then
    echo "✅ Pending uploads directory exists"
    
    # Count files in pending directory
    FILE_COUNT=$(find "$PENDING_DIR" -type f | wc -l)
    echo "📄 Files in pending directory: $FILE_COUNT"
    
    if [ $FILE_COUNT -gt 0 ]; then
        echo "📋 Files found:"
        ls -la "$PENDING_DIR"
    else
        echo "📭 No files in pending directory"
    fi
else
    echo "❌ Pending uploads directory does not exist"
fi

# Check for Hive database files (they're usually in app documents)
echo ""
echo "🗄️ Looking for Hive database files..."

# Common locations for Flutter app data
POSSIBLE_DIRS=(
    "$HOME/Library/Developer/CoreSimulator/Devices/*/data/Containers/Data/Application/*/Documents"
    "/tmp/flutter_tools.*"
    "/tmp/hive_*"
)

for pattern in "${POSSIBLE_DIRS[@]}"; do
    if ls $pattern 2>/dev/null | head -1; then
        echo "📁 Found app data directory: $pattern"
        
        # Look for Hive files
        find $pattern -name "*.hive" -o -name "pendingMediaQueue*" 2>/dev/null | while read file; do
            echo "🗃️ Found Hive file: $file"
            echo "   Size: $(stat -f%z "$file" 2>/dev/null || echo "unknown") bytes"
        done
    fi
done

echo ""
echo "💡 To debug queue issues:"
echo "1. Check Flutter logs when posting offline"
echo "2. Check logs when connectivity restored"
echo "3. Look for 'Triggering background sync' messages"
echo "4. Verify Firebase connection and authentication" 