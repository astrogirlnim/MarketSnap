/**
 * The Cloud Functions for Firebase SDK to create Cloud Functions and triggers.
 *
 * @see {@link https://firebase.google.com/docs/functions}
 */
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import {logger} from "firebase-functions";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import {CallableContext} from "firebase-functions/v1/https";
import * as dotenv from "dotenv";
import * as path from "path";

// Load environment variables from the root of the project
dotenv.config({path: path.resolve(__dirname, "../../.env")});

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();
const messaging = admin.messaging();

logger.log("Cold start: Initialized Firebase Admin SDK.");

/**
 * Retrieves all FCM tokens for a given vendor's followers.
 * @param {string} vendorId The ID of the vendor.
 * @return {Promise<string[]>} A promise that resolves with an array of
 * FCM tokens.
 */
const getFollowerTokens = async (vendorId: string): Promise<string[]> => {
  logger.log(`[getFollowerTokens] Starting for vendorId: ${vendorId}`);
  const tokens: string[] = [];
  try {
    const followersSnapshot = await db
      .collection(`vendors/${vendorId}/followers`)
      .get();

    if (followersSnapshot.empty) {
      logger.log(
        `[getFollowerTokens] No followers found for vendor: ${vendorId}`
      );
      return [];
    }

    followersSnapshot.forEach((doc) => {
      const follower = doc.data();
      // Assuming the FCM token is stored in a field named 'fcmToken'
      if (follower.fcmToken) {
        tokens.push(follower.fcmToken);
        logger.log(
          `[getFollowerTokens] Found token for follower ${doc.id}: ` +
            `${follower.fcmToken.substring(0, 10)}...`
        );
      } else {
        logger.warn(
          `[getFollowerTokens] Follower ${doc.id} for vendor ` +
            `${vendorId} is missing an fcmToken.`
        );
      }
    });

    logger.log(
      `[getFollowerTokens] Successfully retrieved ${tokens.length} tokens ` +
        `for vendor ${vendorId}.`
    );
  } catch (error) {
    logger.error(
      `[getFollowerTokens] Error retrieving tokens for vendor ${vendorId}:`,
      error
    );
    throw new functions.https.HttpsError(
      "internal",
      "Failed to retrieve follower tokens."
    );
  }
  return tokens;
};

/**
 * Retrieves FCM token for a specific user.
 * @param {string} userId The ID of the user.
 * @return {Promise<string|null>} A promise that resolves with the FCM token
 * or null if not found.
 */
const getUserFCMToken = async (userId: string): Promise<string | null> => {
  logger.log(`[getUserFCMToken] Getting FCM token for user: ${userId}`);
  try {
    // Check if user has FCM token stored in vendors collection
    const vendorDoc = await db.collection("vendors").doc(userId).get();
    if (vendorDoc.exists) {
      const vendorData = vendorDoc.data();
      if (vendorData?.fcmToken) {
        logger.log(
          `[getUserFCMToken] Found FCM token for vendor ${userId}: ` +
            `${vendorData.fcmToken.substring(0, 10)}...`
        );
        return vendorData.fcmToken;
      }
    }

    // TODO: In a full implementation, you might also check a separate
    // users collection or followers collection for FCM tokens
    logger.warn(`[getUserFCMToken] No FCM token found for user: ${userId}`);
    return null;
  } catch (error) {
    logger.error(
      `[getUserFCMToken] Error retrieving FCM token for user ${userId}:`,
      error
    );
    return null;
  }
};

/**
 * Cloud Function to send a push notification when a new snap is created.
 */
export const sendFollowerPush = onDocumentCreated(
  "vendors/{vendorId}/snaps/{snapId}",
  async (event) => {
    const {vendorId, snapId} = event.params;
    const snap = event.data;
    if (!snap) {
      logger.error("[sendFollowerPush] No data associated with the event.");
      return;
    }
    const snapData = snap.data();

    logger.log(
      `[sendFollowerPush] Triggered for new snap: ${snapId} ` +
        `from vendor: ${vendorId}`
    );
    logger.log("[sendFollowerPush] Snap data:", snapData);

    try {
      // 1. Get vendor details for the notification title
      logger.log(
        "[sendFollowerPush] Fetching vendor details for " +
          `vendorId: ${vendorId}`
      );
      const vendorDoc = await db.collection("vendors").doc(vendorId).get();
      if (!vendorDoc.exists) {
        logger.error(
          `[sendFollowerPush] Vendor document ${vendorId} not found.`
        );
        return;
      }
      const vendorData = vendorDoc.data();
      const stallName = vendorData?.stallName || "A Market Vendor";
      logger.log(`[sendFollowerPush] Vendor stall name: ${stallName}`);

      // 2. Get all follower tokens
      const tokens = await getFollowerTokens(vendorId);
      if (tokens.length === 0) {
        logger.log(
          "[sendFollowerPush] No follower tokens found for vendor " +
            `${vendorId}. Exiting function.`
        );
        return;
      }

      // 3. Construct the notification payload
      // Using a generic message for now as snapData structure is not
      // fully defined
      const snapText = snapData.text || "has posted a new snap!";
      const payload = {
        notification: {
          title: `${stallName} has a new Snap!`,
          body: snapText,
        },
        data: {
          vendorId: vendorId,
          snapId: snapId,
          // This will help the client app navigate to the correct content
          type: "new_snap",
        },
      };
      logger.log(
        "[sendFollowerPush] Constructed notification payload:",
        payload
      );

      // 4. Send notifications
      logger.log(
        `[sendFollowerPush] Sending notifications to ${tokens.length} ` +
          "followers."
      );
      const response = await messaging.sendEachForMulticast({
        tokens,
        ...payload,
      });
      logger.log(
        `[sendFollowerPush] Successfully sent ${response.successCount} ` +
          "messages."
      );

      if (response.failureCount > 0) {
        logger.warn(
          `[sendFollowerPush] Failed to send ${response.failureCount} ` +
            "messages."
        );
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
            logger.error(
              "[sendFollowerPush] Failure for token " +
                `${tokens[idx].substring(0, 10)}...:`,
              resp.error
            );
          }
        });
        // TODO: Implement cleanup for invalid tokens
        logger.warn("[sendFollowerPush] Failed tokens:", failedTokens);
      }
    } catch (error) {
      logger.error(
        `[sendFollowerPush] Unexpected error for snap ${snapId}:`,
        error
      );
    }
  }
);

/**
 * Cloud Function to fan out a broadcast message via push notification.
 */
