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

async function addTestMessages() {
  console.log('💬 Adding test messages to MarketSnap...');
  
  try {
    // Sample messages between vendors
    const testMessages = [
      {
        fromUid: 'vendor-alice-farm',
        toUid: 'vendor-bob-bakery',
        conversationId: 'vendor-alice-farm_vendor-bob-bakery',
        participants: ['vendor-alice-farm', 'vendor-bob-bakery'],
        text: 'Hi Bob! Do you need any fresh herbs for your bread?',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 30 * 60 * 1000)), // 30 minutes ago
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)), // 24 hours from now
      },
      {
        fromUid: 'vendor-bob-bakery',
        toUid: 'vendor-alice-farm',
        conversationId: 'vendor-alice-farm_vendor-bob-bakery',
        participants: ['vendor-alice-farm', 'vendor-bob-bakery'],
        text: 'That would be amazing! I could use some rosemary and thyme.',
        isRead: false,
        createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 0 * 60 * 1000)), // Now
        expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)), // 24 hours from now
      },
    ];

    console.log(`📝 Adding ${testMessages.length} test messages...`);

    for (const message of testMessages) {
      try {
        const docRef = await db.collection('messages').add(message);
        console.log(`✅ Added message: "${message.text.substring(0, 30)}..." (ID: ${docRef.id})`);
      } catch (error) {
        console.error(`❌ Error adding message: "${message.text.substring(0, 30)}..."`, error);
      }
    }

    console.log('🎉 Test messages added successfully!');
    
    // Verify messages were added
    const messagesSnapshot = await db.collection('messages').get();
    console.log(`📊 Total messages in database: ${messagesSnapshot.size}`);
    
    process.exit(0);
  } catch (error) {
    console.error('❌ Error adding test messages:', error);
    process.exit(1);
  }
}

addTestMessages(); 