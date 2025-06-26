# MarketSnap Messaging Testing Guide

## Prerequisites

1. **Firebase Emulators Running**
   ```bash
   ./scripts/dev_emulator.sh
   ```
   Verify at: http://127.0.0.1:4000

2. **Authentication Required**
   - **CRITICAL**: You must be authenticated before testing messaging
   - The app requires a logged-in user to access messaging features
   - Check authentication status in the app's profile section

## Setup Test Data

1. **Populate Test Vendors and Messages**
   ```bash
   node scripts/setup_messaging_test_data.js
   ```

2. **Verify Data Creation**
   ```bash
   ./scripts/debug_messaging.sh
   ```

## Authentication Troubleshooting

### Problem: "Permission Denied" Error in Chat
**Symptoms**: 
- Android shows: `Error: [cloud_firestore/permission-denied] The caller does not have permission to execute the specified operation`
- iOS shows no vendors in discovery screen

**Root Cause**: User is not authenticated

**Solution**:
1. **Sign Out and Sign Back In**
   - Go to Settings → Sign Out
   - Return to welcome screen and sign in again
   - Complete profile setup if prompted

2. **Verify Authentication**
   - Check that the profile screen shows your information
   - Look for user UID in Flutter console logs
   - Ensure Firebase Auth emulator shows registered users:
     ```bash
     curl -s "http://127.0.0.1:9099/emulator/v1/projects/marketsnap-app/accounts" | jq '.users | length'
     ```

3. **Check Console Logs**
   Look for these authentication debug messages:
   ```
   [ChatScreen] Initialized for user: <UID>, chatting with: <vendor-UID>
   [VendorDiscoveryScreen] Loading vendors for user: <UID>
   [VendorDiscoveryScreen] Total vendors found: 5
   ```

### Problem: No Vendors Show on iOS
**Symptoms**: Vendor discovery screen shows "No vendors found"

**Solutions**:
1. **Check Authentication First** (see above)
2. **Restart iOS Simulator**
   - Close and reopen the iOS simulator
   - Rebuild the app: `flutter run`
3. **Clear App Data**
   - Uninstall and reinstall the app
   - Sign in again and complete profile

## Testing Workflow

### Step 1: Authentication Setup
1. Launch the app
2. Complete phone/email authentication
3. Fill out vendor profile completely
4. Verify profile data saves correctly

### Step 2: Vendor Discovery
1. Navigate to Messages tab (bottom navigation)
2. Tap "+" button to discover vendors
3. **Expected**: See 4 test vendors:
   - Alice's Farm Stand
   - Bob's Artisan Bakery  
   - Carol's Flower Garden
   - Dave's Mountain Honey

### Step 3: Start Conversation
1. Tap on any vendor from discovery
2. **Expected**: Chat screen opens with vendor name in header
3. **Expected**: See "No messages yet" with friendly prompt

### Step 4: Send Messages
1. Type a message in the input field
2. Tap send button
3. **Expected**: Message appears as blue bubble on right
4. **Expected**: Console shows: `[ChatScreen] Message sent successfully`

### Step 5: Verify Real-time Updates
1. Send multiple messages
2. **Expected**: All messages appear immediately
3. **Expected**: Messages persist when navigating away and back

## Debug Commands

### Check System Status
```bash
./scripts/debug_messaging.sh
```

### Check Authentication State
```bash
curl -s "http://127.0.0.1:9099/emulator/v1/projects/marketsnap-app/accounts" | jq '.users'
```

### Check Vendor Data
```bash
curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/vendors" | jq '.documents | length'
```

### Check Messages Data
```bash
curl -s "http://127.0.0.1:8080/v1/projects/marketsnap-app/databases/(default)/documents/messages" | jq '.documents | length'
```

## Expected Behavior

### ✅ Working Correctly
- User can authenticate and complete profile
- Vendor discovery shows 4 test vendors (excluding current user)
- Chat screen opens without errors
- Messages send and appear immediately
- Real-time updates work
- Navigation between conversations works

### ❌ Known Issues
- **Authentication Required**: Must be logged in to access messaging
- **Profile Required**: Must complete vendor profile setup
- **iOS Simulator**: May need restart if vendors don't appear
- **Network**: Emulator network issues may require app restart

## Console Log Examples

### Successful Authentication
```
[VendorDiscoveryScreen] Loading vendors for user: BROKZ9yuNa12mWO2yscIMROniJgV
[VendorDiscoveryScreen] Total vendors found: 5
[VendorDiscoveryScreen] Vendors after filtering: 4
```

