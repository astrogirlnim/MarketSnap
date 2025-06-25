# Firebase TTL Deployment Fix

## Issue Summary

The MarketSnap deployment pipeline was failing with the following error:
```
Error: Must contain "indexes": {"collectionGroup":"messages","fieldPath":"expiresAt","ttl":true}
```

## Root Cause

The issue occurred because of a change in how Firebase handles TTL (Time To Live) policies in recent versions:

1. **Old Approach (Incorrect)**: TTL configuration was placed in `firestore.indexes.json` in the `fieldOverrides` section
2. **New Approach (Correct)**: TTL policies must be configured using the Google Cloud Console or `gcloud` CLI

## Solution Implementation

### 1. Removed TTL from firestore.indexes.json

**Before:**
```json
{
  "indexes": [
    // ... regular indexes
  ],
  "fieldOverrides": [
    {
      "collectionGroup": "messages",
      "fieldPath": "expiresAt",
      "ttl": true
    }
  ]
}
```

**After:**
```json
{
  "indexes": [
    // ... regular indexes
  ],
  "fieldOverrides": []
}
```

### 2. Added TTL Configuration to CI/CD Pipeline

Added a new step in `.github/workflows/deploy.yml`:

```yaml
- name: Configure TTL Policies
  run: |
    echo "🔄 Setting up TTL policy for messages collection..."
    gcloud firestore fields ttls update expiresAt \
      --collection-group=messages \
      --enable-ttl \
      --project=${{ secrets.FIREBASE_PROJECT_ID }} \
      --quiet
    echo "✅ TTL policy configured successfully"
```

### 3. Created Manual Setup Script

Created `scripts/setup_ttl_policies.sh` for local development:

```bash
#!/bin/bash
FIREBASE_PROJECT_ID=your-project-id ./scripts/setup_ttl_policies.sh
```

## TTL Policy Details

- **Collection**: `messages`
- **Field**: `expiresAt` (DateTime field)
- **Behavior**: Documents automatically deleted 24 hours after the `expiresAt` timestamp
- **Deletion Window**: Typically within 24 hours of expiration (not instantaneous)

## Message Model Structure

The `Message` model includes:
```dart
class Message {
  final DateTime createdAt;
  final DateTime expiresAt; // TTL field - 24h from creation
  // ... other fields
}
```

## Verification Steps

1. **Check TTL Policy Status:**
   ```bash
   gcloud firestore fields ttls list --project=your-project-id
   ```

2. **Monitor TTL Deletions:**
   - Use Cloud Monitoring metrics:
     - `firestore.googleapis.com/document/ttl_deletion_count`
     - `firestore.googleapis.com/document/ttl_expiration_to_deletion_delays`

## Key Learnings

1. **TTL Management Evolution**: Firebase has moved TTL management away from `firestore.indexes.json` to dedicated Google Cloud commands
2. **Deployment Order**: TTL policies should be configured after Firestore deployment
3. **Index Exemption**: TTL fields can optionally be exempted from indexing to prevent hotspots

## Related Documentation

- [Firebase TTL Policies Official Docs](https://firebase.google.com/docs/firestore/ttl)
- [gcloud firestore fields ttls commands](https://cloud.google.com/sdk/gcloud/reference/firestore/fields/ttls)
- [MarketSnap Message Model](../lib/core/models/message.dart)

## Troubleshooting

### Common Issues:

1. **Permission Errors**: Ensure service account has `datastore.indexes.update` permission
2. **Project Not Found**: Verify `FIREBASE_PROJECT_ID` is correctly set
3. **gcloud Not Found**: Ensure gcloud CLI is installed in CI environment

### Manual Recovery:

If deployment fails, run the TTL setup script manually:
```bash
FIREBASE_PROJECT_ID=your-project-id ./scripts/setup_ttl_policies.sh
```

## Status

✅ **RESOLVED**: Deployment pipeline now successfully configures TTL policies using the proper gcloud CLI approach. 