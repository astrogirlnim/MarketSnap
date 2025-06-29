const admin = require('firebase-admin');
const https = require('https');

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'demo-marketsnap',
  });
}

async function testVectorization() {
  console.log('🔍 Testing batchVectorizeFAQs function...');
  
  try {
    // Call function via HTTP endpoint (emulator)
    const response = await fetch('http://localhost:5001/demo-marketsnap/us-central1/batchVectorizeFAQs', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer test-token' // Emulator doesn't validate
      },
      body: JSON.stringify({
        data: {
          vendorId: 'test-vendor-123',
          limit: 5
        }
      })
    });
    
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }
    
    const result = await response.json();
    console.log('✅ Function call successful:', result);
    
  } catch (error) {
    console.error('❌ Function call failed:');
    console.error('Error:', error.message);
    console.error('Full error:', error);
    
    // Try alternative approach with curl command
    console.log('\n🔄 Trying with curl command...');
    const { spawn } = require('child_process');
    
    const curl = spawn('curl', [
      '-X', 'POST',
      '-H', 'Content-Type: application/json',
      '-d', JSON.stringify({
        data: {
          vendorId: 'test-vendor-123',
          limit: 5
        }
      }),
      'http://localhost:5001/demo-marketsnap/us-central1/batchVectorizeFAQs'
    ]);
    
    curl.stdout.on('data', (data) => {
      console.log('✅ Curl response:', data.toString());
    });
    
    curl.stderr.on('data', (data) => {
      console.error('❌ Curl error:', data.toString());
    });
    
    curl.on('close', (code) => {
      console.log(`🏁 Curl exited with code ${code}`);
    });
  }
}

// Add basic FAQ data for testing
async function addTestFAQ() {
  console.log('📝 Adding test FAQ for vectorization...');
  
  try {
    const db = admin.firestore();
    
    // Add to faqVectors collection without embedding
    const testFAQ = {
      vendorId: 'test-vendor-123',
      question: 'What are your hours?',
      answer: 'We are open Monday to Friday 9 AM to 5 PM.',
      chunkText: 'What are your hours? We are open Monday to Friday 9 AM to 5 PM.',
      category: 'general',
      keywords: ['hours', 'open', 'schedule'],
      embedding: null, // No embedding yet
      createdAt: admin.firestore.Timestamp.now(),
      updatedAt: admin.firestore.Timestamp.now(),
    };
    
    await db.collection('faqVectors').add(testFAQ);
    console.log('✅ Test FAQ added successfully');
    
  } catch (error) {
    console.error('❌ Error adding test FAQ:', error);
  }
}

async function main() {
  console.log('🚀 Starting vectorization debug test...');
  
  // Add test data first
  await addTestFAQ();
  
  // Wait a moment for data to settle
  await new Promise(resolve => setTimeout(resolve, 1000));
  
  // Test the function
  await testVectorization();
  
  // Wait for curl to complete
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  console.log('🏁 Debug test complete');
  process.exit(0);
}

main().catch(console.error); 