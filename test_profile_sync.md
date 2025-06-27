# Profile Sync Testing Guide

*Created: January 29, 2025*

---

## Overview

This guide provides comprehensive testing procedures for the Profile Propagation Fix implemented on the `user-profile-sync` branch. The fix ensures that profile changes (avatar, username) propagate immediately throughout the app without requiring restarts.

---

## Pre-Testing Setup

### 1. Build and Deploy
```bash
# Clean build to ensure latest changes
flutter clean
flutter pub get
flutter build apk --debug

# Start Firebase emulator
npm run emulator:start

# Install on device/emulator
flutter install
```

### 2. Create Test Data
- **Vendor Account 1**: "Alice's Farm Stand" in "Portland"
- **Vendor Account 2**: "Bob's Organic Market" in "Seattle" 
- **Regular User Account**: "Charlie Customer"
- Create some feed posts from both vendors
- Start conversations between accounts

---

## Core Testing Scenarios

### Test 1: Vendor Profile Avatar Update Propagation

**Setup:**
1. Sign in as Vendor Account 1 (Alice)
2. Post 2-3 snaps to the feed
3. Start a conversation with Regular User (Charlie)
4. Sign out and sign in as Charlie
5. Verify Alice's original avatar appears in feed posts and conversations

**Test Steps:**
1. Sign back in as Alice
2. Go to Profile → Edit Profile → Change Avatar
3. Upload a distinctly different avatar image
4. Save the profile changes
5. **WITHOUT RESTARTING THE APP**, navigate to:
   - Feed screen → Check if Alice's posts show new avatar
   - Messages → Check if conversations show new avatar

**Expected Results:**
- ✅ Feed posts immediately show new avatar (no refresh needed)
- ✅ Conversation list immediately shows new avatar
- ✅ Chat screen header shows new avatar
- ✅ No loading delays or flickering
- ✅ Changes persist after app restart

### Test 2: Vendor Display Name Update Propagation

**Setup:**
1. Use the same accounts from Test 1
2. Ensure Alice has posts in feed and active conversations

**Test Steps:**
1. Sign in as Alice
2. Go to Profile → Edit Profile
3. Change Display Name from "Alice's Farm Stand" to "Alice's Premium Produce"
4. Save the profile changes
5. **WITHOUT RESTARTING THE APP**, check:
   - Feed screen → Verify posts show new name
   - Story carousel → Verify story shows new name
   - Messages → Verify conversations show new name

**Expected Results:**
- ✅ All feed posts immediately show "Alice's Premium Produce"
- ✅ Story carousel shows updated name
- ✅ Conversation list shows updated name
- ✅ Chat screen shows updated name in header
- ✅ Profile screen shows updated name

### Test 3: Cross-User Profile Update Visibility

**Setup:**
1. Sign in as Alice (Vendor 1)
2. Sign in as Bob (Vendor 2) on different device/emulator
3. Both vendors should have posts in feed
4. Start a conversation between Alice and Bob

**Test Steps:**
1. **On Alice's device:** Change avatar and display name
2. **On Bob's device:** WITHOUT refreshing or restarting
   - Check feed → Should see Alice's updated profile in her posts
   - Check messages → Should see Alice's updated profile in conversations
   - Check story carousel → Should see Alice's updated profile

**Expected Results:**
- ✅ Bob's device shows Alice's updated profile across all screens
- ✅ Updates appear within 2-3 seconds
- ✅ No manual refresh required
- ✅ Profile cache properly synchronized

### Test 4: Regular User Profile Update Propagation

**Setup:**
1. Sign in as Charlie (Regular User)
2. Follow both Alice and Bob vendors
3. Start conversations with both vendors

**Test Steps:**
1. Update Charlie's avatar and display name
2. Check that updates appear in:
   - Vendor conversation screens (when vendors view chats with Charlie)
   - Any comments or interactions Charlie made
   - Follow lists and user discovery screens

**Expected Results:**
- ✅ Vendors see Charlie's updated profile in conversations
- ✅ Profile updates propagate to all interaction points
- ✅ Follow button displays updated information

### Test 5: Profile Deletion Handling

**Setup:**
1. Create a test vendor account "Test Vendor"
2. Post content and start conversations
3. Ensure profile appears in other users' feeds and messages

**Test Steps:**
1. Delete the "Test Vendor" profile completely
2. Check other users' screens:
   - Feed posts from deleted vendor
   - Conversation lists
   - Chat screens with deleted vendor

