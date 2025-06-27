const admin = require('firebase-admin');

// Initialize Firebase Admin SDK for emulator
admin.initializeApp({
  projectId: 'demo-marketsnap-app',
});

// Use Firestore emulator
const db = admin.firestore();
db.settings({
  host: 'localhost:8080',
  ssl: false,
});

async function testMessagingQueries() {
  console.log('🔍 Testing messaging queries with demo project...');
  
  const testUserId = 'test-user-123';
  
  try {
    console.log(`📊 Testing getUserConversations query for user: ${testUserId}`);
    
    // This is the exact query from MessagingService.getUserConversations
    const query = db
      .collection('messages')
      .where('participants', 'array-contains', testUserId)
      .orderBy('createdAt', 'desc')
      .limit(100);
    
    console.log('⏱️  Executing query...');
    const startTime = Date.now();
    const snapshot = await query.get();
    const duration = Date.now() - startTime;
    
    console.log(`✅ Query completed in ${duration}ms`);
    console.log(`📝 Found ${snapshot.docs.length} documents`);
    console.log(`📭 No messages found (this is expected for a new user with demo project)`);

    console.log('\n🔍 Testing simpler query without orderBy...');
    const simpleQuery = db
      .collection('messages')
      .where('participants', 'array-contains', testUserId);
    
    const simpleSnapshot = await simpleQuery.get();
    console.log(`✅ Simple query found ${simpleSnapshot.docs.length} documents`);

  } catch (error) {
    console.error('❌ Query failed:', error.message);
    if (error.message.includes('index')) {
      console.log('💡 This suggests missing Firestore indexes - but our indexes should be loaded now.');
    }
  }
}

async function createTestMessage() {
  console.log('\n📝 Creating a test message to trigger index creation...');
  
  try {
    const testMessage = {
      fromUid: 'test-user-123',
      toUid: 'test-user-456',
      text: 'Test message to trigger indexing',
      conversationId: 'test-user-123_test-user-456',
      participants: ['test-user-123', 'test-user-456'],
      createdAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() + 24 * 60 * 60 * 1000)),
      isRead: false,
    };
    
    const docRef = await db.collection('messages').add(testMessage);
    console.log(`✅ Test message created with ID: ${docRef.id}`);
    
    return docRef.id;
  } catch (error) {
    console.error('❌ Error creating test message:', error);
    return null;
  }
}

async function cleanupTestData() {
  console.log('\n🧹 Cleaning up test data...');
  
  try {
    const testMessages = await db
      .collection('messages')
      .where('text', '==', 'Test message to trigger indexing')
      .get();
    
    const batch = db.batch();
    testMessages.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`✅ Cleaned up ${testMessages.docs.length} test messages`);
  } catch (error) {
    console.error('❌ Error cleaning up test data:', error);
  }
}

async function main() {
  console.log('🚀 MarketSnap Messaging Debug Tool (Demo Project)\n');
  
  try {
    await testMessagingQueries();
    console.log('\n🎉 Debug test completed!');
  } catch (error) {
    console.error('💥 Unexpected error:', error);
  }
  
  process.exit(0);
}

main(); 