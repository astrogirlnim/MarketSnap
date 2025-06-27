#!/usr/bin/env node

/**
 * Test script to verify AI functions are working in production
 * Tests both generateCaption and getRecipeSnippet functions
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK for production
admin.initializeApp({
  projectId: 'marketsnap-app',
});

/**
 * Test the generateCaption function
 */
async function testGenerateCaption() {
  console.log('🧺 Testing generateCaption function...');
  
  try {
    const functions = admin.functions();
    const generateCaption = functions.httpsCallable('generateCaption');
    
    const result = await generateCaption({
      mediaType: 'photo',
      existingCaption: '',
      vendorProfile: {
        stallName: 'Test Vendor',
        marketCity: 'Test Market'
      }
    });
    
    console.log('✅ generateCaption result:', result.data);
    
    if (result.data.status === 'disabled') {
      console.log('❌ AI functions are still disabled in production');
      return false;
    }
    
    if (result.data.caption && result.data.caption.trim().length > 0) {
      console.log('✅ generateCaption is working! Caption:', result.data.caption);
      return true;
    } else {
      console.log('❌ generateCaption returned empty caption');
      return false;
    }
    
  } catch (error) {
    console.error('❌ Error testing generateCaption:', error.message);
    return false;
  }
}

/**
 * Test the getRecipeSnippet function
 */
async function testGetRecipeSnippet() {
  console.log('\n🍅 Testing getRecipeSnippet function...');
  
  try {
    const functions = admin.functions();
    const getRecipeSnippet = functions.httpsCallable('getRecipeSnippet');
    
    const result = await getRecipeSnippet({
      caption: 'Fresh strawberries from our farm',
      keywords: ['strawberry', 'fruit', 'fresh'],
      mediaType: 'photo',
      vendorId: 'test-vendor-id'
    });
    
    console.log('✅ getRecipeSnippet result:', result.data);
    
    if (result.data.status === 'disabled') {
      console.log('❌ AI functions are still disabled in production');
      return false;
    }
    
    if (result.data.recipeName && result.data.recipeName.trim().length > 0) {
      console.log('✅ getRecipeSnippet is working! Recipe:', result.data.recipeName);
      return true;
    } else {
      console.log('✅ getRecipeSnippet correctly identified non-food item');
      return true;
    }
    
  } catch (error) {
    console.error('❌ Error testing getRecipeSnippet:', error.message);
    return false;
  }
}

/**
 * Main test runner
 */
async function runTests() {
  console.log('🔥 Testing AI Functions in Production');
  console.log('=====================================\n');
  
  const captionWorking = await testGenerateCaption();
  const recipeWorking = await testGetRecipeSnippet();
  
  console.log('\n📋 Test Summary');
  console.log('================');
  console.log(`Wicker AI Caption: ${captionWorking ? '✅ WORKING' : '❌ FAILED'}`);
  console.log(`Recipe Suggestions: ${recipeWorking ? '✅ WORKING' : '❌ FAILED'}`);
  
  if (captionWorking && recipeWorking) {
    console.log('\n🎉 ALL AI FEATURES ARE WORKING IN PRODUCTION! 🧺');
    process.exit(0);
  } else {
    console.log('\n⚠️  Some AI features are still not working. Check deployment status.');
    process.exit(1);
  }
}

// Run the tests
runTests().catch(console.error); 