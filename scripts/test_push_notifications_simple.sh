#!/bin/bash

# MarketSnap Simple Push Notification Testing Script
# Quick automated testing for push notification functionality

set -e

# Color codes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
}

# Quick setup check
check_prerequisites() {
    log "🔍 Checking prerequisites..."
    
    # Check if jq is available (install if needed)
    if ! command -v jq &> /dev/null; then
        log "Installing jq for JSON processing..."
        if command -v brew &> /dev/null; then
            brew install jq
        else
            error "Please install jq: https://jqlang.github.io/jq/download/"
            exit 1
        fi
    fi
    
    success "Prerequisites checked"
}

# Test Flutter app compilation
test_compilation() {
    log "🔨 Testing Flutter app compilation with push notifications..."
    
    if flutter analyze --no-pub >/dev/null 2>&1; then
        success "Flutter analyze: No issues"
    else
        error "Flutter analyze failed"
        return 1
    fi
    
    if flutter test >/dev/null 2>&1; then
        success "Flutter tests: All passing"
    else
        error "Flutter tests failed"
        return 1
    fi
    
    success "Compilation tests passed"
}

# Test Cloud Functions build
test_functions() {
    log "⚡ Testing Cloud Functions build..."
    
    cd functions
    if npm run build >/dev/null 2>&1; then
        success "Cloud Functions build successful"
    else
        error "Cloud Functions build failed"
        cd ..
        return 1
    fi
    cd ..
    
    success "Functions tests passed"
}

# Test emulator connectivity (if running)
test_emulator_connectivity() {
    log "🔥 Testing emulator connectivity..."
    
    if curl -s http://127.0.0.1:4000 >/dev/null; then
        success "Firebase emulators are running"
        
        # Test Firestore API
        if curl -s http://127.0.0.1:8080/v1/projects/marketsnap-app/databases >/dev/null; then
            success "Firestore emulator accessible"
        fi
        
        # Test Functions API
        if curl -s http://127.0.0.1:5001 >/dev/null; then
            success "Functions emulator accessible"
        fi
        
        return 0
    else
        log "⚠️  Firebase emulators not running (optional for this test)"
        log "   Start with: firebase emulators:start"
        return 1
    fi
}

# Test push notification service integration
test_integration() {
    log "🔗 Testing push notification service integration..."
    
    # Check if PushNotificationService exists and is properly imported
    if grep -q "PushNotificationService" lib/main.dart; then
        success "PushNotificationService integrated in main.dart"
    else
        error "PushNotificationService not found in main.dart"
        return 1
    fi
    
    # Check if service is initialized
    if grep -q "pushNotificationService.initialize" lib/main.dart; then
        success "PushNotificationService initialization found"
    else
        error "PushNotificationService initialization not found"
        return 1
    fi
    
    # Check if FCM dependency exists
    if grep -q "firebase_messaging" pubspec.yaml; then
        success "Firebase messaging dependency found"
    else
        error "Firebase messaging dependency missing"
        return 1
    fi
    
    success "Integration tests passed"
}

# Test Cloud Functions for push notifications
test_notification_functions() {
    log "📨 Testing notification Cloud Functions..."
    
    # Check if functions exist
    local functions=("sendFollowerPush" "sendMessageNotification" "fanOutBroadcast")
    
    for func in "${functions[@]}"; do
        if grep -q "$func" functions/src/index.ts; then
            success "Cloud Function '$func' found"
        else
            error "Cloud Function '$func' not found"
            return 1
        fi
    done
    
    success "Notification functions tests passed"
}

# Test Firestore rules for followers
test_firestore_rules() {
    log "🔒 Testing Firestore security rules..."
    
    if grep -q "vendors/{vendorId}/followers/{followerId}" firestore.rules; then
        success "Followers sub-collection rules found"
    else
        error "Followers sub-collection rules not found"
        return 1
    fi
    
    success "Firestore rules tests passed"
}

# Generate simple test report
generate_simple_report() {
    echo
    echo "================================"
    echo "🔔 PUSH NOTIFICATION TEST SUMMARY"
    echo "================================"
    echo
    echo "✅ Compilation & Code Quality"
    echo "✅ Cloud Functions"
    echo "✅ Service Integration"
    echo "✅ Notification Functions"
    echo "✅ Firestore Security Rules"
    echo
    echo "🎯 RESULT: All core components verified!"
    echo
    echo "📱 Next Steps:"
    echo "   1. Run advanced tests: ./scripts/test_push_notifications_advanced.sh"
    echo "   2. Test with emulators: firebase emulators:start"
    echo "   3. Test on device: ./scripts/dev_emulator.sh"
    echo
}

# Main execution
main() {
    echo
    echo "🚀 MarketSnap Push Notification Quick Test"
    echo "=========================================="
    echo
    
    check_prerequisites
    echo
    
    test_compilation
    echo
    
    test_functions
    echo
    
    test_integration
    echo
    
    test_notification_functions
    echo
    
    test_firestore_rules
    echo
    
    # Optional emulator test
    test_emulator_connectivity
    echo
    
    generate_simple_report
    
    success "🎉 Quick push notification tests completed!"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 