export const fanOutBroadcast = onDocumentCreated(
  "vendors/{vendorId}/broadcasts/{broadcastId}",
  async (event) => {
    const {vendorId, broadcastId} = event.params;
    const broadcast = event.data;
    if (!broadcast) {
      logger.error("[fanOutBroadcast] No data associated with the event.");
      return;
    }
    const broadcastData = broadcast.data();

    logger.log(
      `[fanOutBroadcast] Triggered for new broadcast: ${broadcastId} ` +
        `from vendor: ${vendorId}`
    );
    logger.log("[fanOutBroadcast] Broadcast data:", broadcastData);

    // Check for message content
    const message = broadcastData.message;
    if (!message) {
      logger.error(
        "[fanOutBroadcast] Broadcast message is empty or missing. Exiting."
      );
      return;
    }

    try {
      // 1. Get vendor details for the notification title
      logger.log(
        "[fanOutBroadcast] Fetching vendor details for " +
          `vendorId: ${vendorId}`
      );
      const vendorDoc = await db.collection("vendors").doc(vendorId).get();
      if (!vendorDoc.exists) {
        logger.error(
          `[fanOutBroadcast] Vendor document ${vendorId} not found.`
        );
        return;
      }
      const vendorData = vendorDoc.data();
      const stallName = vendorData?.stallName || "A Market Vendor";
      logger.log(`[fanOutBroadcast] Vendor stall name: ${stallName}`);

      // 2. Get all follower tokens
      const tokens = await getFollowerTokens(vendorId);

      if (tokens.length === 0) {
        logger.log(
          "[fanOutBroadcast] No follower tokens found for vendor " +
            `${vendorId}. Exiting function.`
        );
        return;
      }

      // 3. Construct the notification payload
      const payload = {
        notification: {
          title: `Message from ${stallName}`,
          body: message,
        },
        data: {
          vendorId: vendorId,
          broadcastId: broadcastId,
          // This will help the client app navigate to the correct content
          type: "new_broadcast",
        },
      };
      logger.log(
        "[fanOutBroadcast] Constructed notification payload:",
        payload
      );

      // 4. Send notifications
      logger.log(
        `[fanOutBroadcast] Sending broadcast to ${tokens.length} followers.`
      );
      const response = await messaging.sendEachForMulticast({
        tokens,
        ...payload,
      });

      logger.log(
        `[fanOutBroadcast] Successfully sent ${response.successCount} ` +
          "messages."
      );
      if (response.failureCount > 0) {
        logger.warn(
          `[fanOutBroadcast] Failed to send ${response.failureCount} ` +
            "messages."
        );
        const failedTokens: string[] = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(tokens[idx]);
            logger.error(
              "[fanOutBroadcast] Failure for token " +
                `${tokens[idx].substring(0, 10)}...:`,
              resp.error
            );
          }
        });
        // TODO: Implement cleanup for invalid tokens
        logger.warn("[fanOutBroadcast] Failed tokens:", failedTokens);
      }
    } catch (error) {
      logger.error(
        `[fanOutBroadcast] Unexpected error for broadcast ${broadcastId}:`,
        error
      );
    }
  }
);

/**
 * Cloud Function to send a push notification when a new message is created.
 */
export const sendMessageNotification = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const messageSnap = event.data;
    if (!messageSnap) {
      logger.error(
        "[sendMessageNotification] No data associated with the event."
      );
      return;
    }
    const message = messageSnap.data();
    const {fromUid, toUid, text} = message;

    logger.log(
      "[sendMessageNotification] Triggered for new message from " +
      `${fromUid} to ${toUid}`
    );

    try {
      // 1. Get sender's name
      const fromUserDoc = await db.collection("vendors").doc(fromUid).get();
      const fromUserName = fromUserDoc.data()?.stallName || "Someone";

      // 2. Get recipient's FCM token
      const toUserToken = await getUserFCMToken(toUid);
      if (!toUserToken) {
        logger.warn(
          `[sendMessageNotification] Recipient ${toUid} does not have ` +
          "an FCM token. Cannot send notification."
        );
        return;
      }

      // 3. Construct payload
      const payload = {
        notification: {
          title: `New message from ${fromUserName}`,
          body: text,
        },
        data: {
          type: "new_message",
          fromUid: fromUid,
          fromName: fromUserName,
        },
      };

      logger.log(
        "[sendMessageNotification] Sending notification payload:",
        payload
      );

      // 4. Send notification
      await messaging.send({
        token: toUserToken,
        ...payload,
      });

      logger.log(
        `[sendMessageNotification] Successfully sent notification to ${toUid}`
      );
    } catch (error) {
      logger.error(
        "[sendMessageNotification] Error sending message notification:",
        error
      );
    }
  }
);

// --- AI Helper Functions (Phase 2 Scaffolding) ---

// Configuration for AI Functions - support both environment variables
// and Firebase config
const AI_FUNCTIONS_ENABLED =
  process.env.AI_FUNCTIONS_ENABLED === "true" ||
  functions.config().ai?.functions_enabled === "true" ||
  functions.config().marketsnap?.ai?.enabled === "true";

const OPENAI_API_KEY =
  process.env.OPENAI_API_KEY ||
  functions.config().marketsnap?.openai?.key;

/**
 * A disabled-aware wrapper for HTTPS callable functions.
 * @param {string} functionName The name of the function for logging.
 * @param {function} handler The function handler to execute when AI
 * functions are enabled.
 * @return {functions.https.HttpsFunction} A callable HTTPS function.
 */
const createAIHelper = (
  functionName: string,
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  handler: (data: any, context: CallableContext) => any
) => {
  return functions.https.onCall(async (data, context) => {
    logger.log(`[${functionName}] received request.`);

    // Allow calls from Firebase emulator during development
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      logger.log(`[${functionName}] Running in emulator mode`);
    } else {
      // In production, require authentication
      if (!context.auth) {
        logger.error(`[${functionName}] Authentication required`);
        throw new functions.https.HttpsError(
          "unauthenticated",
          "Authentication required"
        );
      }
      logger.log(`[${functionName}] Authenticated user: ${context.auth.uid}`);
    }

    if (!AI_FUNCTIONS_ENABLED) {
      logger.warn(
        `[${functionName}] AI functions are disabled. ` +
        "Returning dummy response."
      );
      return {
        status: "disabled",
        message: "This AI function is currently disabled.",
      };
    }

    // Check for OpenAI API key
    if (!OPENAI_API_KEY) {
      logger.error(`[${functionName}] OPENAI_API_KEY is not set.`);
      throw new functions.https.HttpsError(
        "internal",
        "The server is missing an API key for an AI service."
      );
    }
    logger.log(
      `[${functionName}] Found OpenAI Key: ` +
      `sk-...${OPENAI_API_KEY.slice(-4)}`
    );

    // TODO: Phase 4 - Replace with actual implementation
    return handler(data, context);
  });
};

/**
 * Generates a caption for an image.
 * [Phase 4: Fully Implemented]
 */
