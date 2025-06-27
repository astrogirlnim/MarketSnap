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

async function addTestData() {
  console.log('🧪 Adding test data to MarketSnap Firestore emulator using Admin SDK...');
  
  try {
    // Better placeholder images using picsum.photos (reliable service)
    const PLACEHOLDER_IMAGES = {
      avatar1: 'https://picsum.photos/50/50?random=1',
      avatar2: 'https://picsum.photos/50/50?random=2', 
      avatar3: 'https://picsum.photos/50/50?random=3',
      media1: 'https://picsum.photos/400/300?random=10',
      media2: 'https://picsum.photos/400/300?random=11',
      media3: 'https://picsum.photos/400/300?random=12'
    };

    // Test snaps data
    const testSnaps = [
      {
        id: 'test-strawberries-1',
        vendorId: 'vendor-berry-patch',
        vendorName: 'Berry Patch',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.avatar1,
        mediaUrl: 'https://picsum.photos/400/300?random=101',
        mediaType: 'photo',
        caption: 'Just picked these sweet, juicy strawberries! Perfect for pies, jams, or just eating fresh.\n🍓 #fresh #berries #farmstand',
        filterType: null,
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)), // 24 hours from now
      },
      {
        id: 'test-tomatoes-2', 
        vendorId: 'vendor-test-user',
        vendorName: 'Test',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.avatar2,
        mediaUrl: 'https://picsum.photos/400/300?random=102',
        mediaType: 'photo',
        caption: 'Fresh organic tomatoes just picked this morning! 🍅',
        filterType: null,
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      },
      {
        id: 'test-sourdough-3',
        vendorId: 'vendor-sunrise-bakery',
        vendorName: 'Sunrise Bakery',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.avatar3,
        mediaUrl: 'https://picsum.photos/400/300?random=103',
        mediaType: 'photo', 
        caption: 'Warm sourdough just out of the oven! 🍞',
        filterType: null,
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      },
      {
        id: 'test-leafy-greens-4',
        vendorId: 'vendor-green-garden',
        vendorName: 'Green Garden',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.avatar1,
        mediaUrl: 'https://picsum.photos/400/300?random=104',
        mediaType: 'photo',
        caption: 'Beautiful leafy greens ready for your salad! 🥬',
        filterType: null,
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      },
      {
        id: 'test-craft-candle-5',
        vendorId: 'vendor-craft-corner',
        vendorName: 'Craft Corner',
        vendorAvatarUrl: PLACEHOLDER_IMAGES.avatar2,
        mediaUrl: 'https://picsum.photos/400/300?random=105',
        mediaType: 'photo',
        caption: 'Handmade lavender scented candles - perfect for relaxation! 🕯️ Made with natural soy wax and essential oils.',
        filterType: null,
        createdAt: admin.firestore.Timestamp.now(),
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      },
    ];

    console.log('📝 Adding sample snaps to Firestore...');
    
    // Clear existing snaps first
    const existingSnaps = await db.collection('snaps').get();
    const batch = db.batch();
    
    existingSnaps.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    if (existingSnaps.docs.length > 0) {
      await batch.commit();
      console.log(`🗑️  Cleared ${existingSnaps.docs.length} existing snaps`);
    }

    // Add new test snaps
    for (let i = 0; i < testSnaps.length; i++) {
      const snap = testSnaps[i];
      const docRef = db.collection('snaps').doc();
      await docRef.set(snap);
      console.log(`✅ Added snap ${i + 1}: "${snap.caption}" by ${snap.vendorName}`);
    }

    console.log('🎉 Test data added successfully!');
    console.log('📱 You can now view the snaps in your MarketSnap app feed');
    console.log('🌐 Or check the Firestore emulator at http://127.0.0.1:4000/firestore');

  } catch (error) {
    console.error('❌ Error adding test data:', error);
    process.exit(1);
  }
}

addTestData(); 