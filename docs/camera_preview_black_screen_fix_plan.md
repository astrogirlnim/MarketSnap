# Camera Preview Black Screen Fix Plan

## Overview

**Issue:**
- When capturing a photo or video, the camera preview area goes black instead of showing the live preview with a progress indicator or countdown. The capture itself works, but the user experience is degraded.
- This is due to logic in `CameraPreviewScreen` that replaces the preview with a black container during `_isTakingPhoto` or `_isRecordingVideo` states, originally intended to prevent navigation crashes.

**Current State:**
- The preview is always hidden during capture, even though the controller is valid until navigation completes.
- The codebase contains defensive logic that needs to be refactored for better UX without reintroducing crashes.

**Related Files:**
- `lib/features/capture/presentation/screens/camera_preview_screen.dart`
- `lib/features/capture/application/camera_service.dart`
- (Potentially) `lib/features/capture/presentation/screens/media_review_screen.dart`

**Key Variables:**
- `_isTakingPhoto`, `_isRecordingVideo` (state flags)
- `_cameraService.controller` (camera controller)
- `_buildCameraPreview()` (preview widget)

---

## Phase 1: Analysis & Logging
- [ ] Review all state transitions for `_isTakingPhoto` and `_isRecordingVideo`.
- [ ] Add deep debug logging for all capture/recording state changes, navigation, and controller disposal.
- [ ] Confirm that the controller is not disposed until after navigation completes.

## Phase 2: UI Refactor
- [ ] Refactor the `build` method in `CameraPreviewScreen`:
    - Remove the logic that replaces the preview with a black container during capture/recording.
    - Always display the camera preview when the controller is valid.
    - Overlay a semi-transparent progress indicator (spinner) for photo capture, or a countdown for video recording, on top of the preview.
- [ ] Ensure overlays are non-blocking and visually clear.

## Phase 3: Controller Lifecycle
- [ ] Ensure the camera controller is only paused/disposed after navigation to the media review screen is complete.
- [ ] Move any pause/dispose logic to after the navigation `await`.
- [ ] Add error handling and logging for controller disposal.

## Phase 4: Testing & Validation
- [ ] Test photo and video capture flows on both emulator and real device.
- [ ] Test rapid tab switching and navigation to ensure no crashes or preview loss.
- [ ] Validate that the preview remains visible during all capture states, and overlays are correct.
- [ ] Confirm that no regressions are introduced (e.g., navigation crashes, buffer overflows).

## Phase 5: Documentation & Commit
- [ ] Document all changes and rationale in this plan and in code comments.
- [ ] Commit the fix with a clear message (do not push).
- [ ] Delete any test files created during validation.

---

## Summary Table

| Phase   | Feature/Task                                      | Related Files                                             |
|---------|---------------------------------------------------|----------------------------------------------------------|
| 1       | Logging & Analysis                                | camera_preview_screen.dart, camera_service.dart           |
| 2       | UI Refactor (overlay, always show preview)        | camera_preview_screen.dart                                |
| 3       | Controller Lifecycle (pause/dispose after nav)    | camera_preview_screen.dart, camera_service.dart           |
| 4       | Testing & Validation                              | camera_preview_screen.dart, media_review_screen.dart      |
| 5       | Documentation & Commit                            | docs/camera_preview_black_screen_fix_plan.md, code files  |

---

## Current State of Codebase
- The preview is hidden during capture due to defensive logic in the build method.
- The controller is paused/disposed before navigation, which is no longer necessary with proper overlay logic.
- The codebase is well-structured, with clear separation of service and UI layers, but needs improved state management for UX.

---

## Next Steps
- Begin with Phase 1: Add logging and review all state transitions.
- Proceed through each phase, ensuring robust testing and documentation at every step.

---

Yoda says: "Visible, the preview must remain. Overlay, not hide, you shall. Fix this, and strong your app will be." 