export const generateCaption = createAIHelper(
  "generateCaption",
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async (data, context) => {
    logger.log("[generateCaption] Processing caption generation request");

    try {
      // Extract parameters from request
      const {mediaType, existingCaption, vendorProfile, imageBase64} = data;

      logger.log(`[generateCaption] MediaType: ${mediaType || "photo"}`);
      logger.log(
        `[generateCaption] ExistingCaption: ${existingCaption || "none"}`
      );
      logger.log(
        "[generateCaption] VendorProfile: " +
        `${JSON.stringify(vendorProfile || {})}`
      );
      logger.log(
        "[generateCaption] ImageBase64 length: " +
        `${imageBase64?.length || 0} characters`
      );

      // Import OpenAI (dynamic import to handle potential missing dependency)
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let OpenAI: any;
      try {
        OpenAI = (await import("openai")).default;
      } catch (importError) {
        logger.error(
          "[generateCaption] OpenAI package not installed:",
          importError
        );
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI package is not installed in the functions environment."
        );
      }

      // Initialize OpenAI client
      const openai = new OpenAI({
        apiKey: OPENAI_API_KEY,
      });

      // Build context-aware prompt for marketplace content
      const vendorName = vendorProfile?.stallName || "vendor";
      const marketCity = vendorProfile?.marketCity || "local market";

      const basePrompt = "You are Wicker, the friendly AI mascot for " +
        "MarketSnap! 🧺 You help farmers market vendors create engaging " +
        `social media captions for their products.

Context:
- Vendor: ${vendorName}
- Market: ${marketCity}
- Media type: ${mediaType || "photo"}
${existingCaption ? `- Current caption: "${existingCaption}"` : ""}

Create a short, engaging caption (under 100 characters) that:
- Works for ANY market product (fresh produce, baked goods, crafts, ` +
        `flowers, prepared foods, artisan items, etc.)
- Captures the local, handmade, or fresh market vibe
- Encourages shoppers to visit or buy
- Uses appropriate emojis (1-2 max) that match the product type
- Feels authentic and not overly promotional
- Highlights quality, craftsmanship, freshness, or uniqueness ` +
        `as appropriate
- Adapts tone to the product (food = fresh/delicious, ` +
        `crafts = handmade/unique, etc.)

${existingCaption ?
    "Improve the existing caption while keeping the same general " +
    "meaning and product focus." :
    "Generate a new caption based on what you see or the context " +
    "provided. If you can identify the product type from the image, " +
    "tailor the caption accordingly."
}

Return only the caption text, no quotes or extra formatting.`;

      // Prepare messages array
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      const messages: any[] = [];

      // If we have image data, use vision model for better context
      if (imageBase64 && mediaType === "photo") {
        logger.log(
          "[generateCaption] Using GPT-4 Vision for image analysis"
        );
        messages.push({
          role: "user",
          content: [
            {
              type: "text",
              text: basePrompt + "\n\nBased on the image provided, " +
                "create a caption that describes what you see. Look for: " +
                "fresh produce, baked goods, crafts, flowers, prepared " +
                "foods, artisan items, or any other market products. " +
                "Tailor your caption to match the specific product type " +
                "and its appeal.",
            },
            {
              type: "image_url",
              image_url: {
                url: `data:image/jpeg;base64,${imageBase64}`,
                detail: "low", // Use low detail for faster processing
              },
            },
          ],
        });
      } else {
        // Text-only prompt when no image
        messages.push({
          role: "user",
          content: basePrompt,
        });
      }

      logger.log("[generateCaption] Sending request to OpenAI GPT-4");

      // Call OpenAI API with appropriate model
      const modelName = imageBase64 && mediaType === "photo" ?
        "gpt-4o" : "gpt-4o";
      const completion = await openai.chat.completions.create({
        model: modelName,
        messages: messages,
        max_tokens: 100,
        temperature: 0.7,
        top_p: 1,
        frequency_penalty: 0.2,
        presence_penalty: 0.1,
      });

      const generatedCaption = completion.choices[0]?.message?.content?.trim();

      if (!generatedCaption) {
        throw new Error("OpenAI returned empty response");
      }

      logger.log(`[generateCaption] Generated caption: "${generatedCaption}"`);

      // Calculate confidence based on response quality metrics
      const lengthBonus = generatedCaption.length > 20 ? 0.1 : 0;
      const emojiBonus = (generatedCaption.includes("🍅") ||
        generatedCaption.includes("🥬") ||
        generatedCaption.includes("🌽")) ? 0.05 : 0;
      const confidence = Math.min(0.95, Math.max(0.7,
        0.8 + lengthBonus + emojiBonus
      ));

      const response = {
        caption: generatedCaption,
        confidence: confidence,
        model: "gpt-4",
        timestamp: new Date().toISOString(),
      };

      logger.log(`[generateCaption] Success! Confidence: ${confidence}`);
      return response;
    } catch (error) {
      logger.error("[generateCaption] Error generating caption:", error);

      // Return appropriate error
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      const errorMessage = error instanceof Error ?
        error.message : "Unknown error";
      throw new functions.https.HttpsError(
        "internal",
        `Failed to generate caption: ${errorMessage}`
      );
    }
  }
);

/**
 * Gets a recipe snippet based on snap content using OpenAI GPT-4.
 * Analyzes caption and keywords to generate relevant recipe suggestions.
 */
