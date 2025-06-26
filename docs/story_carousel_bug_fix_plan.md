# Story Carousel and Viewer Implementation Plan

## 1. Problem Overview

Currently, the app's story functionality is incomplete, leading to a disconnected user experience. The key issues are:

1.  **Videos Appear in Main Feed:** All posted media, including videos intended as stories, are displayed in the main vertical feed instead of the horizontal story carousel.
2.  **Story Carousel Shows Only Self:** The story carousel at the top of the feed only queries for and displays stories from the currently logged-in user, not from other vendors the user follows.
3.  **No Story Viewer:** Tapping on a story avatar in the carousel is a no-op. There is no dedicated interface to view a user's sequence of stories (photos and videos).

This behavior stems from an incomplete implementation of the story feature, where the data is correctly flagged as a story upon upload but is not correctly queried or displayed in the UI.

## 2. Proposed Solution

To create a complete and intuitive story experience akin to platforms like Instagram, the following changes are required:

### Phase 1: Data Layer Correction

-   **Modify `FeedService.getStoriesStream()`:**
    -   The Firestore query must be updated to fetch snaps where `isStory == true` from all vendors the current user **follows**. This will likely require fetching the user's "following" list first and then performing a `whereIn` query on `vendorId`.
    -   The stream should correctly group snaps by `vendorId` to create a `List<StoryItem>`, where each `StoryItem` represents a vendor's story reel.

### Phase 2: UI - Story Viewer Screen

-   **Create `story_viewer_screen.dart`:**
    -   This new screen will be a stateful widget that accepts a list of `StoryItem`s and an initial index to start from.
    -   It will use a `PageView` to allow users to swipe horizontally between different vendors' stories.
    -   Each page within the `PageView` will manage the state for one vendor's story, using another `PageView` (or similar controller like `story_view`) to automatically advance through that vendor's individual snaps (photos and videos).
    -   Each snap view will overlay the caption at the bottom and a progress indicator at the top.
    -   For videos, it will use a `VideoPlayerController`; for images, an `Image` widget.
    -   For any media with a `filterType` set, it will apply the corresponding colored overlay, ensuring visual consistency with the media review screen.

### Phase 3: UI - Integration

-   **Update `feed_screen.dart`:**
    -   The `StoryCarouselWidget` will be passed an `onStoryTap` callback handler.
    -   This handler will navigate to the newly created `StoryViewerScreen`, passing the full list of stories and the index of the tapped story.

## 3. Implementation Checklist

-   [ ] **Data Layer:**
    -   [ ] Implement logic to fetch the current user's followed vendors.
    -   [ ] Update `getStoriesStream` to use the followed list to query for story snaps.
    -   [ ] Ensure `getStoriesStream` correctly groups snaps into `StoryItem`s.
-   [ ] **UI Layer:**
    -   [ ] Create `story_viewer_screen.dart` file.
    -   [ ] Implement the `PageView` for switching between vendors.
    -   [ ] Implement the logic for auto-advancing through a single vendor's snaps.
    -   [ ] Implement the UI for displaying a single snap (image/video, caption, filter overlay, user avatar/name).
    -   [ ] Handle user interactions like tap-to-pause and tap-to-advance.
-   [ ] **Integration:**
    -   [ ] Add `onStoryTap` to `StoryCarouselWidget`.
    -   [ ] In `FeedScreen`, implement the `onStoryTap` callback to navigate to `StoryViewerScreen`.
    -   [ ] Pass the required data (stories list, tapped index) to the viewer screen.
-   [ ] **Testing:**
    -   [ ] Verify that stories from followed vendors appear correctly.
    -   [ ] Verify that tapping a story opens the viewer to the correct content.
    -   [ ] Verify that video and photo snaps display correctly with captions and filter overlays.
    -   [ ] Verify that navigation and gestures within the story viewer work as expected. 