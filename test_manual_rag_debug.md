# Manual RAG Personalization Testing Debug Guide

## Console Debugging Commands

### View User Interests in Firestore Emulator
1. Open `http://localhost:4000` (Firebase Emulator UI)
2. Go to Firestore tab
3. Look for `userInterests` collection
4. Find your user ID document
5. Check fields:
   - `preferredKeywords`: Your top keywords
   - `totalInteractions`: Should increase with each feedback
   - `satisfactionScore`: 0.0-1.0 based on thumbs up/down
   - `personalizationConfidence`: Increases with more data

### Flutter Debug Console Logs
Look for these log patterns:

```dart
[RAGService] Enhanced user preferences loaded for user: YOUR_USER_ID
[RAGService] Personalization confidence: 0.XX (XX% confidence)
[RAGPersonalizationService] User interests updated: X interactions
[RAGPersonalizationService] Confidence threshold reached: Enhanced personalization active
```

### Manual Testing Checklist

#### 🎯 **Verify Basic Functionality**
- [ ] FAQ search returns results
- [ ] Recipe generation works (or gracefully fails without OpenAI)
- [ ] Feedback buttons (👍/👎) are responsive
- [ ] Loading states appear during AI calls

#### 🧠 **Verify Personalization Logic**
- [ ] After 5+ interactions, console shows "Enhanced personalization active"
- [ ] User interests document appears in Firestore
- [ ] Keywords you've given positive feedback appear in `preferredKeywords`
- [ ] `satisfactionScore` reflects your feedback pattern (higher with more 👍)

#### 🔄 **Verify Feedback Loop**
- [ ] Give 👍 to "tomato" recipes → Search "cooking" → Should see tomato-related FAQs ranked higher
- [ ] Give 👎 to certain content → Should see different suggestions
- [ ] Mix positive/negative feedback → `satisfactionScore` adjusts accordingly

#### 📊 **Analytics Verification**
```dart
// Add this to any screen for debugging:
ElevatedButton(
  onPressed: () async {
    final analytics = await RAGPersonalizationService().getUserInterestAnalytics('YOUR_USER_ID');
    print('📊 User Analytics: $analytics');
  },
  child: Text('Debug Analytics'),
)
```

## Test Scenarios

### Scenario 1: New User (No Personalization)
1. Fresh install or cleared data
2. Should see basic FAQ/recipe results
3. Console: "Basic user preferences used"

### Scenario 2: Learning Phase (1-4 interactions)
1. Give some feedback
2. Should see slight preference adjustments
3. Console: "Confidence below threshold"

### Scenario 3: Personalized User (5+ interactions)
1. Provide varied feedback on different topics
2. Should see enhanced personalization
3. Console: "Enhanced personalization active"
4. Results should reflect your preferences

### Scenario 4: Mixed Feedback Testing
1. Give 👍 to "Italian" and "pasta" content
2. Give 👎 to "spicy" content  
3. Search "dinner ideas"
4. Should see Italian/pasta suggestions, fewer spicy ones

## Troubleshooting

### No personalization happening?
- Check Firebase emulator is running
- Verify user is authenticated
- Look for error logs in console
- Check `userInterests` collection exists

### FAQ search not working?
- Verify Cloud Functions emulator running
- Check network connectivity to localhost:5001
- Look for CORS issues in browser console

### Recipe generation failing?
- Expected without OpenAI API key
- Should show graceful error message
- FAQ search should still work

## Expected Timelines
- **Immediate**: Basic FAQ/recipe functionality
- **After 2-3 interactions**: Preferences start recording
- **After 5+ interactions**: Enhanced personalization kicks in
- **After 10+ interactions**: Strong personalization patterns 

## Filter Display Issue Fix (December 28, 2024)

### 🐛 Issue Identified: Double-Filtering Bug
**Problem:** Filtered images from vendors were appearing over-processed or incorrect when viewed by regular users on different devices.

**Root Cause:** Double-filtering in the display pipeline:
1. **During Capture**: LUT filter service processed images and created filtered versions  
2. **During Upload**: Filtered images were uploaded to Firebase Storage
3. **During Display**: Feed widget applied additional color overlays based on `filterType` field

**Result:** Images had both LUT processing AND color overlay, causing over-filtering.

### ✅ Solution Implemented
**Fixed in `lib/features/feed/presentation/widgets/feed_post_widget.dart`:**

1. **Images**: Removed color overlay logic since images are already LUT-processed
2. **Videos**: Kept color overlay logic since videos use preview-only filters
3. **Clear Logging**: Added distinct logging for image vs video filter handling

**Technical Changes:**
```dart
// OLD (Double-filtering):
Image.network(snap.mediaUrl) + Color overlay based on filterType

// NEW (Correct):
Image.network(snap.mediaUrl) // Already filtered image, no overlay needed
```

### 🧪 Testing the Fix

1. **Capture Test Media:**
   - Take photos with different filters (warm, cool, contrast)
   - Upload from vendor account

2. **Cross-Device Verification:**
   - View same filtered posts on different devices
   - Images should look consistent and properly filtered

3. **Video vs Image Comparison:**
   - Videos should still show overlay effects (preview-only)
   - Images should show processed filters (no additional overlay)

### 📊 Expected Results
- ✅ Filtered images appear consistent across all devices
- ✅ No over-processing or double-filtering effects
- ✅ Vendor and regular user see identical filtered content
- ✅ Videos still show filter previews correctly 