export const getRecipeSnippet = createAIHelper(
  "getRecipeSnippet",
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async (data, context) => {
    logger.log("[getRecipeSnippet] Starting recipe generation");
    logger.log("[getRecipeSnippet] Input data:", data);

    // eslint-disable-next-line @typescript-eslint/no-unused-vars
    const {caption, keywords, mediaType, vendorId, userPreferences} = data;

    if (!caption) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Caption is required for recipe generation"
      );
    }

    try {
      // Get OpenAI API key
      const OPENAI_API_KEY =
        process.env.OPENAI_API_KEY ||
        functions.config().marketsnap?.openai?.key;
      if (!OPENAI_API_KEY) {
        logger.error("[getRecipeSnippet] OpenAI API key not found");
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI API key is not configured"
        );
      }

      logger.log(
        `[getRecipeSnippet] Processing caption: "${caption}" with ` +
        `${(keywords || []).length} keywords and user preferences: ` +
        `${userPreferences ? JSON.stringify(userPreferences) : "none"}`
      );

      // Import OpenAI
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let OpenAI: any;
      try {
        OpenAI = (await import("openai")).default;
      } catch (importError) {
        logger.error(
          "[getRecipeSnippet] OpenAI package not installed:",
          importError
        );
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI package is not installed"
        );
      }

      // Initialize OpenAI client
      const openai = new OpenAI({
        apiKey: OPENAI_API_KEY,
      });

      // Build enhanced user preferences context
      let userPreferencesContext = "";
      if (userPreferences && Object.keys(userPreferences).length > 0) {
        const preferredKeywords = userPreferences.preferredKeywords || [];
        const preferredCategories = userPreferences.preferredCategories || [];
        const preferredContentType =
          userPreferences.preferredContentType || "balanced";
        const totalPositiveFeedback =
          userPreferences.totalPositiveFeedback || 0;
        const satisfactionScore = userPreferences.satisfactionScore || 0;
        const personalizationConfidence =
          userPreferences.personalizationConfidence || 0;
        const recentSearchTerms = userPreferences.recentSearchTerms || [];
        const favoriteVendors = userPreferences.favoriteVendors || [];
        const keywordRelevanceScores =
          userPreferences.keywordRelevanceScores || {};
        const hasSignificantData = userPreferences.hasSignificantData || false;

        if (hasSignificantData && personalizationConfidence > 0.3) {
          // Enhanced personalization for users with sufficient data
          const topKeywords = preferredKeywords
            .slice(0, 5)
            .map((keyword: string) => {
              const score = keywordRelevanceScores[keyword];
              return score ? `${keyword} (${score.toFixed(2)})` : keyword;
            })
            .join(", ");

          const confScore = personalizationConfidence.toFixed(2);
          const satScore = satisfactionScore.toFixed(2);
          const topCategories = preferredCategories.slice(0, 3).join(", ");
          const topSearches = recentSearchTerms.slice(0, 3).join(", ");

          userPreferencesContext = `

ENHANCED USER PREFERENCES (confidence: ${confScore}, ` +
            `${totalPositiveFeedback} positive interactions):
- Highly preferred ingredients: ${topKeywords}
- Preferred food categories: ${topCategories}
- Content preference: ${preferredContentType}
- User satisfaction score: ${satScore}
- Recent search interests: ${topSearches}
- Favorite vendors: ${favoriteVendors.slice(0, 2).join(", ")}
- IMPORTANT: Strongly prioritize suggestions that include the user's ` +
            `preferred ingredients and categories
- IMPORTANT: Tailor recipe complexity and style to user's ` +
            "demonstrated preferences";

          logger.log(
            "[getRecipeSnippet] Using enhanced personalization: " +
            `confidence ${personalizationConfidence.toFixed(2)}, ` +
            `${preferredKeywords.length} keywords, ` +
            `satisfaction ${satisfactionScore.toFixed(2)}`
          );
        } else {
          // Basic personalization for users with limited data
          userPreferencesContext = `

USER PREFERENCES (based on ${totalPositiveFeedback} interactions):
- Preferred ingredients: ${preferredKeywords.slice(0, 5).join(", ")}
- Preferred food categories: ${preferredCategories.slice(0, 3).join(", ")}
- Content preference: ${preferredContentType}
- When possible, incorporate these preferred elements into suggestions`;

          logger.log(
            "[getRecipeSnippet] Using basic preferences: " +
            `${preferredKeywords.length} keywords, ` +
            `${preferredCategories.length} categories`
          );
        }
      }

      // Build context-aware prompt for recipe generation
      const keywordList = (keywords || []).join(", ");
      const prompt = "You are a helpful cooking assistant for MarketSnap, " +
        "a farmers market app. Based on the following produce/product " +
        "description, determine if this is food-related and suggest a recipe " +
        `if appropriate.

Product description: "${caption}"
Detected keywords: ${keywordList}
Media type: ${mediaType || "photo"}${userPreferencesContext}

CRITICAL DECISION LOGIC:
1. First determine: Is this describing FOOD, PRODUCE, or EDIBLE ITEMS?
   - FOOD: fruits, vegetables, herbs, baked goods, dairy, meat, grains, etc.
   - NOT FOOD: crafts, soaps, candles, flowers, decorative items, tools, etc.

2. If it's NOT FOOD, return:
{
  "recipeName": null,
  "snippet": null,
  "ingredients": [],
  "category": "non_food",
  "relevanceScore": 0.0
}

3. If it IS FOOD, provide a complete recipe:
{
  "recipeName": "Recipe Title (under 35 characters)",
  "snippet": "Brief description of the recipe and why it's great " +
    "(under 120 characters)",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3", "ingredient4"],
  "category": "produce|baked_goods|dairy|herbs|etc",
  "relevanceScore": 0.85
}

FOOD CATEGORIES: produce, baked_goods, dairy, herbs, meat, grains, beverages
NON-FOOD CATEGORIES: crafts, soaps, candles, flowers, decorative, tools, " +
  "clothing"

IMPORTANT RULES:
- Only suggest recipes for actual FOOD items
- Flowers, crafts, soaps, candles = NOT FOOD = null recipe
- If unsure, err on the side of NOT FOOD
- Include ALL ingredients needed for the recipe (oil, salt, pepper, etc.)
- Keep responses concise but complete for mobile display`;

      logger.log("[getRecipeSnippet] Sending request to OpenAI GPT-4");

      // Call OpenAI API
      const completion = await openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content: "You are a helpful cooking assistant that provides " +
              "simple, practical recipes for farmers market products. " +
              "Always respond with valid JSON matching the requested format. " +
              "Make sure to include ALL ingredients and keep responses " +
              "concise but complete.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        max_tokens: 600, // Increased from 400 to ensure complete responses
        temperature: 0.7,
        top_p: 0.9,
      });

      const responseText = completion.choices[0]?.message?.content?.trim();

      if (!responseText) {
        throw new Error("OpenAI returned empty response");
      }

      logger.log(
        "[getRecipeSnippet] Raw OpenAI response " +
        `(${responseText.length} chars): ${responseText}`
      );

      // Parse the JSON response
      let recipeData;
      try {
        // Clean the response to remove markdown backticks and "json" identifier
        const cleanedResponse = responseText.replace(/```json\n|```/g, "")
          .trim();
        logger.log(
          "[getRecipeSnippet] Cleaned response for parsing: " +
          `${cleanedResponse}`
        );
        recipeData = JSON.parse(cleanedResponse);
      } catch (parseError) {
        logger.error(
          "[getRecipeSnippet] Failed to parse JSON response:",
          parseError
        );
        logger.error("[getRecipeSnippet] Raw response was:", responseText);
        throw new Error("Invalid JSON response from OpenAI");
      }

      // Validate response structure
      const response = {
        recipeName: recipeData.recipeName || null,
        snippet: recipeData.snippet || null,
        ingredients: Array.isArray(recipeData.ingredients) ?
          recipeData.ingredients : [],
        category: recipeData.category || "general",
        relevanceScore: typeof recipeData.relevanceScore === "number" ?
          recipeData.relevanceScore : 0.5,
      };

      logger.log(
        `[getRecipeSnippet] Generated recipe: "${response.recipeName}" ` +
        `(relevance: ${response.relevanceScore})`
      );

      return response;
    } catch (error) {
      logger.error("[getRecipeSnippet] Error generating recipe:", error);

      // Return appropriate error
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      const errorMessage = error instanceof Error ?
        error.message : "Unknown error";
      throw new functions.https.HttpsError(
        "internal",
        `Failed to generate recipe snippet: ${errorMessage}`
      );
    }
  }
);

/**
 * Performs a vector search for relevant FAQs using OpenAI embeddings.
 * Falls back to keyword search if embeddings are not available.
 */
