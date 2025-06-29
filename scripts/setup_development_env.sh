#!/bin/bash

# MarketSnap Development Environment Setup Script
# This script helps configure the environment for AI vectorization features

echo "🚀 MarketSnap Development Environment Setup"
echo "==========================================="

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from template..."
    cp env.example .env
    echo "✅ Created .env file"
else
    echo "✅ .env file already exists"
fi

# Check for OpenAI API key
if grep -q "your_openai_api_key_here" .env 2>/dev/null; then
    echo ""
    echo "⚠️  CONFIGURATION REQUIRED:"
    echo "   1. Get your OpenAI API key from: https://platform.openai.com/api-keys"
    echo "   2. Open .env file and replace 'your_openai_api_key_here' with your actual key"
    echo "   3. Set AI_FUNCTIONS_ENABLED=true in .env"
    echo ""
    echo "🔧 Edit .env file now? (y/n)"
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        if command -v code >/dev/null 2>&1; then
            code .env
        elif command -v nano >/dev/null 2>&1; then
            nano .env
        else
            echo "Please edit .env manually with your preferred editor"
        fi
    fi
else
    echo "✅ OpenAI API key appears to be configured"
fi

# Check if Firebase emulator is running
echo ""
echo "🔍 Checking Firebase emulator status..."
if lsof -i :5001 >/dev/null 2>&1; then
    echo "✅ Firebase Functions emulator is running (port 5001)"
else
    echo "⚠️  Firebase Functions emulator not running"
    echo "   Run: firebase emulators:start --only functions,auth,firestore"
fi

if lsof -i :8080 >/dev/null 2>&1; then
    echo "✅ Firestore emulator is running (port 8080)"
else
    echo "⚠️  Firestore emulator not running"
fi

if lsof -i :9099 >/dev/null 2>&1; then
    echo "✅ Auth emulator is running (port 9099)"
else
    echo "⚠️  Auth emulator not running"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Configure OpenAI API key in .env file"
echo "2. Start Firebase emulators if not running"
echo "3. Test vectorization feature in the app"
echo ""
echo "🔧 For troubleshooting, check: memory_bank/debugging_log.md"
echo ""
echo "✨ Setup complete!" 