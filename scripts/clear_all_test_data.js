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

async function clearCollection(collectionName) {
  console.log(`🧹 Clearing ${collectionName} collection...`);
  const snapshot = await db.collection(collectionName).get();
  
  if (snapshot.empty) {
    console.log(`   ✅ ${collectionName} collection is already empty`);
    return 0;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    batch.delete(doc.ref);
  });
  await batch.commit();
  console.log(`   ✅ Deleted ${snapshot.docs.length} documents from ${collectionName}`);
  return snapshot.docs.length;
}

async function clearAllTestData() {
  console.log('🧹 Clearing ALL test data from Firebase emulators...');
  console.log('💡 This will give you a completely fresh start for testing');
  console.log('');
  
  try {
    let totalDeleted = 0;

    // Clear all main collections
    const collections = [
      'snaps',
      'vendors', 
      'messages',
      'conversations',
      'ragFeedback',
      'faqVectors',
      'broadcasts',
      'followers'
    ];

    for (const collection of collections) {
      const deleted = await clearCollection(collection);
      totalDeleted += deleted;
    }

    // Clear authentication accounts
    console.log('🔐 Clearing authentication accounts...');
    try {
      const listUsersResult = await admin.auth().listUsers();
      let authDeleted = 0;
      
      for (const userRecord of listUsersResult.users) {
        // Only delete test users (don't delete real user accounts)
        if (userRecord.email && userRecord.email.includes('test') || 
            userRecord.uid.startsWith('vendor-') ||
            userRecord.email?.includes('@organicfarms.com') ||
            userRecord.email?.includes('@artisanbread.com') ||
            userRecord.email?.includes('@seasonalblooms.com') ||
            userRecord.email?.includes('@mountainhoney.com') ||
            userRecord.email?.includes('@farmhousecheese.com') ||
            userRecord.email?.includes('@mountainroast.com')) {
          await admin.auth().deleteUser(userRecord.uid);
          authDeleted++;
        }
      }
      
      if (authDeleted > 0) {
        console.log(`   ✅ Deleted ${authDeleted} test authentication accounts`);
      } else {
        console.log('   ✅ No test authentication accounts found to delete');
      }
      
      totalDeleted += authDeleted;
    } catch (authError) {
      console.log('   ⚠️ Could not clear auth accounts (may not exist)');
    }

    console.log('');
    console.log('🎉 All test data cleared successfully!');
    console.log('');
    console.log('📊 Summary:');
    console.log(`   • Total items deleted: ${totalDeleted}`);
    console.log('   • Firestore collections cleared');
    console.log('   • Authentication accounts cleared');
    console.log('   • Fresh slate ready for new test data');
    console.log('');
    console.log('🔄 Next steps:');
    console.log('   1. Run: node scripts/add_farmers_market_data.js');
    console.log('   2. Test RAG feedback on fresh farmer\'s market content');
    console.log('');

  } catch (error) {
    console.error('❌ Error clearing test data:', error);
    process.exit(1);
  }
}

// Run the function
clearAllTestData()
  .then(() => {
    console.log('✅ Clear data script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('❌ Clear data script failed:', error);
    process.exit(1);
  }); 