export const vectorSearchFAQ = createAIHelper(
  "vectorSearchFAQ",
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  async (data, context) => {
    logger.log("[vectorSearchFAQ] Starting FAQ search");
    logger.log("[vectorSearchFAQ] Input data:", data);

    const {query, keywords, vendorId, limit = 3, userPreferences} = data;

    if (!query) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Query is required for FAQ search"
      );
    }

    try {
      // Get OpenAI API key
      const OPENAI_API_KEY =
        process.env.OPENAI_API_KEY ||
        functions.config().marketsnap?.openai?.key;
      if (!OPENAI_API_KEY) {
        logger.error("[vectorSearchFAQ] OpenAI API key not found");
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI API key is not configured"
        );
      }

      logger.log(
        `[vectorSearchFAQ] Searching for: "${query}" ` +
        `${vendorId ? `from vendor: ${vendorId}` : "across all vendors"} ` +
        "with user preferences: " +
        `${userPreferences ? JSON.stringify(userPreferences) : "none"}`
      );

      // Import OpenAI for embeddings
      // eslint-disable-next-line @typescript-eslint/no-explicit-any
      let OpenAI: any;
      try {
        OpenAI = (await import("openai")).default;
      } catch (importError) {
        logger.error(
          "[vectorSearchFAQ] OpenAI package not installed:",
          importError
        );
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI package is not installed"
        );
      }

      // Initialize OpenAI client
      const openai = new OpenAI({
        apiKey: OPENAI_API_KEY,
      });

      // Generate embedding for the query
      logger.log("[vectorSearchFAQ] Generating query embedding");
      const embeddingResponse = await openai.embeddings.create({
        model: "text-embedding-ada-002",
        input: query,
      });

      const queryEmbedding = embeddingResponse.data[0].embedding;
      logger.log(
        "[vectorSearchFAQ] Generated embedding with " +
        `${queryEmbedding.length} dimensions`
      );

      // Search FAQs in Firestore
      // For now, we'll implement a simple keyword-based fallback since
      // vector search requires additional setup (pgvector or similar)
      let faqQuery = db.collection("faqVectors").limit(limit * 2);

      // Filter by vendor if specified
      if (vendorId) {
        faqQuery = faqQuery.where("vendorId", "==", vendorId);
      }

      const faqSnapshot = await faqQuery.get();

      if (faqSnapshot.empty) {
        logger.log("[vectorSearchFAQ] No FAQs found in database");
        return {results: []};
      }

      logger.log(
        `[vectorSearchFAQ] Found ${faqSnapshot.docs.length} FAQ entries`
      );

      // Calculate similarity scores with user preference boosting
      const results = [];
      const queryWords = query.toLowerCase().split(" ");
      const keywordSet = new Set([
        ...queryWords,
        ...(keywords || []).map((k: string) => k.toLowerCase()),
      ]);

      // Extract user preferred keywords for boosting
      const preferredKeywords = userPreferences?.preferredKeywords || [];
      const preferredCategories = userPreferences?.preferredCategories || [];
      const preferredKeywordSet: Set<string> = new Set(
        preferredKeywords
          .filter((k: unknown): k is string => typeof k === "string")
          .map((k: string) => k.toLowerCase())
      );
      const preferredCategorySet: Set<string> = new Set(
        preferredCategories
          .filter((c: unknown): c is string => typeof c === "string")
          .map((c: string) => c.toLowerCase())
      );

      logger.log(
        `[vectorSearchFAQ] Using ${preferredKeywords.length} keywords ` +
        `and ${preferredCategories.length} categories for scoring boost`
      );

      for (const doc of faqSnapshot.docs) {
        const faqData = doc.data();

        // Calculate relevance score based on keyword matching
        // In a full implementation, this would use vector similarity
        let score = 0;

        const questionText = (faqData.question || "").toLowerCase();
        const answerText = (faqData.answer || "").toLowerCase();
        const chunkText = (faqData.chunkText || "").toLowerCase();
        const combinedText = `${questionText} ${answerText} ${chunkText}`;

        // Score based on exact query matches
        if (combinedText.includes(query.toLowerCase())) {
          score += 0.5;
        }

        // Score based on keyword matches
        let keywordMatches = 0;
        keywordSet.forEach((keyword) => {
          if (combinedText.includes(keyword)) {
            keywordMatches++;
          }
        });

        score += (keywordMatches / Math.max(keywordSet.size, 1)) * 0.4;

        // Category bonus for matching product types
        const category = faqData.category || "";
        const categoryKeywords = ["produce", "baked", "dairy", "herb", "craft"];
        const hasRelevantCategory = categoryKeywords.some((cat) =>
          query.toLowerCase().includes(cat) && category.includes(cat)
        );
        if (hasRelevantCategory) {
          score += 0.1;
        }

        // User preference bonuses
        let preferenceBonus = 0;

        // Boost score for preferred keywords in FAQ content
        preferredKeywordSet.forEach((preferredKeyword) => {
          if (combinedText.includes(preferredKeyword)) {
            preferenceBonus += 0.15; // Significant boost for preferred keywords
          }
        });

        // Boost score for preferred categories
        preferredCategorySet.forEach((preferredCategory) => {
          if (category.toLowerCase().includes(preferredCategory)) {
            preferenceBonus += 0.2; // Strong boost for preferred categories
          }
        });

        score += Math.min(preferenceBonus, 0.3); // Cap preference bonus at 0.3

        // Only include results with reasonable relevance
        if (score > 0.1) {
          results.push({
            question: faqData.question || "",
            answer: faqData.answer || "",
            score: Math.min(score, 1.0),
            vendorId: faqData.vendorId || "",
            category: faqData.category || "general",
            faqId: doc.id,
          });
        }
      }

      // Sort by relevance score and limit results
      results.sort((a, b) => b.score - a.score);
      const topResults = results.slice(0, limit);

      logger.log(
        `[vectorSearchFAQ] Returning ${topResults.length} results ` +
        `(scores: ${topResults.map((r) => r.score.toFixed(2)).join(", ")}) ` +
        "with preference boosting applied"
      );

      return {
        results: topResults,
        totalFound: results.length,
        // In production: "vector_similarity"
        searchMethod: "keyword_similarity",
      };
    } catch (error) {
      logger.error("[vectorSearchFAQ] Error searching FAQs:", error);

      // Return appropriate error
      if (error instanceof functions.https.HttpsError) {
        throw error;
      }

      const errorMessage = error instanceof Error ?
        error.message : "Unknown error";
      throw new functions.https.HttpsError(
        "internal",
        `Failed to search FAQs: ${errorMessage}`
      );
    }
  }
);

/**
 * Cloud Function to delete a user account and all associated data
 * Handles cascading deletion across all collections and storage
 */
