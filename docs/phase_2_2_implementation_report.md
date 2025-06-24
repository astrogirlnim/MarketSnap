# Phase 2.2 Implementation Report: Storage Buckets

**Date:** June 24, 2025

## 1. Summary

This report details the implementation of Phase 2, Step 2 of the MVP checklist: **Storage Buckets**. The primary goal was to establish secure and well-defined policies for media uploads to Firebase Storage.

The following tasks were completed:
-   A security rule was implemented in `storage.rules` to restrict uploads to the `/vendors/{uid}/snaps/` path.
-   The rule enforces a maximum object size of 1MB.
-   Read access was restricted to authenticated users only.
-   The requirement for a 30-day TTL (Time-To-Live) lifecycle rule was analyzed and documented.

## 2. Technical Implementation

### 2.1. Firebase Storage Security Rules

The `storage.rules` file was updated to enforce the required policies. The existing rule was modified for clarity and to restrict read access.

**File:** `storage.rules`

```
rules_version = '2';

service firebase.storage {
  match /b/{bucket}/o {
    // Match the path for vendor snaps.
    // Allow writes only if the user is authenticated, the path matches their UID,
    // and the file size is less than 1MB.
    // Read access is granted to any authenticated user.
    match /vendors/{userId}/snaps/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId
                   && request.resource.size < 1 * 1024 * 1024; // 1 MB
    }
  }
}
```

**Key Rule Components:**

*   `match /vendors/{userId}/snaps/{allPaths=**}`: This targets all files within any vendor's `snaps` directory.
*   `allow read: if request.auth != null;`: Restricts read access to any user who is logged in. This is a security improvement over allowing public reads.
*   `allow write: if request.auth != null && request.auth.uid == userId`: Ensures that only the authenticated owner of the vendor directory (`userId` must match `request.auth.uid`) can upload files.
*   `request.resource.size < 1 * 1024 * 1024`: Enforces the 1MB file size limit for all uploads.

These rules can be fully tested locally using the Firebase Emulator Suite.

### 2.2. TTL Lifecycle Rule (30-Day Deletion)

The second requirement was to configure a 30-day hard delete policy on stored objects.

**This is a Google Cloud Storage (GCS) lifecycle management policy, not a Firebase Storage security rule.** It cannot be configured or tested via the Firebase Emulator Suite.

**Configuration for Production:**

This rule must be applied directly to the GCS bucket used by the production Firebase project. It can be configured in two ways:

1.  **Via Google Cloud Console:**
    *   Navigate to the Cloud Storage browser in the Google Cloud Console.
    *   Select the project's storage bucket (e.g., `<project-id>.appspot.com`).
    *   Go to the "Lifecycle" tab.
    *   Add a rule to "Delete object" when the "Age" is greater than 30 days.

2.  **Via `gcloud` CLI (Recommended for Infrastructure-as-Code):**
    *   Create a JSON file (e.g., `gcs-lifecycle.json`) with the rule:
        ```json
        {
          "rule": [
            {
              "action": {
                "type": "Delete"
              },
              "condition": {
                "age": 30
              }
            }
          ]
        }
        ```
    *   Apply the rule using the `gcloud` command-line tool:
        ```bash
        gcloud storage buckets update gs://<your-bucket-name> --lifecycle-file=gcs-lifecycle.json
        ```

This configuration is noted in `docs/deployment.md` as a required step for production deployment.

## 3. Cross-Platform Considerations

The implemented storage rules are enforced by the Firebase backend and are inherently cross-platform. They apply to all client applications (iOS, Android, Web) without any platform-specific code changes. The Flutter application will receive a `FirebaseException` with a `permission-denied` code if any of these rules are violated during an upload attempt.

## 4. Testing

The security rules can be validated using the Firebase Emulator Suite. To test:
1.  Start the emulators: `firebase emulators:start`
2.  Attempt to upload files via a client connected to the emulators:
    *   **Success Case:** Upload a file < 1MB to `/vendors/<your-uid>/snaps/` as an authenticated user.
    *   **Failure Case (Size):** Upload a file > 1MB.
    *   **Failure Case (Auth):** Upload a file as an unauthenticated user.
    *   **Failure Case (Path):** Upload a file to another user's directory (e.g., `/vendors/<another-uid>/snaps/`).

The application's error handling logic should catch these failures gracefully.

## 5. Conclusion

Phase 2, Step 2 is complete. The storage bucket is secured with path and size restrictions, and a clear plan is in place for configuring the TTL policy in production. 