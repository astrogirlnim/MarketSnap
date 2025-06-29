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
    // ✅ FIXED: Using consistent static images instead of random picsum URLs
    // These URLs will show the SAME image on all devices
    const CONSISTENT_IMAGES = {
      avatar1: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=50&h=50&fit=crop&crop=face',
      avatar2: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=50&h=50&fit=crop&crop=face', 
      avatar3: 'https://images.unsplash.com/photo-1494790108755-2616b612b790?w=50&h=50&fit=crop&crop=face',
      // Specific food images that are consistent
      strawberries: 'https://images.unsplash.com/photo-1464965911861-746a04b4bca6?w=400&h=300&fit=crop',
      tomatoes: 'https://images.unsplash.com/photo-1560472354-b33ff0c44a43?w=400&h=300&fit=crop',
      bread: 'https://images.unsplash.com/photo-1549931319-a545dcf3bc73?w=400&h=300&fit=crop',
      greens: 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=400&h=300&fit=crop',
      candles: 'https://images.unsplash.com/photo-1536431311719-398b6704d4cc?w=400&h=300&fit=crop'
    };

    // Test snaps data
    const testSnaps = [
      {
        id: 'test-strawberries-1',
        vendorId: 'vendor-berry-patch',
        vendorName: 'Berry Patch',
        vendorAvatarUrl: CONSISTENT_IMAGES.avatar1,
        mediaUrl: CONSISTENT_IMAGES.strawberries,
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
        vendorAvatarUrl: CONSISTENT_IMAGES.avatar2,
        mediaUrl: CONSISTENT_IMAGES.tomatoes,
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
        vendorAvatarUrl: CONSISTENT_IMAGES.avatar3,
        mediaUrl: CONSISTENT_IMAGES.bread,
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
        vendorAvatarUrl: CONSISTENT_IMAGES.avatar1,
        mediaUrl: CONSISTENT_IMAGES.greens,
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
        vendorAvatarUrl: CONSISTENT_IMAGES.avatar2,
        mediaUrl: CONSISTENT_IMAGES.candles,
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