export const deleteUserAccount = functions.https.onCall(
  async (data, context) => {
    logger.log("[deleteUserAccount] 🗑️ Account deletion request received");

    // Verify authentication
    if (!context.auth) {
      logger.error("[deleteUserAccount] ❌ Unauthorized request");
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated"
      );
    }

    const requestingUid = context.auth.uid;
    const targetUid = data.uid;
    const timestamp = data.timestamp;

    logger.log(
      "[deleteUserAccount] Request details: " +
      `requestingUid=${requestingUid}, targetUid=${targetUid}, ` +
      `timestamp=${timestamp}`
    );

    // Security: Users can only delete their own accounts
    if (requestingUid !== targetUid) {
      logger.error(
        `[deleteUserAccount] ❌ Unauthorized: User ${requestingUid} ` +
        `attempted to delete account ${targetUid}`
      );
      throw new functions.https.HttpsError(
        "permission-denied",
        "Users can only delete their own accounts"
      );
    }

    try {
      logger.log(
        `[deleteUserAccount] 🚀 Starting deletion for UID: ${targetUid}`
      );

      // Track deletion statistics
      const deletionStats = {
        snapsDeleted: 0,
        messagesDeleted: 0,
        followersDeleted: 0,
        followingDeleted: 0,
        ragFeedbackDeleted: 0,
        faqVectorsDeleted: 0,
        broadcastsDeleted: 0,
        storageFilesDeleted: 0,
        profileDeleted: false,
        errors: [] as string[],
      };

      // Step 1: Delete user's snaps and associated media
      logger.log("[deleteUserAccount] 🖼️ Deleting user snaps...");
      try {
        // Query for user's snaps
        const snapsQuery = await db.collection("snaps")
          .where("vendorId", "==", targetUid)
          .get();

        if (!snapsQuery.empty) {
          const batch = db.batch();

          for (const snapDoc of snapsQuery.docs) {
            const snapData = snapDoc.data();

            // Delete associated media files from Storage
            if (snapData.mediaUrl) {
              try {
                // Extract file path from URL and delete from Storage
                const mediaRef = admin.storage().bucket().file(
                  `vendors/${targetUid}/snaps/${snapDoc.id}`
                );
                await mediaRef.delete();
                deletionStats.storageFilesDeleted++;
                logger.log(
                  `[deleteUserAccount] ✅ Deleted media for snap ${snapDoc.id}`
                );
              } catch (mediaError) {
                logger.warn(
                  "[deleteUserAccount] ⚠️ Failed to delete media " +
                  `for snap ${snapDoc.id}: ${mediaError}`
                );
                deletionStats.errors.push(
                  `Media deletion failed for snap ${snapDoc.id}`
                );
              }
            }

            // Add snap document to batch delete
            batch.delete(snapDoc.ref);
          }

          await batch.commit();
          deletionStats.snapsDeleted = snapsQuery.docs.length;
          logger.log(
            "[deleteUserAccount] ✅ Deleted " +
            `${deletionStats.snapsDeleted} snaps`
          );
        } else {
          logger.log("[deleteUserAccount] ℹ️ No snaps found for user");
        }
      } catch (snapError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting snaps: ${snapError}`
        );
        deletionStats.errors.push(`Snap deletion error: ${snapError}`);
      }

      // Step 2: Delete user's messages (both sent and received)
      logger.log("[deleteUserAccount] 💬 Deleting user messages...");
      try {
        // Delete messages sent by user
        const sentMessagesQuery = await db.collection("messages")
          .where("fromUid", "==", targetUid)
          .get();

        // Delete messages received by user
        const receivedMessagesQuery = await db.collection("messages")
          .where("toUid", "==", targetUid)
          .get();

        const allMessages = [
          ...sentMessagesQuery.docs,
          ...receivedMessagesQuery.docs,
        ];

        if (allMessages.length > 0) {
          // Process in batches of 500 (Firestore batch limit)
          const batchSize = 500;
          for (let i = 0; i < allMessages.length; i += batchSize) {
            const batch = db.batch();
            const batchMessages = allMessages.slice(i, i + batchSize);

            batchMessages.forEach((doc) => batch.delete(doc.ref));
            await batch.commit();
          }

          deletionStats.messagesDeleted = allMessages.length;
          logger.log(
            "[deleteUserAccount] ✅ Deleted " +
            `${deletionStats.messagesDeleted} messages`
          );
        } else {
          logger.log("[deleteUserAccount] ℹ️ No messages found for user");
        }
      } catch (messageError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting messages: ${messageError}`
        );
        deletionStats.errors.push(`Message deletion error: ${messageError}`);
      }

      // Step 3: Delete follow relationships
      logger.log("[deleteUserAccount] 👥 Deleting follow relationships...");
      try {
        // Delete users this person is following
        const followingQuery = await db.collection("followers")
          .where("followerId", "==", targetUid)
          .get();

        // Delete followers of this user
        const followersQuery = await db.collection("followers")
          .where("followedId", "==", targetUid)
          .get();

        const allRelationships = [
          ...followingQuery.docs,
          ...followersQuery.docs,
        ];

        if (allRelationships.length > 0) {
          const batch = db.batch();
          allRelationships.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();

          deletionStats.followingDeleted = followingQuery.docs.length;
          deletionStats.followersDeleted = followersQuery.docs.length;
          logger.log(
            "[deleteUserAccount] ✅ Deleted " +
            `${deletionStats.followingDeleted} following ` +
            `and ${deletionStats.followersDeleted} follower relationships`
          );
        } else {
          logger.log("[deleteUserAccount] ℹ️ No follow relationships found");
        }
      } catch (followError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting relationships: ${followError}`
        );
        deletionStats.errors.push(
          `Follow relationship deletion error: ${followError}`
        );
      }

      // Step 4: Delete RAG feedback
      logger.log("[deleteUserAccount] 🤖 Deleting RAG feedback...");
      try {
        const ragFeedbackQuery = await db.collection("ragFeedback")
          .where("userId", "==", targetUid)
          .get();

        if (!ragFeedbackQuery.empty) {
          const batch = db.batch();
          ragFeedbackQuery.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();

          deletionStats.ragFeedbackDeleted = ragFeedbackQuery.docs.length;
          logger.log(
            "[deleteUserAccount] ✅ Deleted " +
            `${deletionStats.ragFeedbackDeleted} RAG feedback items`
          );
        } else {
          logger.log("[deleteUserAccount] ℹ️ No RAG feedback found");
        }
      } catch (ragError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting RAG feedback: ${ragError}`
        );
        deletionStats.errors.push(`RAG feedback deletion error: ${ragError}`);
      }

      // Step 5: Delete FAQ vectors (for vendors)
      logger.log("[deleteUserAccount] 📚 Deleting FAQ vectors...");
      try {
        const faqVectorsQuery = await db.collection("faqVectors")
          .where("vendorId", "==", targetUid)
          .get();

        if (!faqVectorsQuery.empty) {
          const batch = db.batch();
          faqVectorsQuery.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();

          deletionStats.faqVectorsDeleted = faqVectorsQuery.docs.length;
          logger.log(
            "[deleteUserAccount] ✅ Deleted " +
            `${deletionStats.faqVectorsDeleted} FAQ vectors`
          );
        } else {
          logger.log("[deleteUserAccount] ℹ️ No FAQ vectors found");
        }
      } catch (faqError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting FAQ vectors: ${faqError}`
        );
        deletionStats.errors.push(`FAQ vectors deletion error: ${faqError}`);
      }

      // Step 6: Delete broadcasts (for vendors)
      logger.log("[deleteUserAccount] 📢 Deleting broadcasts...");
      try {
        const broadcastsQuery = await db.collection("broadcasts")
          .where("vendorId", "==", targetUid)
          .get();

        if (!broadcastsQuery.empty) {
          const batch = db.batch();
          broadcastsQuery.docs.forEach((doc) => batch.delete(doc.ref));
          await batch.commit();

          deletionStats.broadcastsDeleted = broadcastsQuery.docs.length;
          logger.log(
            "[deleteUserAccount] ✅ Deleted " +
            `${deletionStats.broadcastsDeleted} broadcasts`
          );
        } else {
          logger.log("[deleteUserAccount] ℹ️ No broadcasts found");
        }
      } catch (broadcastError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting broadcasts: ${broadcastError}`
        );
        deletionStats.errors.push(
          `Broadcast deletion error: ${broadcastError}`
        );
      }

      // Step 7: Delete user profiles (vendor and regular user)
      logger.log("[deleteUserAccount] 👤 Deleting user profiles...");
      try {
        // Try to delete vendor profile
        const vendorDoc = db.collection("vendors").doc(targetUid);
        const vendorSnapshot = await vendorDoc.get();

        if (vendorSnapshot.exists) {
          await vendorDoc.delete();
          logger.log("[deleteUserAccount] ✅ Vendor profile deleted");
          deletionStats.profileDeleted = true;
        }

        // Try to delete regular user profile
        const regularUserDoc = db.collection("regularUsers").doc(targetUid);
        const regularUserSnapshot = await regularUserDoc.get();

        if (regularUserSnapshot.exists) {
          await regularUserDoc.delete();
          logger.log("[deleteUserAccount] ✅ Regular user profile deleted");
          deletionStats.profileDeleted = true;
        }

        if (!deletionStats.profileDeleted) {
          logger.log("[deleteUserAccount] ℹ️ No user profile found to delete");
        }
      } catch (profileError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting profiles: ${profileError}`
        );
        deletionStats.errors.push(`Profile deletion error: ${profileError}`);
      }

      // Step 8: Delete entire user storage folder
      logger.log("[deleteUserAccount] 📁 Deleting user storage folder...");
      try {
        const bucket = admin.storage().bucket();

        // Delete vendor folder
        try {
          const [vendorFiles] = await bucket.getFiles({
            prefix: `vendors/${targetUid}/`,
          });

          if (vendorFiles.length > 0) {
            await Promise.all(vendorFiles.map((file) => file.delete()));
            deletionStats.storageFilesDeleted += vendorFiles.length;
            logger.log(
              `[deleteUserAccount] ✅ Deleted ${vendorFiles.length} ` +
              "files from vendor folder"
            );
          }
        } catch (vendorStorageError) {
          logger.warn(
            "[deleteUserAccount] ⚠️ Vendor storage deletion error: " +
            `${vendorStorageError}`
          );
        }

        // Delete regular user folder
        try {
          const [regularUserFiles] = await bucket.getFiles({
            prefix: `regularUsers/${targetUid}/`,
          });

          if (regularUserFiles.length > 0) {
            await Promise.all(regularUserFiles.map((file) => file.delete()));
            deletionStats.storageFilesDeleted += regularUserFiles.length;
            logger.log(
              `[deleteUserAccount] ✅ Deleted ${regularUserFiles.length} ` +
              "files from regular user folder"
            );
          }
        } catch (regularStorageError) {
          logger.warn(
            "[deleteUserAccount] ⚠️ Regular user storage deletion error: " +
            `${regularStorageError}`
          );
        }
      } catch (storageError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting storage: ${storageError}`
        );
        deletionStats.errors.push(`Storage deletion error: ${storageError}`);
      }

      // Final step: Delete Firebase Auth user
      logger.log("[deleteUserAccount] 🔐 Deleting Firebase Auth user...");
      try {
        await admin.auth().deleteUser(targetUid);
        logger.log("[deleteUserAccount] ✅ Firebase Auth user deleted");
      } catch (authError) {
        logger.error(
          `[deleteUserAccount] ❌ Error deleting auth user: ${authError}`
        );
        deletionStats.errors.push(`Auth deletion error: ${authError}`);
        // Critical - if auth deletion fails, account isn't fully deleted
      }

      // Log final results
      logger.log(
        `[deleteUserAccount] 🎉 Account deletion completed for ${targetUid}:\n` +
        `- Snaps deleted: ${deletionStats.snapsDeleted}\n` +
        `- Messages deleted: ${deletionStats.messagesDeleted}\n` +
        `- Following deleted: ${deletionStats.followingDeleted}\n` +
        `- Followers deleted: ${deletionStats.followersDeleted}\n` +
        `- RAG feedback deleted: ${deletionStats.ragFeedbackDeleted}\n` +
        `- FAQ vectors deleted: ${deletionStats.faqVectorsDeleted}\n` +
        `- Broadcasts deleted: ${deletionStats.broadcastsDeleted}\n` +
        `- Storage files deleted: ${deletionStats.storageFilesDeleted}\n` +
        `- Profile deleted: ${deletionStats.profileDeleted}\n` +
        `- Errors: ${deletionStats.errors.length}`
      );

      if (deletionStats.errors.length > 0) {
        logger.warn(
          "[deleteUserAccount] ⚠️ Deletion completed with errors: " +
            `${JSON.stringify(deletionStats.errors)}`
        );
      }

      return {
        success: true,
        message: "Account successfully deleted",
        stats: deletionStats,
        timestamp: admin.firestore.Timestamp.now(),
      };
    } catch (error) {
      logger.error(
        `[deleteUserAccount] ❌ Critical error during deletion: ${error}`
      );

      const errorMessage = error instanceof Error ?
        error.message : "Unknown error";

      return {
        success: false,
        error: `Account deletion failed: ${errorMessage}`,
        timestamp: admin.firestore.Timestamp.now(),
      };
    }
  }
);

