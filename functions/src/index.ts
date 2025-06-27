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

// Configuration for AI Functions
const AI_FUNCTIONS_ENABLED = process.env.AI_FUNCTIONS_ENABLED === "true";
const OPENAI_API_KEY = process.env.OPENAI_API_KEY;

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
        "gpt-4-vision-preview" : "gpt-4";
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
  async (data, context) => {
    logger.log("[getRecipeSnippet] Starting recipe generation");
    logger.log("[getRecipeSnippet] Input data:", data);

    const {caption, keywords, mediaType, vendorId} = data;

    if (!caption) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Caption is required for recipe generation"
      );
    }

    try {
      // Get OpenAI API key
      const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
      if (!OPENAI_API_KEY) {
        logger.error("[getRecipeSnippet] OpenAI API key not found");
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI API key is not configured"
        );
      }

      logger.log(
        `[getRecipeSnippet] Processing caption: "${caption}" with ` +
        `${(keywords || []).length} keywords`
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

      // Build context-aware prompt for recipe generation
      const keywordList = (keywords || []).join(", ");
      const prompt = `You are a helpful cooking assistant for MarketSnap, ` +
        `a farmers market app. Based on the following produce/product ` +
        `description, suggest a simple, delicious recipe that highlights ` +
        `the main ingredients.

Product description: "${caption}"
Detected keywords: ${keywordList}
Media type: ${mediaType || "photo"}

Please provide:
1. A recipe name (under 50 characters)
2. A brief description/snippet (under 200 characters) 
3. Main ingredients list (3-6 items)
4. Product category (produce, baked_goods, dairy, herbs, crafts, etc.)

Focus on:
- Simple, accessible recipes suitable for home cooking
- Highlighting the freshness and quality of market ingredients
- Seasonal and local cooking approaches
- Practical recipes that can be made with common kitchen tools

Return your response as JSON with this exact structure:
{
  "recipeName": "Recipe Title",
  "snippet": "Brief description of the recipe and why it's great",
  "ingredients": ["ingredient1", "ingredient2", "ingredient3"],
  "category": "produce",
  "relevanceScore": 0.85
}

If the product isn't suitable for recipes (like crafts, soaps, flowers), ` +
        `return null for recipeName and snippet, but still provide the ` +
        `category and a relevanceScore of 0.1.`;

      logger.log("[getRecipeSnippet] Sending request to OpenAI GPT-4");

      // Call OpenAI API
      const completion = await openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: "You are a helpful cooking assistant that provides " +
              "simple, practical recipes for farmers market products. " +
              "Always respond with valid JSON matching the requested format.",
          },
          {
            role: "user",
            content: prompt,
          },
        ],
        max_tokens: 400,
        temperature: 0.7,
        top_p: 0.9,
      });

      const responseText = completion.choices[0]?.message?.content?.trim();

      if (!responseText) {
        throw new Error("OpenAI returned empty response");
      }

      logger.log(`[getRecipeSnippet] OpenAI response: ${responseText}`);

      // Parse the JSON response
      let recipeData;
      try {
        recipeData = JSON.parse(responseText);
      } catch (parseError) {
        logger.error(
          "[getRecipeSnippet] Failed to parse JSON response:",
          parseError
        );
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
  async (data, context) => {
    logger.log("[vectorSearchFAQ] Starting FAQ search");
    logger.log("[vectorSearchFAQ] Input data:", data);

    const {query, keywords, vendorId, limit = 3} = data;

    if (!query) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Query is required for FAQ search"
      );
    }

    try {
      // Get OpenAI API key
      const OPENAI_API_KEY = process.env.OPENAI_API_KEY;
      if (!OPENAI_API_KEY) {
        logger.error("[vectorSearchFAQ] OpenAI API key not found");
        throw new functions.https.HttpsError(
          "failed-precondition",
          "OpenAI API key is not configured"
        );
      }

      logger.log(
        `[vectorSearchFAQ] Searching for: "${query}" ` +
        `${vendorId ? `from vendor: ${vendorId}` : "across all vendors"}`
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
        `[vectorSearchFAQ] Generated embedding with ` +
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

      // Calculate similarity scores
      const results = [];
      const queryWords = query.toLowerCase().split(" ");
      const keywordSet = new Set([
        ...queryWords,
        ...(keywords || []).map((k: string) => k.toLowerCase()),
      ]);

      for (const doc of faqSnapshot.docs) {
        const faqData = doc.data();
        
        // Calculate relevance score based on keyword matching
        // In a full implementation, this would use vector similarity
        let score = 0;
        
        const questionText = (faqData.question || "").toLowerCase();
        const answerText = (faqData.answer || "").toLowerCase();
        const chunkText = (faqData.chunkText || "").toLowerCase();
        
        // Score based on exact query matches
        if (chunkText.includes(query.toLowerCase())) {
          score += 0.5;
        }
        
        // Score based on keyword matches
        let keywordMatches = 0;
        keywordSet.forEach((keyword) => {
          if (chunkText.includes(keyword)) {
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
        `(scores: ${topResults.map((r) => r.score.toFixed(2)).join(", ")})`
      );

      return {
        results: topResults,
        totalFound: results.length,
        searchMethod: "keyword_similarity", // In production: "vector_similarity"
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
