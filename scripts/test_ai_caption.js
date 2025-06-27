#!/usr/bin/env node

/**
 * Test script for AI Caption Generation with Wicker
 * 
 * This script tests the generateCaption Cloud Function with real OpenAI API
 * to ensure the Wicker AI mascot caption generation is working properly.
 */

const admin = require('firebase-admin');
const functions = require('firebase-functions-test');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
try {
  admin.initializeApp({
    projectId: 'marketsnap-app',
  });
  console.log('✅ Firebase Admin SDK initialized');
} catch (error) {
  console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
  process.exit(1);
}

// Initialize Functions Test SDK
const testEnv = functions();

// Import the function
const { generateCaption } = require('../functions/lib/index');

/**
 * Convert image to base64 for testing
 */
function imageToBase64(imagePath) {
  try {
    if (!fs.existsSync(imagePath)) {
      console.log(`⚠️  Image not found: ${imagePath}`);
      return null;
    }
    
    const imageBuffer = fs.readFileSync(imagePath);
    const base64Image = imageBuffer.toString('base64');
    console.log(`📷 Encoded image: ${imagePath} (${base64Image.length} characters)`);
    return base64Image;
  } catch (error) {
    console.error(`❌ Error encoding image: ${error.message}`);
    return null;
  }
}

/**
 * Test data for different scenarios  
 */
const testScenarios = [
  {
    name: 'Text-only caption (no image)',
    data: {
      mediaType: 'photo',
      existingCaption: '',
      vendorProfile: {
        stallName: 'Green Valley Farm',
        marketCity: 'Portland'
      }
    }
  },
  {
    name: 'Caption improvement (existing text)',
    data: {
      mediaType: 'photo', 
      existingCaption: 'Fresh tomatoes for sale',
      vendorProfile: {
        stallName: 'Sunny Acres',
        marketCity: 'San Francisco'
      }
    }
  },
  {
    name: 'Video caption generation',
    data: {
      mediaType: 'video',
      existingCaption: '',
      vendorProfile: {
        stallName: 'Farm Fresh Co',
        marketCity: 'Austin'
      }
    }
  }
];

/**
 * Test with image if available
 */
function addImageTest() {
  // Look for test images in common locations
  const testImagePaths = [
    'assets/images/icon.png',
    'assets/images/icons/basket_icon.png',
    'documentation/frontend_redesign_refs/icon.png'
  ];
  
  for (const imagePath of testImagePaths) {
    const fullPath = path.resolve(imagePath);
    const imageBase64 = imageToBase64(fullPath);
    
    if (imageBase64) {
      testScenarios.push({
        name: `Image analysis with GPT-4 Vision (${path.basename(imagePath)})`,
        data: {
          mediaType: 'photo',
          existingCaption: '',
          vendorProfile: {
            stallName: 'Visual Test Farm',
            marketCity: 'Denver'
          },
          imageBase64: imageBase64
        }
      });
      break; // Only add one image test
    }
  }
}

/**
 * Run a single test scenario
 */
async function runTest(scenario) {
  console.log(`\n🧪 Testing: ${scenario.name}`);
  console.log(`📝 Data:`, JSON.stringify({
    ...scenario.data,
    imageBase64: scenario.data.imageBase64 ? `[${scenario.data.imageBase64.length} chars]` : undefined
  }, null, 2));
  
  try {
    const startTime = Date.now();
    
    // Call the function with test data
    const result = await generateCaption(scenario.data, {
      auth: { uid: 'test-user-123' }
    });
    
    const endTime = Date.now();
    const duration = endTime - startTime;
    
    console.log(`✅ Success! (${duration}ms)`);
    console.log(`🧺 Wicker says: "${result.caption}"`);
    console.log(`📊 Confidence: ${(result.confidence * 100).toFixed(1)}%`);
    console.log(`🤖 Model: ${result.model}`);
    console.log(`⏰ Timestamp: ${result.timestamp}`);
    
    // Validate response structure
    if (!result.caption || typeof result.caption !== 'string') {
      throw new Error('Invalid caption in response');
    }
    if (typeof result.confidence !== 'number' || result.confidence < 0 || result.confidence > 1) {
      throw new Error('Invalid confidence score');
    }
    
    return { success: true, duration, result };
    
  } catch (error) {
    console.error(`❌ Test failed: ${error.message}`);
    console.error(`🔍 Stack trace:`, error.stack);
    return { success: false, error: error.message };
  }
}

/**
 * Main test runner
 */
async function runAllTests() {
  console.log('🧺 Starting Wicker AI Caption Tests');
  console.log('====================================');
  
  // Check if OpenAI API key is available
  const hasOpenAIKey = process.env.OPENAI_API_KEY || process.env.AI_FUNCTIONS_ENABLED;
  if (!hasOpenAIKey) {
    console.log('⚠️  OpenAI API key not found in environment');
    console.log('🔧 Make sure OPENAI_API_KEY is set in your Cloud Functions environment');
  }
  
  // Add image test if available
  addImageTest();
  
  const results = [];
  let successCount = 0;
  
  for (const scenario of testScenarios) {
    const result = await runTest(scenario);
    results.push({ scenario: scenario.name, ...result });
    
    if (result.success) {
      successCount++;
    }
    
    // Add delay between tests to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
  
  // Summary
  console.log('\n📋 Test Summary');
  console.log('================');
  console.log(`✅ Passed: ${successCount}/${testScenarios.length}`);
  console.log(`❌ Failed: ${testScenarios.length - successCount}/${testScenarios.length}`);
  
  if (successCount === testScenarios.length) {
    console.log('🎉 All tests passed! Wicker is ready to help vendors! 🧺');
  } else {
    console.log('⚠️  Some tests failed. Check the logs above for details.');
  }
  
  // Detailed results
  console.log('\n📊 Detailed Results:');
  results.forEach((result, index) => {
    const status = result.success ? '✅' : '❌';
    const duration = result.duration ? `(${result.duration}ms)` : '';
    console.log(`  ${status} ${result.scenario} ${duration}`);
    if (!result.success) {
      console.log(`     Error: ${result.error}`);
    }
  });
  
  // Cleanup
  testEnv.cleanup();
  process.exit(successCount === testScenarios.length ? 0 : 1);
}

// Handle uncaught errors
process.on('unhandledRejection', (error) => {
  console.error('❌ Unhandled promise rejection:', error);
  testEnv.cleanup();
  process.exit(1);
});

process.on('uncaughtException', (error) => {
  console.error('❌ Uncaught exception:', error);
  testEnv.cleanup();
  process.exit(1);
});

// Run the tests
runAllTests().catch((error) => {
  console.error('❌ Test runner failed:', error);
  testEnv.cleanup();
  process.exit(1);
}); 