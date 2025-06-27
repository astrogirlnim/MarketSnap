const admin = require('firebase-admin');

// Initialize Firebase Admin SDK for emulator
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'marketsnap-app',
  });
}

const db = admin.firestore();

// Connect to Firestore emulator
db.settings({
  host: 'localhost:8080',
  ssl: false,
});

// Test FAQ data for vendors
const testFAQs = [
  {
    vendorId: 'tJlgNXg24H7bZoXdPknj6pymbJ5q', // Use the user ID from the logs
    question: 'What dog breeds do you have available?',
    answer: 'We have various dog statuettes including Golden Retrievers, German Shepherds, and Bulldogs, all handcrafted from local clay.',
    chunkText: 'dog breeds statuettes Golden Retrievers German Shepherds Bulldogs handcrafted clay',
    keywords: ['dog', 'breeds', 'statuettes', 'handcrafted', 'clay', 'Golden Retriever', 'German Shepherd', 'Bulldog'],
    category: 'crafts',
    embedding: null, // Would normally contain OpenAI embeddings
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    vendorId: 'tJlgNXg24H7bZoXdPknj6pymbJ5q',
    question: 'How much do the dog statuettes cost?',
    answer: 'Our dog statuettes range from $15-45 depending on size. Small ones are $15, medium $25, and large $45.',
    chunkText: 'dog statuettes cost price $15 $25 $45 small medium large size',
    keywords: ['dog', 'statuettes', 'cost', 'price', 'small', 'medium', 'large', 'size'],
    category: 'crafts',
    embedding: null,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    vendorId: 'tJlgNXg24H7bZoXdPknj6pymbJ5q',
    question: 'Are the statuettes suitable for outdoor display?',
    answer: 'Yes! Our clay statuettes are fired at high temperature and sealed with weather-resistant glaze, perfect for gardens.',
    chunkText: 'statuettes outdoor display clay fired high temperature sealed weather-resistant glaze gardens',
    keywords: ['statuettes', 'outdoor', 'display', 'clay', 'weather-resistant', 'glaze', 'gardens'],
    category: 'crafts',
    embedding: null,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    vendorId: 'general-vendor',
    question: 'What tomato varieties do you grow?',
    answer: 'We grow heirloom tomatoes including Cherokee Purple, Brandywine, and Green Zebra varieties.',
    chunkText: 'tomato varieties heirloom Cherokee Purple Brandywine Green Zebra grow',
    keywords: ['tomato', 'varieties', 'heirloom', 'Cherokee Purple', 'Brandywine', 'Green Zebra', 'grow'],
    category: 'produce',
    embedding: null,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
  {
    vendorId: 'general-vendor',
    question: 'How do you keep tomatoes fresh?',
    answer: 'Store ripe tomatoes at room temperature and use within 3-5 days. Avoid refrigeration as it affects flavor.',
    chunkText: 'tomatoes fresh store room temperature 3-5 days avoid refrigeration flavor',
    keywords: ['tomatoes', 'fresh', 'store', 'room temperature', 'refrigeration', 'flavor'],
    category: 'produce',
    embedding: null,
    createdAt: admin.firestore.Timestamp.now(),
    updatedAt: admin.firestore.Timestamp.now(),
  },
];

async function addTestFAQs() {
  console.log('🔄 Adding test FAQ data to faqVectors collection...');
  
  const batch = db.batch();
  
  for (const faq of testFAQs) {
    const docRef = db.collection('faqVectors').doc();
    batch.set(docRef, faq);
    console.log(`✅ Added FAQ: "${faq.question.substring(0, 50)}..."`);
  }
  
  try {
    await batch.commit();
    console.log(`🎉 Successfully added ${testFAQs.length} test FAQs!`);
    console.log('📍 FAQs added for vendor ID: tJlgNXg24H7bZoXdPknj6pymbJ5q');
    console.log('🔍 You should now see FAQ suggestions when viewing posts with relevant content');
  } catch (error) {
    console.error('❌ Error adding FAQs:', error);
  }
}

// Run the script
addTestFAQs()
  .then(() => {
    console.log('✨ FAQ data setup complete!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Script failed:', error);
    process.exit(1);
  }); 