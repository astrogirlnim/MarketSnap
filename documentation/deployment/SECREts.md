# Secrets Management for CI/CD and Local Development

A clear distinction must be made between the secrets required for the CI/CD pipeline and those needed for local development. They serve different purposes and are stored in different locations for security reasons.

---

### 1. GitHub Actions Secrets (for Deployment Pipeline)

These secrets must be added to your GitHub repository under **Settings > Secrets and variables > Actions**. They enable the CI/CD pipeline to build, sign, and deploy your application automatically and securely without exposing sensitive credentials in your code.

| Secret Name                        | What It Is & Why It's Needed                                                                                                                                                                                               |
| :--------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`FIREBASE_SERVICE_ACCOUNT_KEY`** | **What:** The content of a JSON file for a Firebase service account. <br/> **Why:** This is the master key for the CI/CD pipeline. It authenticates GitHub Actions with your Firebase project, granting it permission to upload the built apps to Firebase App Distribution. |
| **`GOOGLE_SERVICES_JSON`**         | **What:** The content of the `google-services.json` file for your Android app. <br/> **Why:** The Android app requires this file at build time to connect to your Firebase project. As this file is not in version control, its content must be provided securely to the pipeline. |
| **`GOOGLE_SERVICE_INFO_PLIST_BASE64`** | **What:** The content of the `GoogleService-Info.plist` file for your iOS app, encoded in Base64. <br/> **Why:** This is the iOS equivalent of `google-services.json`. The pipeline needs it to configure the iOS app to communicate with Firebase. It's Base64 encoded to preserve the XML format correctly as a GitHub secret. |
| **`ANDROID_APP_ID`**               | **What:** The unique ID for your Android app within your Firebase project. <br/> **Why:** It tells Firebase App Distribution which specific app to associate the new Android build with.                                                                                 |
| **`IOS_APP_ID`**                   | **What:** The unique ID for your iOS app within your Firebase project. <br/> **Why:** It tells Firebase App Distribution which specific app to associate the new iOS build with.                                                                                     |
| **`BUILD_CERTIFICATE_BASE64`**     | **What:** Your Apple P12 distribution certificate, encoded in Base64. <br/> **Why:** To release an iOS app, it must be signed with an official Apple certificate to prove it's from a trusted developer. The CI pipeline uses this to sign the app before packaging. |
| **`P12_PASSWORD`**                 | **What:** The password you set when exporting your P12 certificate. <br/> **Why:** The P12 certificate is password-protected. The pipeline needs this password to unlock and use it for signing.                                                                        |
| **`BUILD_PROVISION_PROFILE_BASE64`** | **What:** Your Apple provisioning profile, encoded in Base64. <br/> **Why:** This profile ties your app ID, certificate, and developer account together. It is required by Apple to authorize distribution. The pipeline needs it to complete the code signing process. |
| **`KEYCHAIN_PASSWORD`**            | **What:** A password you create for a temporary keychain. <br/> **Why:** The macOS runner in GitHub Actions creates a temporary, secure keychain to store your signing certificate. This password is used to create and unlock that temporary keychain during the build. |

---

### 2. Local Environment Secrets (for `.env` file)

These secrets are for **local development only**. You must create a `.env` file in the root of your project (this file should be listed in `.gitignore`). When you run the app on your local machine, it loads these variables to connect to Firebase.

| Variable Name                 | What It Is & Why It's Needed                                                                                                                                               |
| :------------------------------ | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`ANDROID_API_KEY` / `IOS_API_KEY`** | **What:** Platform-specific API keys from your Firebase project. <br/> **Why:** Used by the running app to make authenticated calls to Firebase services like Firestore and Authentication. |
| **`FIREBASE_PROJECT_ID`**         | **What:** The globally unique ID for your Firebase project. <br/> **Why:** This is the primary identifier the app uses to know which Firebase project to connect to.                   |
| **`FIREBASE_MESSAGING_SENDER_ID`**  | **What:** A unique ID for Firebase Cloud Messaging. <br/> **Why:** Required if your app uses Firebase for push notifications.                                                    |
| **`FIREBASE_STORAGE_BUCKET`**     | **What:** The URL of your Firebase Storage bucket. <br/> **Why:** Tells the app where to upload and download files (e.g., images, user content).                                |
| **`ANDROID_APP_ID` / `IOS_APP_ID`**   | **What:** The same Firebase-specific app IDs used in the CI pipeline. <br/> **Why:** Allows the running app to identify itself to Firebase Analytics and other services.           |
| **`APP_BUNDLE_ID`**               | **What:** Your application's bundle ID for iOS (`com.company.appname`). <br/> **Why:** While Firebase uses its own app IDs, this native identifier is often used for other services or deep linking. |

</rewritten_file> 