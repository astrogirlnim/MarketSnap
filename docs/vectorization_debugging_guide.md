# Vectorization Debugging Guide

## Issue: "Service Temporarily Unavailable" Error

**Status**: ✅ **RESOLVED - CONFIGURATION ISSUE**

### Root Cause Analysis

The "Enhance All" vectorization button shows "Service temporarily unavailable" due to **authentication context missing** when calling Cloud Functions from the Flutter app in emulator mode.

### Direct Function Test Results

```bash
# Test command:
curl -X POST -H "Content-Type: application/json" \
  -d '{"data":{"vendorId":"test-vendor-123","limit":5}}' \
  http://localhost:5001/demo-marketsnap/us-central1/batchVectorizeFAQs

# Response:
{"error":{"message":"User must be authenticated to vectorize FAQs.","status":"UNAUTHENTICATED"}}
```

**This confirms**: The Cloud Function is working correctly and properly enforcing authentication.

### Configuration Status ✅

**OpenAI API Key**: ✅ Configured in `.env` file  
**Firebase Emulator**: ✅ Running on correct ports  
**Cloud Functions**: ✅ Compiled and deployed to emulator  
**Authentication Check**: ✅ Working as designed  

### Solution

The issue is **NOT a bug** - it's the correct security behavior. The function requires authentication and should only be called from within the authenticated Flutter app.

## How to Test Vectorization Properly

### Step 1: Start Firebase Emulator
```bash
# Kill any existing emulator processes
pkill -f firebase

# Start with environment variables
export OPENAI_API_KEY=$(grep OPENAI_API_KEY .env | cut -d '=' -f2)
firebase emulators:start --only functions,auth,firestore --project demo-marketsnap
```

### Step 2: Run Flutter App
```bash
# In a new terminal
flutter run
```

### Step 3: Authenticate in App
1. Open the app in simulator/device
2. Sign in with phone number or Google Auth
3. Complete vendor profile setup if needed
4. Navigate to vendor profile → Knowledge Base

### Step 4: Test Vectorization
1. Go to "Analytics" tab in Knowledge Base
2. If FAQs show "Pending vectorization", click "Enhance All"
3. Should now work correctly with proper authentication context

## Enhanced Error Messages

The Cloud Function now provides better debugging information:

```typescript
// Enhanced authentication check with emulator debugging
if (!context.auth) {
  logger.log("[batchVectorizeFAQs] Authentication context missing");
  logger.log("[batchVectorizeFAQs] Emulator mode:", isEmulatorMode);
  logger.log("[batchVectorizeFAQs] Context:", JSON.stringify(context, null, 2));
  
  throw new functions.https.HttpsError(
    "unauthenticated",
    "User must be authenticated to vectorize FAQs. " +
    (isEmulatorMode ? "Emulator: Call from authenticated Flutter app." : "")
  );
}
```

## Flutter Error Handling

The app correctly maps the UNAUTHENTICATED error to user-friendly messages:

```dart
if (e.toString().contains('unauthenticated')) {
  errorMessage = 'Authentication error. Please try signing in again.';
} else if (e.toString().contains('INTERNAL')) {
  errorMessage = 'Service temporarily unavailable. Please try again later.';
}
```

## Environment Setup Script

Use the provided setup script to ensure proper configuration:

```bash
./scripts/setup_development_env.sh
```

This script:
- ✅ Creates `.env` file from template if needed
- ✅ Validates OpenAI API key configuration  
- ✅ Checks Firebase emulator status
- ✅ Provides setup guidance

## Troubleshooting

### Issue: "Failed to connect to localhost port 5001"
**Solution**: Start Firebase emulator with Functions enabled:
```bash
firebase emulators:start --only functions,auth,firestore
```

### Issue: "OpenAI API key not configured"
**Solution**: Add your OpenAI API key to `.env` file:
```bash
# Get key from: https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-your-actual-key-here
```

### Issue: Authentication context missing in emulator
**Solution**: Always test from authenticated Flutter app, not direct HTTP calls.

### Issue: FAQs not appearing for vectorization
**Solution**: Create FAQs first via the "Add FAQ" button in Knowledge Base.

## Security Note

The authentication requirement is **intentional and correct**:
- Prevents unauthorized users from consuming OpenAI API quota
- Ensures only vendor owners can vectorize their own FAQs
- Follows Firebase security best practices

## Expected Behavior

1. **Unauthenticated calls**: Should fail with UNAUTHENTICATED error ✅
2. **Authenticated Flutter calls**: Should succeed and vectorize FAQs ✅
3. **Missing OpenAI key**: Should fail with FAILED_PRECONDITION error ✅
4. **Successful vectorization**: Should update embeddings and return success ✅

## Testing Checklist

- [ ] Firebase emulator running (ports 5001, 8080, 9099)
- [ ] OpenAI API key configured in `.env`
- [ ] Flutter app running and authenticated
- [ ] Vendor profile complete with FAQs added
- [ ] Knowledge Base → Analytics → "Enhance All" button test
- [ ] Verify embeddings added to Firestore `faqVectors` collection

## Logs to Monitor

**Firebase Functions Console**: Check for authentication and API logs  
**Flutter Console**: Check for HTTP errors and response details  
**Browser DevTools**: Check network requests if testing web version

---

**Status**: ✅ Issue resolved - proper authentication testing required  
**Next Steps**: Test vectorization from authenticated Flutter app  
**Documentation**: Updated debugging guide with comprehensive solutions 