# MarketSnap Phase 3.3: Story Reel & Feed Implementation Report
*Generated July 2, 2025*

---

## 1. Overview

This document outlines the implementation of the **Story Reel & Feed** feature, corresponding to **Phase 3, Step 3** of the MVP checklist. This major update introduces a core social feed experience to the MarketSnap application, shifting the post-login user experience from a direct-to-camera flow to a content-centric home screen.

The implementation includes a new main application shell with bottom navigation, a dynamic feed screen displaying stories and snaps, the required data models and services, and several new UI components.

---

## 2. Core Architectural Changes

### 2.1. Main Application Shell (`main_shell_screen.dart`)

To support a multi-screen experience, a new **`MainShellScreen`** was introduced.

- **Location**: `lib/features/shell/presentation/screens/main_shell_screen.dart`
- **Functionality**:
    - Acts as the new home screen for authenticated users.
    - Implements a `BottomNavigationBar` with three tabs: **Feed**, **Capture**, and **Profile**.
    - Manages the state and navigation between the main feature screens.
- **Integration**: The `AuthWrapper` in `lib/main.dart` was updated to navigate to `MainShellScreen` upon successful login and profile completion, replacing the previous navigation to `CameraPreviewScreen`.

### 2.2. Feed Feature Module Structure

The `lib/features/feed/` directory was populated with a clean architecture structure:

- **`application/feed_service.dart`**: Contains the business logic for fetching feed data.
- **`domain/models/`**: Contains the data models `snap_model.dart` and `story_item_model.dart`.
- **`presentation/screens/feed_screen.dart`**: The main UI for the feed.
- **`presentation/widgets/`**: Reusable UI components for the feed, `story_carousel_widget.dart` and `feed_post_widget.dart`.

---

## 3. Feature Implementation Details

### 3.1. Data Models

- **`Snap` (`snap_model.dart`)**: Represents a single media post.
  - **Fields**: `id`, `vendorId`, `vendorName`, `vendorAvatarUrl`, `mediaUrl`, `mediaType`, `caption`, `createdAt`, `expiresAt`.
  - **Factory**: Includes a `fromFirestore` factory for easy conversion from Firestore documents.

- **`StoryItem` (`story_item_model.dart`)**: Represents a vendor's collection of recent stories.
  - **Fields**: `vendorId`, `vendorName`, `vendorAvatarUrl`, `snaps`, `hasUnseenSnaps`.

### 3.2. Feed Service (`feed_service.dart`)

- **Responsibilities**:
  - `getStories()`: Fetches recent snaps and groups them by vendor to create `StoryItem` objects for the story carousel.
  - `getFeedSnaps()`: Fetches a paginated list of the most recent snaps for the main feed.
- **Current Logic**: For the MVP, the service fetches snaps from all vendors. A future iteration will filter this based on the current user's followed vendors.
- **Emulator Support**: The service uses the `FirebaseFirestore.instance`, which is configured in `main.dart` to automatically connect to the Firestore emulator in debug mode.

### 3.3. Feed Screen & Widgets

- **`FeedScreen` (`feed_screen.dart`)**:
  - A `StatefulWidget` that uses the `FeedService` to fetch stories and snaps.
  - Implements `RefreshIndicator` for a pull-to-refresh user experience.
  - Uses `FutureBuilder` to handle loading states and display data asynchronously.
  - Composes the UI using `StoryCarouselWidget` and a `SliverList` of `FeedPostWidget`s.

- **`StoryCarouselWidget` (`story_carousel_widget.dart`)**:
  - A horizontal `ListView` that displays circular avatars for each vendor's story.
  - A colored border (using `AppColors.harvestOrange`) indicates unseen stories.
  - Displays the vendor's name below the avatar.

- **`FeedPostWidget` (`feed_post_widget.dart`)**:
  - A `Card`-based widget that displays a single snap.
  - **Header**: Shows the vendor's avatar and name.
  - **Media**: Uses the `cached_network_image` package to display the snap's image from a URL. This provides:
      - **Thumbnail/Placeholder**: A `CircularProgressIndicator` is shown while the image is loading.
      - **Error Handling**: An error icon is displayed if the image fails to load.
  - **Footer**: Displays the snap's caption and creation timestamp.

---

## 4. Dependencies

- **`cached_network_image: ^3.3.0`**: Added to `pubspec.yaml` to handle efficient loading, caching, and placeholder display for network images in the feed.

---

## 5. Firebase Configuration Considerations

- **Firestore Indexes**: The `FeedService` currently queries the `snaps` collection and orders by `createdAt`. To ensure optimal performance at scale, a composite index on the `snaps` collection might be required. The current query is:
  ```
  _firestore.collection('snaps').orderBy('createdAt', descending: true)
  ```
  A single-field index is automatically created by Firestore, so no immediate changes to `firestore.indexes.json` are needed for this simple query. However, as filtering by followed vendors is implemented, a composite index will become necessary (e.g., on `vendorId` and `createdAt`).

- **Security Rules**: The Firestore security rules (`firestore.rules`) should be reviewed to ensure that users can only read snaps from vendors they follow. The current implementation fetches all snaps, but this should be locked down in a future iteration. A placeholder rule might look like:
  ```
  match /snaps/{snapId} {
    // Allow read if the user is authenticated.
    // Future rule: allow read if request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.following
    allow read: if request.auth != null;
    allow write: if request.auth.uid == resource.data.vendorId;
  }
  ```

---

## 6. Conclusion

The implementation of the Story Reel & Feed feature marks a significant milestone in the development of MarketSnap. The application now has a central, content-driven home screen, providing a foundation for user engagement. The architecture is scalable, with a clear separation of concerns that will facilitate future development, such as implementing the "following" model and adding more complex feed-filtering logic. 