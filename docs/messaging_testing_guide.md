# Messaging Testing Guide

This guide explains how to test the messaging functionality locally using Firebase emulators and test data.

## Prerequisites

1. **Firebase Emulators Running**: Make sure your Firebase emulators are running:
   ```bash
   ./scripts/dev_emulator.sh
   ```

2. **App Running**: Have the MarketSnap app running on both iOS and Android emulators.

## Setting Up Test Data

### 1. Create Test Vendor Accounts

Run the messaging test data script to create multiple vendor profiles:

```bash
node scripts/setup_messaging_test_data.js
```

This script creates the following test vendors:
- **Alice's Farm Stand** (Portland, OR)
- **Bob's Organic Produce** (Seattle, WA) 
- **Carol's Country Market** (San Francisco, CA)
- **Dave's Fresh Vegetables** (Los Angeles, CA)

It also creates some sample messages between vendors to populate the conversation list.

### 2. Authentication

Since the test vendors are created directly in Firestore, you'll need to:

1. **Sign up/Sign in** with your own account in the app
2. **Use the vendor discovery feature** to find and message the test vendors
3. **Or manually create additional accounts** using different email addresses

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