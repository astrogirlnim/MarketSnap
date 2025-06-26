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
    // Test vendor profiles for messaging with authentication
    const testVendors = [
      {
        uid: 'vendor-alice-farm',
        email: 'alice@farmstand.com',
        phoneNumber: '+15551001001',
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
        email: 'bob@artisanbakery.com',
        phoneNumber: '+15551001002',
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
        email: 'carol@flowergarden.com',
        phoneNumber: '+15551001003',
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
        email: 'dave@mountainhoney.com',
        phoneNumber: '+15551001004',
        displayName: 'Dave\'s Mountain Honey',
        stallName: 'Dave\'s Mountain Honey',
        marketCity: 'Portland, OR',
        avatarUrl: 'https://picsum.photos/100/100?random=104', 
        bio: 'Pure wildflower honey from the Cascade Mountains 🍯',
        isComplete: true,
        fcmToken: 'fake-fcm-token-dave'
      }
    ];

    console.log('🔐 Creating authentication accounts...');
    
    // Create authentication accounts for test vendors
    for (const vendor of testVendors) {
      try {
        await admin.auth().createUser({
          uid: vendor.uid,
          email: vendor.email,
          phoneNumber: vendor.phoneNumber,
          displayName: vendor.displayName,
          emailVerified: true,
        });
        console.log(`✅ Created auth account: ${vendor.displayName} (${vendor.email})`);
      } catch (error) {
        if (error.code === 'auth/uid-already-exists') {
          console.log(`⚠️  Auth account already exists: ${vendor.displayName}`);
        } else {
          console.error(`❌ Error creating auth account for ${vendor.displayName}:`, error.message);
        }
      }
    }

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
        participants: ['vendor-alice-farm', 'vendor-bob-bakery'],
        conversationId: 'vendor-alice-farm_vendor-bob-bakery',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000)), // 2 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 2 * 60 * 60 * 1000 + 24 * 60 * 60 * 1000)), // 22 hours from now
        isRead: false
      },
      {
        fromUid: 'vendor-bob-bakery', 
        toUid: 'vendor-alice-farm',
        text: 'That would be amazing! I could use some rosemary and thyme.',
        participants: ['vendor-alice-farm', 'vendor-bob-bakery'],
        conversationId: 'vendor-alice-farm_vendor-bob-bakery',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1.5 * 60 * 60 * 1000)), // 1.5 hours ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1.5 * 60 * 60 * 1000 + 24 * 60 * 60 * 1000)), // 22.5 hours from now
        isRead: false
      },
      {
        fromUid: 'vendor-alice-farm',
        toUid: 'vendor-bob-bakery', 
        text: 'Perfect! I have both fresh. I\'ll bring some over later.',
        participants: ['vendor-alice-farm', 'vendor-bob-bakery'],
        conversationId: 'vendor-alice-farm_vendor-bob-bakery',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 60 * 60 * 1000)), // 1 hour ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 1 * 60 * 60 * 1000 + 24 * 60 * 60 * 1000)), // 23 hours from now
        isRead: false
      },
      {
        fromUid: 'vendor-carol-flowers',
        toUid: 'vendor-dave-honey',
        text: 'Hey Dave! Would you be interested in trading honey for some sunflowers?',
        participants: ['vendor-carol-flowers', 'vendor-dave-honey'],
        conversationId: 'vendor-carol-flowers_vendor-dave-honey',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000)), // 30 min ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000 + 24 * 60 * 60 * 1000)), // 23.5 hours from now
        isRead: false
      },
      {
        fromUid: 'vendor-dave-honey',
        toUid: 'vendor-carol-flowers',
        text: 'Absolutely! I love sunflowers. How many jars of honey would you want?',
        participants: ['vendor-carol-flowers', 'vendor-dave-honey'],
        conversationId: 'vendor-carol-flowers_vendor-dave-honey',
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 15 * 60 * 1000)), // 15 min ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 15 * 60 * 1000 + 24 * 60 * 60 * 1000)), // 23.75 hours from now
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
    console.log('   • 4 test vendor authentication accounts');
    console.log('   • 4 test vendor profiles with complete information');
    console.log('   • 5 sample messages between vendors');
    console.log('   • All vendors are in Portland, OR or Seattle, WA');
    console.log('');
    console.log('🔐 TEST VENDOR LOGIN CREDENTIALS:');
    console.log('');
    console.log('   🌱 Alice\'s Farm Stand');
    console.log('      Email: alice@farmstand.com');
    console.log('      Phone: +15551001001');
    console.log('      UID: vendor-alice-farm');
    console.log('');
    console.log('   🍞 Bob\'s Artisan Bakery');
    console.log('      Email: bob@artisanbakery.com');
    console.log('      Phone: +15551001002');
    console.log('      UID: vendor-bob-bakery');
    console.log('');
    console.log('   🌸 Carol\'s Flower Garden');
    console.log('      Email: carol@flowergarden.com');
    console.log('      Phone: +15551001003');
    console.log('      UID: vendor-carol-flowers');
    console.log('');
    console.log('   🍯 Dave\'s Mountain Honey');
    console.log('      Email: dave@mountainhoney.com');
    console.log('      Phone: +15551001004');
    console.log('      UID: vendor-dave-honey');
    console.log('');
    console.log('🧪 How to test messaging:');
    console.log('   1. Sign in using any of the above email addresses');
    console.log('   2. Use phone number authentication or email (no password needed in emulator)');
    console.log('   3. Go to the Messages tab - you should see conversations');
    console.log('   4. Tap on a conversation to open the chat screen');
    console.log('   5. Send messages back and forth');
    console.log('');
    console.log('🔍 To view the data:');
    console.log('   • Firestore UI: http://127.0.0.1:4000/firestore');
    console.log('   • Auth UI: http://127.0.0.1:4000/auth');
    console.log('   • Check "vendors" and "messages" collections');
    console.log('');
    console.log('💡 Note: In Firebase emulator, you can sign in with any email');
    console.log('   without a password. Just use the email addresses above.');

  } catch (error) {
    console.error('❌ Error setting up messaging test data:', error);
    process.exit(1);
  }
}

setupMessagingTestData(); 