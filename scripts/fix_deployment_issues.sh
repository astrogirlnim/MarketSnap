#!/bin/bash

# Fix Firebase Deployment Issues
# This script addresses the container healthcheck failures and function trigger type changes

set -e

echo "🔧 Starting Firebase deployment issue fixes..."

# Set colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    print_error "Firebase CLI is not installed. Please install it first:"
    echo "npm install -g firebase-tools"
    exit 1
fi

# Check if we're in the correct directory
if [ ! -f "firebase.json" ] && [ ! -f "firebase.json.template" ]; then
    print_error "Not in a Firebase project directory. Please run from project root."
    exit 1
fi

print_status "Checking Firebase authentication..."
if ! firebase projects:list &> /dev/null; then
    print_error "Not authenticated with Firebase. Please run: firebase login"
    exit 1
fi

print_success "Firebase CLI authenticated successfully"

# Get the current project ID
PROJECT_ID=$(firebase use --current 2>/dev/null | grep "Active Project" | awk '{print $NF}' | tr -d '()')
if [ -z "$PROJECT_ID" ]; then
    print_warning "No active Firebase project. Using default project ID from environment..."
    PROJECT_ID=${FIREBASE_PROJECT_ID:-"marketsnap-lite"}
fi

print_status "Working with Firebase project: $PROJECT_ID"

# Step 1: Delete the problematic autoVectorizeFAQ function
print_status "Deleting problematic autoVectorizeFAQ function to resolve trigger type change..."
if firebase functions:delete autoVectorizeFAQ --force --non-interactive 2>/dev/null; then
    print_success "Successfully deleted autoVectorizeFAQ function"
else
    print_warning "autoVectorizeFAQ function might not exist or already deleted"
fi

# Step 2: Update Functions dependencies
print_status "Updating Firebase Functions dependencies..."
cd functions

# Install latest dependencies
print_status "Installing updated dependencies..."
npm install

# Build functions to check for compilation issues
print_status "Building functions to verify no compilation errors..."
npm run build

if [ $? -eq 0 ]; then
    print_success "Functions built successfully"
else
    print_error "Function build failed. Check TypeScript compilation errors above."
    exit 1
fi

cd ..

# Step 3: Deploy with staged approach
print_status "Starting staged deployment to minimize risks..."

# Deploy Firestore rules and indexes first
print_status "Deploying Firestore rules and indexes..."
firebase deploy --only firestore --non-interactive

# Deploy Storage rules
print_status "Deploying Storage rules..."
firebase deploy --only storage --non-interactive

# Deploy functions with retry logic
print_status "Deploying Firebase Functions with enhanced configuration..."
RETRY_COUNT=0
MAX_RETRIES=3

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if firebase deploy --only functions --non-interactive --debug; then
        print_success "Functions deployed successfully!"
        break
    else
        RETRY_COUNT=$((RETRY_COUNT + 1))
        print_warning "Function deployment failed. Retry $RETRY_COUNT of $MAX_RETRIES..."
        if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            print_status "Waiting 30 seconds before retry..."
            sleep 30
        fi
    fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    print_error "Function deployment failed after $MAX_RETRIES attempts"
    print_error "Check the logs above for specific error details"
    exit 1
fi

# Step 4: Verify deployment
print_status "Verifying deployment..."
firebase functions:list

print_success "🎉 Firebase deployment issue fixes completed successfully!"
print_status "All functions should now be running with proper resource allocation:"
print_status "  - Memory: 1GiB for regular functions, 2GiB for AI functions"
print_status "  - Timeout: 540 seconds"
print_status "  - Max instances: 100 for regular functions, 50 for AI functions"

echo ""
print_status "Next steps:"
echo "  1. Monitor function performance in Firebase Console"
echo "  2. Check Cloud Run logs if any issues persist"
echo "  3. Test function triggers to ensure they work correctly" 