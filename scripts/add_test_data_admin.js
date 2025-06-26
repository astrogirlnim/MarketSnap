#!/usr/bin/env node

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK for emulator
admin.initializeApp({
  projectId: 'marketsnap-app',
});

// Connect to Firestore emulator
const db = admin.firestore();
db.settings({
  host: '127.0.0.1:8080',
  ssl: false,
});

// Simple colored placeholder data URLs (small 1x1 pixel images)
const PLACEHOLDER_IMAGES = {
  green: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  orange: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8/5+hHgAHggJ/PchI7wAAAABJRU5ErkJggg==',
  yellow: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAGA4jR9awAAAABJRU5ErkJggg==',
  tomato: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  lettuce: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  bread: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChAGA4jR9awAAAABJRU5ErkJggg=='
};

async function addTestData() {
  console.log('🧪 Adding test data to MarketSnap Firestore emulator using Admin SDK...');
  console.log('📸 Using local data URL images to avoid network timeouts');
  
  try {
    // Sample snaps data with local data URLs
    const testSnaps = [
      {
        vendorId: 'A41wmeGZ7hv8WB9LKGSSm3cbTDWt',
        vendorName: 'Test',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.green,
        mediaUrl: PLACEHOLDER_IMAGES.tomato,
        mediaType: 'photo',
        caption: 'Fresh organic tomatoes just picked! 🍅',
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000))
      },
      {
        vendorId: 'A41wmeGZ7hv8WB9LKGSSm3cbTDWt',
        vendorName: 'Test',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.green,
        mediaUrl: PLACEHOLDER_IMAGES.lettuce,
        mediaType: 'photo',
        caption: 'Crispy lettuce ready for your salad! 🥬',
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000))
      },
      {
        vendorId: 'gdAtsPSKZhdH3HHoufDe8UN7Eawr',
        vendorName: 'Sunrise Bakery',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.orange,
        mediaUrl: PLACEHOLDER_IMAGES.bread,
        mediaType: 'photo',
        caption: 'Warm sourdough just out of the oven! 🍞',
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000))
      },
      {
        vendorId: 'A41wmeGZ7hv8WB9LKGSSm3cbTDWt',
        vendorName: 'Test',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.green,
        mediaUrl: PLACEHOLDER_IMAGES.yellow,
        mediaType: 'photo',
        caption: 'Golden corn fresh from the field! 🌽',
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000))
      }
    ];

    console.log('📱 Adding sample snaps with local images...');
    
    // First, clear existing test data
    console.log('🧹 Clearing existing test data...');
    const existingSnaps = await db.collection('snaps').get();
    const deleteBatch = db.batch();
    existingSnaps.docs.forEach(doc => {
      deleteBatch.delete(doc.ref);
    });
    if (existingSnaps.size > 0) {
      await deleteBatch.commit();
      console.log(`   ✅ Deleted ${existingSnaps.size} existing snaps`);
    }
    
    // Add new test data
    const batch = db.batch();
    
    testSnaps.forEach((snap, index) => {
      const docRef = db.collection('snaps').doc();
      batch.set(docRef, snap);
      console.log(`  ✅ Queued snap ${index + 1}: ${snap.vendorName} - ${snap.caption}`);
    });

    await batch.commit();
    console.log('🎉 All test data added successfully with local images!');
    
    // Verify data was added
    const snapshot = await db.collection('snaps').get();
    console.log(`📊 Total snaps in collection: ${snapshot.size}`);
    
    console.log('\n🔍 To view the data:');
    console.log('   • Open Firestore UI: http://127.0.0.1:4000/firestore');
    console.log('   • Check \'snaps\' collection');
    console.log('\n📱 To test in your app:');
    console.log('   • Navigate to the Feed tab');
    console.log('   • Pull down to refresh');
    console.log('   • Images should load instantly (no network requests)');
    
  } catch (error) {
    console.error('❌ Error adding test data:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

addTestData(); 