/**
 * Batch vectorization function for FAQs
 * Generates embeddings for FAQs that don't have them yet
 */
export const batchVectorizeFAQs = createAIHelper(
  "batchVectorizeFAQs",
  async (data: any, context: CallableContext) => {
    logger.log("[batchVectorizeFAQs] Starting batch vectorization");
    logger.log("[batchVectorizeFAQs] Input data:", data);

    const {vendorId, limit = 50} = data;

    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to vectorize FAQs."
      );
    }

    // Check for OpenAI API key
    const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
    const openaiKey = isEmulator ?
      process.env.OPENAI_API_KEY :
      functions.config().openai?.api_key;

    if (!openaiKey) {
      logger.error("[batchVectorizeFAQs] OpenAI API key not found");
      throw new functions.https.HttpsError(
        "failed-precondition",
        "OpenAI API key not configured"
      );
    }

    logger.log(
      `[batchVectorizeFAQs] Found OpenAI Key: ${openaiKey.substring(0, 10)}...`
    );

    try {
      // Import OpenAI
      let OpenAI;
      try {
        OpenAI = (await import("openai")).default;
      } catch (importError) {
        logger.error(
          "[batchVectorizeFAQs] OpenAI package not installed:",
          importError
        );
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI package not available"
        );
      }

      const openai = new OpenAI({apiKey: openaiKey});

      // Query for FAQs without embeddings
      let query = db.collection("faqVectors")
        .where("embedding", "==", null)
        .limit(limit);

      if (vendorId) {
        query = query.where("vendorId", "==", vendorId);
        logger.log(
          `[batchVectorizeFAQs] Processing FAQs for vendor: ${vendorId}`
        );
      } else {
        logger.log("[batchVectorizeFAQs] Processing FAQs for all vendors");
      }

      const faqVectorSnapshot = await query.get();

      if (faqVectorSnapshot.empty) {
        logger.log("[batchVectorizeFAQs] No FAQs need vectorization");
        return {
          success: true,
          processed: 0,
          message: "No FAQs need vectorization",
          timestamp: admin.firestore.Timestamp.now(),
        };
      }

      logger.log(
        `[batchVectorizeFAQs] Found ${faqVectorSnapshot.docs.length} ` +
        "FAQs to vectorize"
      );

      const results = {
        processed: 0,
        errors: [] as string[],
        success: true,
      };

      // Process each FAQ
      for (const faqDoc of faqVectorSnapshot.docs) {
        const faqData = faqDoc.data();
        const faqId = faqDoc.id;

        try {
          logger.log(`[batchVectorizeFAQs] Processing FAQ ${faqId}`);

          // Create text for embedding (combine question and answer)
          const embeddingText = `${faqData.question} ${faqData.answer}`;

          // Generate embedding
          const embeddingResponse = await openai.embeddings.create({
            model: "text-embedding-3-small",
            input: embeddingText,
          });

          const embedding = embeddingResponse.data[0].embedding;

          logger.log(
            `[batchVectorizeFAQs] Generated embedding for FAQ ${faqId} ` +
            `with ${embedding.length} dimensions`
          );

          // Update the faqVector document with the embedding
          await db.collection("faqVectors").doc(faqId).update({
            embedding: embedding,
            updatedAt: admin.firestore.Timestamp.now(),
          });

          results.processed++;
          logger.log(
            `[batchVectorizeFAQs] ✅ Updated FAQ ${faqId} with embedding`
          );
        } catch (faqError) {
          const errorMessage = faqError instanceof Error ?
            faqError.message : "Unknown error";
          logger.error(
            `[batchVectorizeFAQs] ❌ Error processing FAQ ${faqId}: ` +
            errorMessage
          );
          results.errors.push(`FAQ ${faqId}: ${errorMessage}`);
          results.success = false;
        }
      }

      logger.log(
        `[batchVectorizeFAQs] Batch vectorization completed. ` +
        `Processed: ${results.processed}, Errors: ${results.errors.length}`
      );

      return {
        success: results.success,
        processed: results.processed,
        errors: results.errors,
        message: results.success ?
          `Successfully vectorized ${results.processed} FAQs` :
          `Vectorized ${results.processed} FAQs with ${results.errors.length} errors`,
        timestamp: admin.firestore.Timestamp.now(),
      };
    } catch (error) {
      logger.error("[batchVectorizeFAQs] Error in batch vectorization:", error);

      const errorMessage = error instanceof Error ?
        error.message : "Unknown error";

      throw new functions.https.HttpsError(
        "internal",
        `Batch vectorization failed: ${errorMessage}`
      );
    }
  }
);