**Expected Results:**
- ✅ Profile cache properly removes deleted user data
- ✅ No crashes or errors when deleted profiles are referenced
- ✅ Graceful handling of missing profile data
- ✅ UI shows appropriate placeholder for deleted accounts

---

## Performance Testing

### Test 6: Memory and Performance Impact

**Test Steps:**
1. Open app and monitor memory usage
2. Update profiles multiple times rapidly
3. Navigate between screens frequently
4. Check for memory leaks or performance degradation

**Expected Results:**
- ✅ No significant memory increase during profile updates
- ✅ UI remains responsive during profile propagation
- ✅ No frame drops or stuttering
- ✅ Stream controllers properly disposed of

### Test 7: Network Efficiency

**Test Steps:**
1. Monitor network requests during profile updates
2. Update same profile multiple times quickly
3. Check for duplicate or unnecessary API calls

**Expected Results:**
- ✅ Profile updates don't cause excessive Firestore reads
- ✅ Caching reduces redundant network requests
- ✅ Efficient use of Firebase bandwidth

---

## Edge Case Testing

### Test 8: Offline Profile Updates

**Test Steps:**
1. Turn off internet connection
2. Update profile (should save locally)
3. Navigate through app (should show updated profile locally)
4. Turn internet back on
5. Verify profile syncs and propagates to other users

**Expected Results:**
- ✅ Offline updates work locally
- ✅ Online sync propagates changes to other users
- ✅ No data loss during offline/online transitions

### Test 9: Rapid Profile Updates

**Test Steps:**
1. Quickly update profile multiple times in succession
2. Change avatar, then name, then avatar again within 10 seconds
3. Check that final state is correct across all screens

**Expected Results:**
- ✅ Final profile state is consistent everywhere
- ✅ No race conditions or conflicting updates
- ✅ UI doesn't flicker or show intermediate states

### Test 10: App Backgrounding/Foregrounding

**Test Steps:**
1. Update profile on one device
2. Put app in background on another device
3. Bring app back to foreground
4. Check if profile updates are visible

**Expected Results:**
- ✅ Profile updates appear when app returns to foreground
- ✅ Background sync works properly
- ✅ No stale data displayed

---

## Automated Testing Commands

### Unit Tests
```bash
# Run existing tests to ensure no regressions
flutter test

# Specific profile-related tests
flutter test test/profile_offline_test.dart
```

### Integration Tests
```bash
# Build and test on real device
flutter drive --target=test_driver/app.dart
```

### Code Quality Checks
```bash
# Analyze code for issues
flutter analyze

# Check for proper memory management
flutter run --profile
# Use DevTools to monitor memory usage
```

---

## Success Criteria

### ✅ Functional Requirements
- [ ] Profile avatar updates propagate immediately to all screens
- [ ] Profile name updates propagate immediately to all screens  
- [ ] Updates work across different user accounts/devices
- [ ] Profile deletions are handled gracefully
- [ ] Offline updates sync properly when back online

### ✅ Performance Requirements
- [ ] Profile updates appear within 2-3 seconds
- [ ] No memory leaks from stream controllers
- [ ] No excessive network requests
- [ ] UI remains responsive during updates
- [ ] No crashes or errors during rapid updates

### ✅ User Experience Requirements
- [ ] No app restarts required for profile changes
- [ ] No manual refresh needed
- [ ] Consistent profile display across all screens
- [ ] Smooth transitions without flickering
- [ ] Graceful error handling for edge cases

---

## Debugging Commands

If issues are found during testing:

```bash
# Enable verbose logging
flutter run --verbose

# Check Firebase emulator logs
firebase emulators:start --debug

# Monitor real-time database activity
# Use Firebase console or emulator UI

# Check device logs
adb logcat | grep -i "ProfileUpdateNotifier\|ProfileService\|FeedService"
```

---

## Rollback Plan

If critical issues are discovered:

1. **Immediate:** Switch back to `main` branch
```bash
git checkout main
flutter clean && flutter pub get
flutter run
```

2. **Analysis:** Review logs and test results
3. **Fix:** Address issues on feature branch
4. **Re-test:** Run full testing suite again
5. **Deploy:** Merge only after all tests pass

---

## Documentation Updates

After successful testing:

1. Update `memory_bank/memory_bank_progress.md` with completion status
2. Update `memory_bank/memory_bank_active_context.md` with next priorities
3. Create deployment notes for production release
4. Update user-facing documentation if needed 