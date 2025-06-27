# Offline Authentication Behavior - MarketSnap

## Overview
MarketSnap implements offline-first authentication to ensure users can access the app and queue media posts even when network connectivity is poor or unavailable. This document outlines the expected behavior in various connectivity scenarios.

**✅ RESOLVED**: Fixed async initialization race condition in AuthService that was preventing cached authentication from loading before UI initialization.

## Implementation Status
- **Core Offline Media Queue**: ✅ COMPLETE
- **Offline Authentication Persistence**: ✅ COMPLETE (Synchronous initialization fix applied)
- **Real-time Connectivity Monitoring**: ✅ COMPLETE

## Expected Authentication Behavior

### Scenario 1: User Authenticates While Online
**Flow:**
1. User opens app with internet connection
2. User taps "Log In" or "Sign Up as Vendor"
3. User completes phone number or email verification
4. Firebase Auth creates authenticated session
5. AuthService caches user data locally in Hive:
   - User ID (uid)
   - Email address
   - Phone number (if used)
   - Display name
   - Profile photo URL
   - Cache timestamp
6. User gains full access to app features

**Expected Result:**
- ✅ User is authenticated and can use all features
- ✅ User data is cached for offline access
- ✅ Profile data syncs from Firestore to local storage

### Scenario 2: Authenticated User Goes Offline
**Flow:**
1. User is already authenticated and using the app
2. Network connection is lost (airplane mode, poor signal, etc.)
3. AuthService detects connectivity change
4. App switches to offline mode using cached authentication

**Expected Result:**
- ✅ User remains authenticated using cached data
- ✅ Profile information loads from local Hive storage
- ✅ Media capture and review functions work normally
- ✅ Photos/videos are queued locally for upload when online
- ✅ Full app navigation remains functional
- ✅ User sees "Will post when online" messaging for queued content

### Scenario 3: User Starts App Offline (Previously Authenticated)
**Flow:**
1. User opens app without internet connection
2. AuthService checks for cached authentication in Hive
3. If valid cached data exists (< 30 days old):
   - Load cached user data
   - Set authentication state as authenticated
   - Load local profile data
4. If no valid cache exists:
   - Show authentication screens
   - Display offline indicator

**Expected Result:**
- ✅ Previously authenticated users can access the app fully offline
- ✅ Local profile data is available immediately
- ✅ Media posting queues locally until connectivity returns
- ✅ All offline features work as if user were online

### Scenario 4: User Tries to Authenticate While Offline
**Flow:**
1. User opens app without internet connection
2. User has no valid cached authentication
3. User attempts to log in or sign up
4. AuthService detects offline status
5. Authentication is blocked with clear messaging

**Expected Result:**
- ❌ Phone/email verification cannot proceed (requires network)
- ✅ Clear error message: "Cannot verify while offline. Please connect to the internet and try again."
- ✅ Offline indicator shows current connectivity status
- ✅ User is guided to establish internet connection for initial authentication

### Scenario 5: User Signs Out While Offline
**Flow:**
1. User is authenticated (online or offline)
2. User taps sign out from settings
3. AuthService clears both Firebase session and local cache
4. User is redirected to authentication screens

**Expected Result:**
- ✅ User is signed out completely
- ✅ Local authentication cache is cleared
- ✅ Local profile data is cleared
- ✅ Pending media queue is preserved (will upload when user re-authenticates online)

## Security & Privacy Considerations

### Data Storage
- **Cached Data**: Only basic user metadata (uid, email, phone, display name, photo URL)
- **No Sensitive Tokens**: Firebase ID tokens are NOT cached locally
- **Encryption**: All local data stored in encrypted Hive boxes
- **Expiry**: Cached authentication expires after 30 days

### Authentication Validation
- **Online Validation**: When connectivity returns, Firebase Auth state is synchronized
- **Cache Integrity**: Cached data includes timestamp for expiry validation
- **Automatic Cleanup**: Expired cache is automatically cleared

### Privacy Protection
- **Minimal Data**: Only essential user identification data is cached
- **Secure Storage**: Uses flutter_secure_storage for encryption keys
- **User Control**: Users can sign out to clear all local data

## Technical Implementation Details

### Core Components
1. **AuthService**: Manages authentication state with offline support
2. **HiveService**: Provides encrypted local storage for user cache
3. **Connectivity Monitoring**: Real-time network status detection
4. **CachedUser Model**: Simple representation of offline user data

### Data Flow
```
Online Authentication → Firebase Auth → Cache in Hive → Offline Access
                                    ↓
                          Real-time Sync ← Connectivity Monitor
```

### Cache Management
- **Storage Location**: Encrypted Hive box (`authCache`)
- **Cache Key**: `current_user`
- **Expiry Check**: Performed on app start and authentication checks
- **Cleanup**: Automatic on expiry or manual on sign out

## Error Handling

### Network Connectivity Issues
- **Graceful Degradation**: App functions with cached data when offline
- **User Feedback**: Clear messaging about offline status and limitations
- **Retry Logic**: Automatic sync when connectivity returns

### Cache Corruption or Expiry
- **Fallback**: Redirect to authentication if cache is invalid
- **Recovery**: User can re-authenticate to restore access
- **Data Preservation**: Pending media queue survives authentication issues

## User Experience Guidelines

### Visual Indicators
- **Offline Status**: Amber warning banner when offline
- **Posting Status**: "Will post when online" for queued media
- **Connectivity**: Real-time indicators for network status changes

### Messaging Strategy
- **Positive Framing**: Focus on what works offline rather than limitations
- **Clear Actions**: Guide users on how to resolve connectivity issues
- **Progress Feedback**: Show sync status when connectivity returns

## Testing Scenarios

### Manual Testing Checklist
1. ✅ Authenticate online, go offline, verify continued access
2. ✅ Start app offline with valid cache, verify authentication
3. ✅ Start app offline without cache, verify authentication blocking
4. ✅ Post media offline, verify queueing and eventual upload
5. ✅ Sign out offline, verify complete data clearing
6. ✅ Cache expiry handling (simulate 30+ day old cache)

### Automated Testing
- Unit tests for AuthService offline state management
- Integration tests for cache persistence across app restarts
- Widget tests for offline UI indicators and messaging

## Current Implementation Status

### ✅ Working Components
- Real-time connectivity monitoring
- Offline media queue with background sync
- Enhanced UX with smart posting flow
- Offline status indicators and messaging
- **Authentication Cache Persistence**: Synchronous initialization ensures cached auth loads immediately
- **_CachedFirebaseUser Implementation**: Complete Firebase User interface implementation
- **End-to-end Offline Authentication**: Fully functional

### 🔧 Technical Resolution
- ✅ **Race Condition Fixed**: AuthService now loads cached authentication synchronously in constructor
- ✅ **Firebase Auth Compatibility**: _CachedFirebaseUser implements all required User interface methods
- ✅ **App Compilation**: No compilation errors, all tests passing

## Future Enhancements

### Phase 2 Considerations
- Biometric authentication for quick offline access
- Selective sync preferences for limited bandwidth
- Enhanced cache management with size limits
- Background authentication refresh when online

---

**Last Updated**: January 28, 2025  
**Status**: Implementation Complete and Fully Functional  
**Next Steps**: Phase 4.2 - Push Notification Flow