/**
 * Firestore trigger to automatically vectorize FAQs when created
 */
export const autoVectorizeFAQ = onDocumentCreated(
  "faqs/{faqId}",
  async (event) => {
    const faqId = event.params.faqId;
    const faqData = event.data?.data();

    if (!faqData) {
      logger.error("[autoVectorizeFAQ] No FAQ data in document");
      return;
    }

    logger.log(`[autoVectorizeFAQ] Auto-vectorizing new FAQ: ${faqId}`);

    try {
      // Check for OpenAI API key
      const isEmulator = process.env.FUNCTIONS_EMULATOR === "true";
      const openaiKey = isEmulator ?
        process.env.OPENAI_API_KEY :
        functions.config().openai?.api_key;

      if (!openaiKey) {
        logger.error("[autoVectorizeFAQ] OpenAI API key not found");
        return;
      }

      // Import OpenAI
      let OpenAI;
      try {
        OpenAI = (await import("openai")).default;
      } catch (importError) {
        logger.error(
          "[autoVectorizeFAQ] OpenAI package not installed:",
          importError
        );
        return;
      }

      const openai = new OpenAI({apiKey: openaiKey});

      // Create text for embedding
      const embeddingText = `${faqData.question} ${faqData.answer}`;

      // Generate embedding
      const embeddingResponse = await openai.embeddings.create({
        model: "text-embedding-3-small",
        input: embeddingText,
      });

      const embedding = embeddingResponse.data[0].embedding;

      logger.log(
        `[autoVectorizeFAQ] Generated embedding with ${embedding.length} ` +
        "dimensions"
      );

      // Check if faqVector already exists
      const faqVectorRef = db.collection("faqVectors").doc(faqId);
      const faqVectorDoc = await faqVectorRef.get();

      if (faqVectorDoc.exists) {
        // Update existing faqVector with embedding
        await faqVectorRef.update({
          embedding: embedding,
          updatedAt: admin.firestore.Timestamp.now(),
        });
        logger.log(`[autoVectorizeFAQ] ✅ Updated existing faqVector ${faqId}`);
      } else {
        // Create new faqVector with embedding
        await faqVectorRef.set({
          faqId: faqId,
          vendorId: faqData.vendorId,
          question: faqData.question,
          answer: faqData.answer,
          category: faqData.category,
          keywords: faqData.keywords || [],
          embedding: embedding,
          createdAt: admin.firestore.Timestamp.now(),
          updatedAt: admin.firestore.Timestamp.now(),
        });
        logger.log(`[autoVectorizeFAQ] ✅ Created new faqVector ${faqId}`);
      }
    } catch (error) {
      logger.error(
        `[autoVectorizeFAQ] Error auto-vectorizing FAQ ${faqId}:`,
        error
      );
    }
  }
);