### Successful Message Send
```
[ChatScreen] Sending message from BROKZ9yuNa12mWO2yscIMROniJgV to vendor-alice-farm: Hello!
[ChatScreen] Message sent successfully
[ChatScreen] Loaded 1 messages
```

### Authentication Error
```
[ChatScreen] StreamBuilder error: [cloud_firestore/permission-denied]
```

## Troubleshooting Checklist

- [ ] Firebase emulators running (port 4000, 8080, 9099)
- [ ] User authenticated and profile complete
- [ ] Test data populated (5 vendors, sample messages)
- [ ] App has network access to emulators
- [ ] iOS simulator restarted if needed
- [ ] Flutter console shows authentication logs
- [ ] No permission denied errors in console

## Support

If issues persist:
1. Check all console logs for error details
2. Verify emulator accessibility via web UI
3. Try authentication flow from scratch
4. Clear all app data and restart testing

## Testing the Messaging Features

### 1. Conversation List Screen

**Location**: Messages tab (bottom navigation)

**Test Cases**:
- ✅ View list of recent conversations
- ✅ See last message preview and timestamp
- ✅ Notice unread message indicators (blue dot)
- ✅ Tap on conversation to open chat

### 2. Vendor Discovery Screen

**Location**: Tap the "+" floating action button on Messages screen

**Test Cases**:
- ✅ Browse list of all vendors
- ✅ See vendor names and market cities
- ✅ Tap "Message" to start a new conversation
- ✅ Navigate to chat screen with selected vendor

### 3. Chat Screen

**Location**: Tap on any conversation or start new chat

**Test Cases**:
- ✅ Send text messages
- ✅ See messages appear in real-time
- ✅ Verify message bubbles (your messages on right, theirs on left)
- ✅ Check timestamps are displayed
- ✅ Test with emojis and longer text

### 4. Cross-Platform Testing

**Test with both iOS and Android emulators**:
- ✅ Send message from iOS → receive on Android
- ✅ Send message from Android → receive on iOS
- ✅ Verify real-time sync works across platforms

## Testing Push Notifications

### Local Emulator Testing

1. **Background the app** on one device/emulator
2. **Send a message** from the other device
3. **Check Firebase Console** (emulator UI) for notification logs

**Note**: Push notifications in emulators have limitations. For full testing:
- Use physical devices with Firebase project configured
- Check Cloud Function logs in Firebase Console

### Deep-Linking Testing

1. **Send a message** to trigger notification
2. **Tap the notification** (on physical device)
3. **Verify** the app opens directly to the chat screen

## Troubleshooting

### No Conversations Showing

1. Check that Firebase emulators are running
2. Verify test data was created: `node scripts/setup_messaging_test_data.js`
3. Check Firestore emulator UI at `http://localhost:4000`

### Messages Not Sending

1. Verify you're authenticated (check auth status in app)
2. Check console logs for error messages
3. Ensure Firestore rules allow your user to write messages

### Real-time Updates Not Working

1. Check internet connectivity (even for emulators)
2. Verify Firestore listeners are properly set up
3. Check console for WebSocket connection errors

## Manual Testing Scenarios

### Scenario 1: New User Journey
1. Sign up with new account
2. Complete vendor profile
3. Discover other vendors
4. Start first conversation
5. Send and receive messages

### Scenario 2: Existing User
1. Sign in with existing account
2. Check conversation list for previous chats
3. Continue existing conversation
4. Start new conversation with different vendor

### Scenario 3: Multi-Device
1. Sign in with same account on two devices
2. Send messages from device A
3. Verify they appear on device B
4. Test real-time synchronization

## Expected Behavior

### ✅ Working Features
- Real-time message sending/receiving
- Conversation list with last message preview
- Vendor discovery and new chat creation
- Cross-platform messaging
- Message timestamps and read indicators
- Clean UI with MarketSnap design system

### 🚧 Known Limitations
- Push notifications require physical devices for full testing
- Message history is limited (24h TTL in production)
- No message editing or deletion (by design)
- No media messages (text only for MVP)

## Data Cleanup

To reset test data:

```bash
# Clear Firestore data
firebase emulators:exec --only firestore "echo 'Clearing data'"

# Recreate test data
node scripts/setup_messaging_test_data.js
```

## Production Testing

When testing against production Firebase:

1. Update Firebase project configuration
2. Deploy Cloud Functions: `firebase deploy --only functions`
3. Test with real FCM tokens on physical devices
4. Verify TTL policies are working (24h message expiration)

---

**Need Help?**
- Check Firebase emulator logs in terminal
- View Firestore data at `http://localhost:4000`
- Check app console logs for detailed error messages 