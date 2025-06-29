# RAG Personalization Integration Test

This integration test validates the complete Phase 4.9 RAG Personalization implementation end-to-end with Firebase emulators.

## Prerequisites

1. **Firebase Emulators Running**: Make sure the Firebase emulators are running with:
   ```bash
   firebase emulators:start
   ```

2. **Flutter Integration Test Package**: The test uses the `integration_test` package which should already be included in the project.

## Running the Integration Test

### Option 1: With Emulators (Recommended)

```bash
# Start Firebase emulators in one terminal
firebase emulators:start

# Run the integration test in another terminal  
flutter test integration_test/rag_personalization_integration_test.dart
```

### Option 2: Direct Flutter Integration Test

```bash
# Make sure emulators are running first
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/rag_personalization_integration_test.dart
```

## What This Test Validates

✅ **User Interest Management**
- Creating and updating user interests in Firestore
- Interest analytics and confidence calculation
- Data structure validation

✅ **Personalization Services**
- RAGPersonalizationService functionality
- Caching and performance optimization
- User preference calculations

✅ **RAG Integration** 
- Enhanced FAQ search with user preferences
- Personalized content ranking
- Recipe suggestions (if OpenAI key available)

✅ **Feedback Loop**
- Recording user feedback in both services
- Interest updates based on interactions
- Dual feedback system validation

✅ **Data Management**
- User data cleanup and deletion
- GDPR compliance features
- Account deletion support

## Expected Output

The test provides detailed console output showing:
- Step-by-step validation progress
- Analytics data (interactions, satisfaction, confidence)
- Sample FAQ results with personalized scoring
- Success confirmation for each component

## Troubleshooting

**If test fails with "No implementation found":**
- Make sure Firebase emulators are running on default ports
- Verify emulator configuration in `firebase.json`

**If recipe generation fails:**
- This is expected if OpenAI API key is not configured
- The test will skip recipe generation gracefully

**If Firestore connection fails:**
- Check that Firestore emulator is running on port 8080
- Verify Firebase project configuration

## Production Readiness

When this test passes completely, it confirms that:
- Phase 4.9 RAG Personalization is fully implemented ✅
- All services integrate properly ✅  
- Data flows work end-to-end ✅
- The system is ready for production deployment ✅ 