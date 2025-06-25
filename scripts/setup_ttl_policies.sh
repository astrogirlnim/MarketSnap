#!/bin/bash

# MarketSnap TTL Policy Setup Script
# This script configures Time-To-Live (TTL) policies for Firestore collections

set -e

echo "🔧 MarketSnap TTL Policy Setup"
echo "================================"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI is required but not installed."
    echo "Please install gcloud CLI: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if project ID is provided
if [ -z "$FIREBASE_PROJECT_ID" ]; then
    echo "❌ FIREBASE_PROJECT_ID environment variable is required"
    echo "Usage: FIREBASE_PROJECT_ID=your-project-id ./scripts/setup_ttl_policies.sh"
    exit 1
fi

echo "🔄 Setting up TTL policies for project: $FIREBASE_PROJECT_ID"

# Configure TTL policy for messages collection
echo "📝 Configuring TTL policy for 'messages' collection..."
gcloud firestore fields ttls update expiresAt \
  --collection-group=messages \
  --enable-ttl \
  --project="$FIREBASE_PROJECT_ID" \
  --quiet

echo "✅ TTL policy configured successfully!"
echo ""
echo "📋 TTL Policy Details:"
echo "  - Collection: messages"
echo "  - Field: expiresAt"
echo "  - Auto-deletion: Documents expire after 24 hours"
echo "  - Deletion window: Within 24 hours of expiration"
echo ""
echo "🎉 Setup complete! Messages will now automatically expire."

# Optional: List all TTL policies to verify
echo "🔍 Current TTL policies:"
gcloud firestore fields ttls list --project="$FIREBASE_PROJECT_ID" 2>/dev/null || echo "No TTL policies found or insufficient permissions" 