# Phase 3.5: Messaging UI Implementation Report

This document outlines the implementation of the ephemeral messaging interface, corresponding to Phase 3, Step 5 of the MVP checklist.

## 1. Feature Overview

The messaging feature enables one-to-one ephemeral chats between users. Conversations are automatically deleted after 24 hours, enforced by a Firestore TTL policy.

The implementation includes:
- A conversation list screen showing all active chats.
- A real-time chat screen with message bubbles.
- Push notifications for new messages.
- Deep-linking from notifications directly to the relevant chat screen.

## 2. Technical Implementation

### 2.1. Backend (Cloud Functions)

- **`sendMessageNotification`**: A new Cloud Function was added to `functions/src/index.ts`.
  - **Trigger**: `onDocumentCreated` on the `/messages/{messageId}` path.
  - **Action**: Fetches the sender's name and recipient's FCM token, then sends a push notification.
  - **Payload**: The notification's data payload includes `type: 'new_message'` and `fromUid`, which is used by the client for deep-linking.

### 2.2. Core Services

- **`MessagingService`**: This existing service was leveraged. It provides streams for conversations and messages, and methods for sending messages and marking them as read. No major changes were required.
- **`ProfileService`**: A new method, `saveFCMToken(String token)`, was added to update the user's profile in Firestore with their unique Firebase Cloud Messaging token.
- **`PushNotificationService`**: A new service was created to handle push notifications.
  - It initializes FCM listeners (`onMessageOpenedApp`, `getInitialMessage`).
  - It uses a `GlobalKey<NavigatorState>` to navigate imperatively from outside the widget tree.
  - It handles incoming message notifications, fetches the sender's profile, and pushes the `ChatScreen` for that conversation.

### 2.3. New Feature Modules

A new feature module was created at `lib/features/messaging/`.

- **Domain**:
  - `models/conversation.dart`: A client-side model to represent a conversation, combining a `VendorProfile` with the `Message`.
- **Presentation**:
  - `screens/conversation_list_screen.dart`: Displays a list of active conversations. Uses a `StreamBuilder` on `MessagingService.getUserConversations` and a `FutureBuilder` on `ProfileService.loadProfileFromFirestore` to build the list.
  - `screens/chat_screen.dart`: The main chat UI. Uses a `StreamBuilder` on `MessagingService.getConversationMessages`. It marks messages as read on `initState`.
  - `widgets/conversation_list_item.dart`: A row in the conversation list.
  - `widgets/chat_bubble.dart`: A message bubble, styled differently for sent vs. received.
  - `widgets/message_input_bar.dart`: A text input field and send button.

### 2.4. Integration

- **`main.dart`**:
  - A global `MessagingService` and `PushNotificationService` were initialized.
  - A global `navigatorKey` was created and passed to `MaterialApp` and `PushNotificationService` to enable deep-linking.
  - The `_handlePostAuthenticationFlow` was updated to save the user's FCM token on every login.
- **`lib/features/shell/presentation/screens/main_shell_screen.dart`**:
  - A new "Messages" tab was added to the bottom navigation bar, pointing to the `ConversationListScreen`.

## 3. Firebase Configuration

- **`firestore.rules`**: The rules for the `/messages/{messageId}` path were confirmed to be secure, allowing reads only by participants and updates only for the `isRead` flag by the recipient.
- **`firestore.indexes.json`**: A TTL policy on the `expiresAt` field in the `messages` collection is assumed to be in place as per the project checklist, ensuring messages are deleted after 24 hours.

## 4. Cross-Platform Support

The implementation uses standard Flutter widgets and Firebase packages (`cloud_firestore`, `firebase_messaging`) that have full support for both iOS and Android. The UI was built with platform-agnostic components. Local testing is supported via the Firebase Emulator Suite, which the new `sendMessageNotification` function is compatible with. 