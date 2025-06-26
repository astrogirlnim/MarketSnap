# Video Filter Bug Debugging Log
*Created: January 27, 2025*

## Issue Summary
Video posts in the feed are not displaying the selected LUT filters (warm, cool, contrast) that were chosen during the media review process. The filters work correctly for photos but not for videos.

## Root Cause Analysis

### The Problem
From the Flutter logs, we can see the exact data flow issue:

1. **MediaReviewScreen**: ✅ Filter correctly selected and stored
   ```
   I/flutter: [MediaReviewScreen] Creating PendingMediaItem with filterType: "cool" (from Cool)
   ```

2. **HiveService**: ❌ **CRITICAL BUG** - Filter gets lost during Hive storage
   ```
   I/flutter: [HiveService] - FilterType: "cool"
   I/flutter: [HiveService] Verification - stored item filterType: "null"
   ```

3. **BackgroundSyncService**: ❌ Receives null filter from Hive
   ```
   I/flutter: [Main Isolate] - FilterType: "null"
   I/flutter: [Main Isolate] Creating Firestore document with filterType: "null"
   ```

4. **FeedPostWidget**: ❌ Displays no filter overlay
   ```
   I/flutter: [FeedPostWidget] Processing video for snap [...] with filterType: "null"
   I/flutter: [FeedPostWidget] Applied overlay color: Color(alpha: 0.0000, red: 0.0000, green: 0.0000, blue: 0.0000, colorSpace: ColorSpace.sRGB) for filter: null
   ```

### The Root Cause
**The `filterType` field is being lost during Hive serialization/deserialization.** This is a **data migration issue** where the Hive adapter is not properly handling the newly added `filterType` field.

## Code Changes Made

### 1. Data Models Updated
- ✅ Added `filterType` field to `PendingMediaItem` class
- ✅ Added `filterType` field to `Snap` model
- ✅ Regenerated Hive adapter with `build_runner`

### 2. Background Sync Service
- ✅ Updated to include `filterType` in Firestore document creation
- ✅ Added comprehensive debug logging

### 3. Feed Display
- ✅ Updated `FeedPostWidget` to apply color overlays for video filters
- ✅ Separated video and photo aspect ratio handling
- ✅ Added debug logging for filter application

### 4. Debug Logging Added
- ✅ MediaReviewScreen: Logs filter selection
- ✅ HiveService: Logs storage and retrieval with verification
- ✅ BackgroundSyncService: Logs complete data flow
- ✅ FeedPostWidget: Logs filter application

## Current State of Codebase

### Working Components
1. **Filter Selection UI**: Users can select filters for videos in MediaReviewScreen
2. **Visual Preview**: Color overlays display correctly during review
3. **Filter Enum**: `LutFilterType` enum correctly maps names (`"cool"`, `"warm"`, `"contrast"`, `"none"`)
4. **Firestore Schema**: Documents include `filterType` field
5. **Feed Display Logic**: `FeedPostWidget` has correct overlay application code

### Broken Component
**Hive Storage/Retrieval**: The `filterType` field is being lost between storage and retrieval in the Hive queue.

## Technical Details

### Hive Adapter Analysis
- Field is defined: `@HiveField(7) final String? filterType;`
- Generated adapter includes field: Line 23 and 50 in `pending_media.g.dart`
- Constructor properly accepts parameter: `this.filterType`

### Data Migration Issue
The issue appears to be related to **existing Hive data** that was created before the `filterType` field was added. When these old records are retrieved, the missing field defaults to `null`.

### Verification Steps Taken
1. ✅ Cleared Hive queue with `./scripts/clear_hive_queue.sh`
2. ✅ Ran `flutter clean` to clear all caches
3. ✅ Regenerated Hive adapters with `build_runner`
4. ❌ Issue persists - new items still lose `filterType` during storage

## Next Steps for Resolution

### Immediate Actions Needed
1. **Investigate Hive Type ID Conflicts**: Check if there are TypeId conflicts in the Hive registration
2. **Verify Hive Box Initialization**: Ensure the `filterType` field is properly handled during box operations
3. **Test Hive Adapter Directly**: Create a minimal test to verify field serialization/deserialization
4. **Check Flutter/Hive Version Compatibility**: Ensure current versions are compatible

### Potential Solutions
1. **Force Hive Schema Migration**: Explicitly handle the schema change
2. **Re-register Hive Adapters**: Clear and re-register all Hive type adapters
3. **Alternative Storage**: Consider using a different field name or storage approach
4. **Hive Box Recreation**: Force recreation of the Hive box with new schema

## Testing Environment
- **Platform**: Android Emulator (API 36)
- **Flutter Version**: Latest stable
- **Firebase**: Emulator mode
- **Hive**: Local storage with generated adapters

## Log Evidence
The logs clearly show the data loss occurs between:
```
[HiveService] - FilterType: "cool"          ← Input to Hive
[HiveService] Verification - stored item filterType: "null"  ← Retrieved from Hive
```

This indicates the issue is specifically with the Hive storage mechanism, not with the UI logic, Firestore integration, or display components.

## Status
🔴 **BLOCKED** - Core data persistence issue prevents filter functionality from working end-to-end.

*Next debugging session should focus on Hive adapter and storage mechanism investigation.* 