#!/bin/bash

# MarketSnap Firebase Emulators Startup Script
# Starts Firebase emulators with proper configuration for local development

set -e  # Exit on any error

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[${timestamp}] INFO:${NC} $message"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[${timestamp}] SUCCESS:${NC} $message"
            ;;
        "WARNING")  
            echo -e "${YELLOW}[${timestamp}] WARNING:${NC} $message"
            ;;
        "ERROR")
            echo -e "${RED}[${timestamp}] ERROR:${NC} $message"
            ;;
    esac
}

# Check if we're in the right directory
if [[ ! -f "pubspec.yaml" ]]; then
    log "ERROR" "pubspec.yaml not found. Please run this script from the MarketSnap project root."
    exit 1
fi

log "INFO" "🔥 Starting Firebase Emulators for MarketSnap"

# Check if .env file exists
if [[ ! -f ".env" ]]; then
    log "ERROR" ".env file not found. Please create .env file with Firebase configuration."
    exit 1
fi

# Generate firebase.json if it doesn't exist
if [[ ! -f "firebase.json" ]]; then
    log "INFO" "Generating firebase.json from template..."
    
    if [[ ! -f "firebase.json.template" ]]; then
        log "ERROR" "firebase.json.template not found. This file is required."
        exit 1
    fi
    
    # Load environment variables
    source .env
    
    # Generate firebase.json using envsubst
    if command -v envsubst &> /dev/null; then
        envsubst < firebase.json.template > firebase.json
        log "SUCCESS" "Generated firebase.json from template"
    else
        log "ERROR" "envsubst not found. Please install gettext package."
        exit 1
    fi
fi

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    log "ERROR" "Firebase CLI not found. Please install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if user is logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    log "WARNING" "Not logged in to Firebase. Please run: firebase login"
    firebase login
fi

# Kill any existing emulator processes
log "INFO" "Stopping any existing Firebase emulators..."
pkill -f "firebase emulators" 2>/dev/null || true
pkill -f "cloud-firestore-emulator" 2>/dev/null || true
pkill -f "cloud-storage-rules-runtime" 2>/dev/null || true
sleep 2

# Build Cloud Functions if they exist
if [[ -d "functions" ]]; then
    log "INFO" "Building Cloud Functions..."
    cd functions
    if [[ -f "package.json" ]]; then
        npm install --silent
        npm run build --silent
        log "SUCCESS" "Cloud Functions built successfully"
    fi
    cd ..
fi

# Start Firebase emulators
log "INFO" "Starting Firebase emulators..."
log "INFO" "Emulator UI will be available at: http://127.0.0.1:4000"
log "INFO" "Auth Emulator: http://127.0.0.1:9099"
log "INFO" "Firestore Emulator: http://127.0.0.1:8080"
log "INFO" "Storage Emulator: http://127.0.0.1:9199"
log "INFO" "Functions Emulator: http://127.0.0.1:5001"

echo ""
log "SUCCESS" "🚀 Firebase emulators starting..."
echo ""
log "INFO" "💡 Tips:"
log "INFO" "   • Use the Emulator UI to view/edit data: http://127.0.0.1:4000"
log "INFO" "   • Auth emulator automatically creates test users"
log "INFO" "   • Press Ctrl+C to stop all emulators"
echo ""

# Start emulators with proper configuration
firebase emulators:start --only auth,firestore,storage,functions 