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

async function clearMessagingData() {
  console.log('🧹 Clearing all messaging data from Firebase emulators...');
  console.log('');
  
  try {
    // Clear messages collection
    console.log('💬 Clearing messages collection...');
    const messagesSnapshot = await db.collection('messages').get();
    
    if (messagesSnapshot.empty) {
      console.log('   ✅ Messages collection is already empty');
    } else {
      const batch = db.batch();
      messagesSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`   ✅ Deleted ${messagesSnapshot.docs.length} messages`);
    }

    // Clear conversations collection (if it exists)
    console.log('📋 Clearing conversations collection...');
    const conversationsSnapshot = await db.collection('conversations').get();
    
    if (conversationsSnapshot.empty) {
      console.log('   ✅ Conversations collection is already empty');
    } else {
      const batch = db.batch();
      conversationsSnapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });
      await batch.commit();
      console.log(`   ✅ Deleted ${conversationsSnapshot.docs.length} conversations`);
    }

    // Clear FCM tokens from vendor profiles (but keep the profiles)
    console.log('🔔 Clearing FCM tokens from vendor profiles...');
    const vendorsSnapshot = await db.collection('vendors').get();
    
    if (vendorsSnapshot.empty) {
      console.log('   ✅ No vendor profiles found');
    } else {
      const batch = db.batch();
      let tokensCleared = 0;
      
      vendorsSnapshot.docs.forEach((doc) => {
        const data = doc.data();
        if (data.fcmToken) {
          batch.update(doc.ref, { fcmToken: admin.firestore.FieldValue.delete() });
          tokensCleared++;
        }
      });
      
      if (tokensCleared > 0) {
        await batch.commit();
        console.log(`   ✅ Cleared FCM tokens from ${tokensCleared} vendor profiles`);
      } else {
        console.log('   ✅ No FCM tokens found to clear');
      }
    }

    console.log('');
    console.log('🎉 Messaging data cleared successfully!');
    console.log('');
    console.log('📋 What was cleared:');
    console.log('   • All messages between vendors');
    console.log('   • All conversation records');
    console.log('   • FCM tokens (for fresh notification setup)');
    console.log('   • Vendor profiles were preserved');
    console.log('');
    console.log('🔄 Next steps:');
    console.log('   1. Run: node scripts/setup_messaging_test_data.js');
    console.log('   2. Or start fresh messaging between test vendors');
    console.log('');

  } catch (error) {
    console.error('❌ Error clearing messaging data:', error);
    process.exit(1);
  }
}

// Run the function
clearMessagingData()
  .then(() => {
    console.log('✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Script failed:', error);
    process.exit(1);
  }); 