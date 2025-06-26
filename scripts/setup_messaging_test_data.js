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

async function setupMessagingTestData() {
  console.log('💬 Setting up messaging test data for MarketSnap...');
  
  try {
    // Test vendor profiles for messaging
    const testVendors = [
      {
        uid: 'vendor-alice-farm',
        displayName: 'Alice\'s Farm Stand',
        stallName: 'Alice\'s Farm Stand',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://picsum.photos/100/100?random=101',
        bio: 'Organic vegetables and herbs grown with love! 🌱',
        isComplete: true,
        fcmToken: 'fake-fcm-token-alice'
      },
      {
        uid: 'vendor-bob-bakery',
        displayName: 'Bob\'s Artisan Bakery',
        stallName: 'Bob\'s Artisan Bakery', 
        marketCity: 'Portland, OR',
        avatarUrl: 'https://picsum.photos/100/100?random=102',
        bio: 'Fresh bread and pastries baked daily! 🍞',
        isComplete: true,
        fcmToken: 'fake-fcm-token-bob'
      },
      {
        uid: 'vendor-carol-flowers',
        displayName: 'Carol\'s Flower Garden',
        stallName: 'Carol\'s Flower Garden',
        marketCity: 'Seattle, WA', 
        avatarUrl: 'https://picsum.photos/100/100?random=103',
        bio: 'Beautiful seasonal flowers and arrangements 🌸',
        isComplete: true,
        fcmToken: 'fake-fcm-token-carol'
      },
      {
        uid: 'vendor-dave-honey',
        displayName: 'Dave\'s Mountain Honey',
        stallName: 'Dave\'s Mountain Honey',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://picsum.photos/100/100?random=104', 
        bio: 'Pure wildflower honey from the Cascade Mountains 🍯',
        isComplete: true,
        fcmToken: 'fake-fcm-token-dave'
      }
    ];

    console.log('👥 Adding test vendor profiles...');
    
    // Add vendor profiles
    for (const vendor of testVendors) {
      await db.collection('vendors').doc(vendor.uid).set(vendor);
      console.log(`✅ Added vendor: ${vendor.displayName}`);
    }

    // Sample messages between vendors
    const testMessages = [
      {
        fromUid: 'vendor-alice-farm',
        toUid: 'vendor-bob-bakery',
        text: 'Hi Bob! Do you need any fresh herbs for your bread?',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)), // 2 hours ago
        isRead: false
      },
      {
        fromUid: 'vendor-bob-bakery', 
        toUid: 'vendor-alice-farm',
        text: 'That would be amazing! I could use some rosemary and thyme.',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1.5 * 60 * 60 * 1000)), // 1.5 hours ago
        isRead: false
      },
      {
        fromUid: 'vendor-alice-farm',
        toUid: 'vendor-bob-bakery', 
        text: 'Perfect! I have both fresh. I\'ll bring some over later.',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 60 * 60 * 1000)), // 1 hour ago
        isRead: false
      },
      {
        fromUid: 'vendor-carol-flowers',
        toUid: 'vendor-dave-honey',
        text: 'Hey Dave! Would you be interested in trading honey for some sunflowers?',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000)), // 30 min ago
        isRead: false
      },
      {
        fromUid: 'vendor-dave-honey',
        toUid: 'vendor-carol-flowers',
        text: 'Absolutely! I love sunflowers. How many jars of honey would you want?',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 15 * 60 * 1000)), // 15 min ago
        isRead: false
      }
    ];

    console.log('💬 Adding sample messages...');
    
    // Add messages
    for (const message of testMessages) {
      await db.collection('messages').add(message);
      console.log(`✅ Added message: "${message.text.substring(0, 30)}..."`);
    }

    console.log('');
    console.log('🎉 Messaging test data setup complete!');
    console.log('');
    console.log('📋 What was created:');
    console.log('   • 4 test vendor profiles with complete information');
    console.log('   • 5 sample messages between vendors');
    console.log('   • All vendors are in Portland, OR or Seattle, WA');
    console.log('');
    console.log('🧪 How to test messaging:');
    console.log('   1. Sign in as any user and complete your profile');
    console.log('   2. Go to the Messages tab - you should see conversations');
    console.log('   3. Tap on a conversation to open the chat screen');
    console.log('   4. Send messages back and forth');
    console.log('');
    console.log('🔍 To view the data:');
    console.log('   • Firestore UI: http://127.0.0.1:4000/firestore');
    console.log('   • Check "vendors" and "messages" collections');
    console.log('');
    console.log('💡 Note: To discover vendors for new conversations,');
    console.log('   we\'ll need to implement a vendor discovery feature');
    console.log('   (browse vendors, search, or follow system)');

  } catch (error) {
    console.error('❌ Error setting up messaging test data:', error);
    process.exit(1);
  }
}

setupMessagingTestData(); 