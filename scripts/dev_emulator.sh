#!/bin/bash

# MarketSnap Development Emulator Script
# Launches both iOS and Android emulators and runs Flutter app on both platforms
# Handles cleanup on CTRL-C or script exit

set -e  # Exit on any error

# Color codes for logging
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables for process management
IOS_SIM_PID=""
ANDROID_EMU_PID=""
FLUTTER_IOS_PID=""
FLUTTER_ANDROID_PID=""
ANDROID_SDK_PATH="$HOME/Library/Android/sdk"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Emulator configurations
IOS_EMULATOR_ID="apple_ios_simulator"
ANDROID_EMULATOR_ID="Medium_Phone_API_36.0"
IOS_DEVICE_NAME="iPhone 16 Pro"  # Default iOS device
ANDROID_PORT="5554"  # Default Android emulator port

# Logging function with timestamps
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    case "$level" in
        "INFO")
            echo -e "${CYAN}[${timestamp}] INFO:${NC} $message"
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
        "DEBUG")
            echo -e "${PURPLE}[${timestamp}] DEBUG:${NC} $message"
            ;;
        *)
            echo -e "${BLUE}[${timestamp}] LOG:${NC} $message"
            ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    log "INFO" "🔍 Checking prerequisites..."
    
    # Check if we're in the right directory
    if [[ ! -f "$PROJECT_DIR/pubspec.yaml" ]]; then
        log "ERROR" "❌ pubspec.yaml not found. Please run this script from the MarketSnap project root."
        exit 1
    fi
    
    # Check Flutter installation
    if ! command -v flutter &> /dev/null; then
        log "ERROR" "❌ Flutter command not found. Please install Flutter and add it to your PATH."
        exit 1
    fi
    
    # Check .env file exists
    if [[ ! -f "$PROJECT_DIR/.env" ]]; then
        log "ERROR" "❌ .env file not found. Please create .env file with Firebase configuration."
        exit 1
    fi
    
    # Check Android SDK
    if [[ ! -d "$ANDROID_SDK_PATH" ]]; then
        log "ERROR" "❌ Android SDK not found at $ANDROID_SDK_PATH"
        exit 1
    fi
    
    # Check Xcode command line tools
    if ! command -v xcrun &> /dev/null; then
        log "ERROR" "❌ Xcode command line tools not found. Please install Xcode."
        exit 1
    fi
    
    log "SUCCESS" "✅ All prerequisites met"
}

# Function to clean and prepare Flutter project
prepare_flutter_project() {
    log "INFO" "🧹 Cleaning and preparing Flutter project..."
    cd "$PROJECT_DIR"
    
    # Run flutter clean and pub get to ensure a fresh state
    flutter clean > /dev/null 2>&1
    log "DEBUG" "Flutter clean completed"
    
    flutter pub get > /dev/null 2>&1
    log "DEBUG" "Flutter pub get completed"
    
    log "SUCCESS" "✅ Flutter project is clean and ready"
}

# Function to setup environment variables
setup_environment() {
    log "INFO" "🔧 Setting up environment variables..."
    
    # Set Android SDK environment variables
    export ANDROID_HOME="$ANDROID_SDK_PATH"
    export ANDROID_SDK_ROOT="$ANDROID_SDK_PATH"
    export PATH="$ANDROID_SDK_PATH/emulator:$ANDROID_SDK_PATH/platform-tools:$ANDROID_SDK_PATH/cmdline-tools/latest/bin:$PATH"
    
    log "DEBUG" "ANDROID_HOME set to: $ANDROID_HOME"
    log "DEBUG" "PATH updated with Android SDK tools"
    log "SUCCESS" "✅ Environment variables configured"
}

# Function to check emulator availability
check_emulators() {
    log "INFO" "🔍 Checking available emulators..."
    
    # Check Flutter emulators
    local flutter_emulators=$(flutter emulators 2>/dev/null)
    log "DEBUG" "Flutter emulators output:"
    echo "$flutter_emulators" | while IFS= read -r line; do
        log "DEBUG" "  $line"
    done
    
    # Verify iOS simulator
    if ! echo "$flutter_emulators" | grep -q "$IOS_EMULATOR_ID"; then
        log "ERROR" "❌ iOS Simulator ($IOS_EMULATOR_ID) not available"
        exit 1
    fi
    
    # Verify Android emulator
    if ! echo "$flutter_emulators" | grep -q "$ANDROID_EMULATOR_ID"; then
        log "ERROR" "❌ Android Emulator ($ANDROID_EMULATOR_ID) not available"
        log "INFO" "Available Android emulators:"
        "$ANDROID_SDK_PATH/emulator/emulator" -list-avds 2>/dev/null | while IFS= read -r line; do
            log "INFO" "  - $line"
        done
        exit 1
    fi
    
    log "SUCCESS" "✅ Required emulators are available"
}

# Function to check if iOS Simulator is already booted
check_ios_simulator_status() {
    log "INFO" "🔍 Checking iOS Simulator status..."
    
    # Check if any iOS simulators are currently booted
    local booted_devices=$(xcrun simctl list devices | grep "Booted" || true)
    
    if [[ -n "$booted_devices" ]]; then
        log "SUCCESS" "✅ Found booted iOS Simulator:"
        echo "$booted_devices" | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done
        return 0
    else
        log "INFO" "📱 No iOS Simulators currently booted"
        return 1
    fi
}

# Function to get available iOS simulators
get_available_ios_simulators() {
    log "DEBUG" "🔍 Getting available iOS simulators..."
    
    # Get list of available iOS simulators (iPhone devices only for mobile app)
    local available_sims=$(xcrun simctl list devices available | grep -E "iPhone.*\(.*\) \(Shutdown\)" | head -5 || true)
    
    if [[ -n "$available_sims" ]]; then
        log "DEBUG" "Available iOS Simulators:"
        echo "$available_sims" | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done
        # Return only the device list without debug output
        echo "$available_sims" | grep -E "iPhone.*\(.*\) \(Shutdown\)"
    else
        log "ERROR" "❌ No available iOS simulators found"
        return 1
    fi
}

# Function to extract device ID from simulator line
extract_device_id() {
    local sim_line="$1"
    # Extract UUID from format: "iPhone 16 Pro (CE267B8B-A009-41C3-A16F-80720B3D22AA) (Shutdown)"
    echo "$sim_line" | sed -n 's/.*(\([A-F0-9-]*\)).*(Shutdown).*/\1/p'
}

# Function to extract device name from simulator line  
extract_device_name() {
    local sim_line="$1"
    # Extract device name from format: "iPhone 16 Pro (CE267B8B-A009-41C3-A16F-80720B3D22AA) (Shutdown)"
    echo "$sim_line" | sed -n 's/^[[:space:]]*\([^(]*\)[[:space:]]*(.*/\1/p' | sed 's/[[:space:]]*$//'
}

# Function to boot iOS Simulator
boot_ios_simulator() {
    local device_id="$1"
    local device_name="$2"
    
    log "INFO" "🚀 Booting iOS Simulator: $device_name"
    log "DEBUG" "Device ID: $device_id"
    
    # Boot the simulator
    if xcrun simctl boot "$device_id" 2>/dev/null; then
        log "DEBUG" "Boot command executed successfully"
        
        # Open Simulator app
        open -a Simulator --args -CurrentDeviceUDID "$device_id" &
        IOS_SIM_PID=$!
        
        log "DEBUG" "Simulator app opened with PID: $IOS_SIM_PID"
        
        # Wait for simulator to be fully booted
        local max_wait=60
        local wait_count=0
        
        while [ $wait_count -lt $max_wait ]; do
            local boot_status=$(xcrun simctl list devices | grep "$device_id" | grep -o "Booted" || true)
            
            if [[ "$boot_status" == "Booted" ]]; then
                log "SUCCESS" "✅ iOS Simulator '$device_name' is now booted and ready"
                return 0
            fi
            
            log "DEBUG" "Waiting for iOS Simulator to fully boot... ($wait_count/$max_wait)"
            sleep 2
            ((wait_count++))
        done
        
        log "ERROR" "❌ iOS Simulator failed to boot within $max_wait seconds"
        return 1
    else
        log "ERROR" "❌ Failed to boot iOS Simulator: $device_name"
        return 1
    fi
}

# Function to launch iOS Simulator (improved version)
launch_ios_simulator() {
    log "INFO" "🍎 Setting up iOS Simulator..."
    
    # Step 1: Check if a simulator is already booted
    if check_ios_simulator_status; then
        log "SUCCESS" "✅ Using existing booted iOS Simulator"
        return 0
    fi
    
    # Step 2: Get available simulators
    local available_sims=$(get_available_ios_simulators)
    if [[ -z "$available_sims" ]]; then
        log "ERROR" "❌ No available iOS simulators found"
        return 1
    fi
    
    # Step 3: Select the first available simulator (preferably iPhone 16 Pro)
    local selected_sim=""
    local preferred_device="iPhone 16 Pro"
    
    # Try to find preferred device first (filter out any debug lines)
    selected_sim=$(echo "$available_sims" | grep -v "DEBUG" | grep "$preferred_device" | head -1 || true)
    
    # If preferred device not found, use the first available (filter out any debug lines)
    if [[ -z "$selected_sim" ]]; then
        selected_sim=$(echo "$available_sims" | grep -v "DEBUG" | grep -E "iPhone.*\(" | head -1)
        log "INFO" "💡 Preferred device '$preferred_device' not found, using first available"
    fi
    
    # Step 4: Extract device information
    local device_id=$(extract_device_id "$selected_sim")
    local device_name=$(extract_device_name "$selected_sim")
    
    if [[ -z "$device_id" || -z "$device_name" ]]; then
        log "ERROR" "❌ Failed to parse device information from: $selected_sim"
        return 1
    fi
    
    log "INFO" "📱 Selected iOS Simulator: $device_name (ID: $device_id)"
    
    # Step 5: Boot the selected simulator
    if boot_ios_simulator "$device_id" "$device_name"; then
        log "SUCCESS" "✅ iOS Simulator setup completed successfully"
        return 0
    else
        log "ERROR" "❌ Failed to boot iOS Simulator"
        return 1
    fi
}

# Function to get currently running Android emulator device ID
get_android_device_id() {
    # Get the first available Android emulator device ID
    local device_id=$("$ANDROID_SDK_PATH/platform-tools/adb" devices 2>/dev/null | grep "emulator-" | head -1 | awk '{print $1}' || echo "")
    echo "$device_id"
}

# Function to check Android emulator status
check_android_emulator_status() {
    local device_id=$(get_android_device_id)
    
    if [[ -z "$device_id" ]]; then
        log "DEBUG" "No Android device found in ADB devices list"
        return 1
    fi
    
    log "DEBUG" "Checking Android device status: $device_id"
    
    # Check if emulator is fully booted by checking multiple properties with specific device
    local boot_completed=$("$ANDROID_SDK_PATH/platform-tools/adb" -s "$device_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || echo "")
    local dev_bootcomplete=$("$ANDROID_SDK_PATH/platform-tools/adb" -s "$device_id" shell getprop dev.bootcomplete 2>/dev/null | tr -d '\r' || echo "")
    local init_svc_bootanim=$("$ANDROID_SDK_PATH/platform-tools/adb" -s "$device_id" shell getprop init.svc.bootanim 2>/dev/null | tr -d '\r' || echo "")
    
    log "DEBUG" "Boot properties - completed: '$boot_completed', dev_complete: '$dev_bootcomplete', bootanim: '$init_svc_bootanim'"
    
    # Primary check: Both boot_completed and dev_bootcomplete must be "1"
    if [[ "$boot_completed" == "1" && "$dev_bootcomplete" == "1" ]]; then
        # Secondary check: If bootanim is available, it should not be "running"
        if [[ -n "$init_svc_bootanim" && "$init_svc_bootanim" == "running" ]]; then
            log "DEBUG" "Android emulator boot animation still running"
            return 1  # Still booting
        else
            log "DEBUG" "Android emulator fully booted (bootanim: '$init_svc_bootanim')"
            # Add a small delay to ensure all services are up
            sleep 2
            return 0  # Fully booted
        fi
    else
        log "DEBUG" "Android emulator still booting (boot_completed: '$boot_completed', dev_complete: '$dev_bootcomplete')"
        return 1  # Still booting
    fi
}

# Function to launch Android Emulator
launch_android_emulator() {
    log "INFO" "🤖 Launching Android Emulator..."
    
    # Kill any existing Android emulator processes
    pkill -f "qemu-system" 2>/dev/null || true
    pkill -f "emulator" 2>/dev/null || true
    sleep 3
    
    # Launch Android emulator with optimized settings (no wipe-data for faster boot)
    "$ANDROID_SDK_PATH/emulator/emulator" -avd "$ANDROID_EMULATOR_ID" -gpu host -no-snapshot -no-boot-anim > /dev/null 2>&1 &
    ANDROID_EMU_PID=$!
    
    log "DEBUG" "Android Emulator launched with PID: $ANDROID_EMU_PID"
    
    # Wait for Android Emulator to be ready (optimized for fast boot)
    local max_wait=45  # Increased to 45 seconds for more reliability
    local wait_count=0
    
    while [ $wait_count -lt $max_wait ]; do
        # Check if ADB can connect to any Android emulator
        local device_id=$(get_android_device_id)
        if [[ -n "$device_id" ]]; then
            log "DEBUG" "ADB connection established to device: $device_id"
            
            # Wait a moment for emulator to settle
            sleep 2
            
            # Check if fully booted
            if check_android_emulator_status; then
                log "SUCCESS" "✅ Android Emulator is fully booted and ready (Device: $device_id)"
                return 0
            fi
        else
            log "DEBUG" "No Android device found in ADB devices list yet..."
        fi
        
        # Show progress every 10 seconds
        if [[ $((wait_count % 10)) -eq 0 ]]; then
            log "INFO" "⏳ Android Emulator still booting... ($wait_count/$max_wait seconds)"
        else
            log "DEBUG" "Waiting for Android Emulator to boot... ($wait_count/$max_wait)"
        fi
        
        sleep 2 # Changed from 3 to 2
        ((wait_count++))
    done
    
    log "ERROR" "❌ Android Emulator failed to boot within $max_wait seconds"
    return 1
}

# Function to get booted iOS simulator device ID for Flutter
get_booted_ios_device_id() {
    # Wait a moment for Flutter to detect the device
    sleep 3
    
    # Get the iOS simulator device ID that Flutter recognizes
    local flutter_devices
    flutter_devices=$(flutter devices 2>/dev/null)
    
    # Try to find the iOS device ID (UUID) from the flutter devices output
    # This looks for a line containing "ios" and "CoreSimulator" and then extracts the UUID.
    # This is more robust than looking for "(simulator)" which can be on a different line.
    local ios_device_id
    ios_device_id=$(echo "$flutter_devices" | grep "ios" | grep "CoreSimulator" | grep -o -E '[A-F0-9]{8}-([A-F0-9]{4}-){3}[A-F0-9]{12}' | head -1)

    # Fallback to generic iOS simulator ID if parsing fails
    if [[ -z "$ios_device_id" ]]; then
        log "DEBUG" "No specific iOS device UUID found, using generic 'apple_ios_simulator' ID as fallback."
        ios_device_id="apple_ios_simulator"
    else
        log "DEBUG" "Flutter detected iOS device with UUID: $ios_device_id"
    fi
    
    echo "$ios_device_id"
    return 0
}

# Function to run Flutter app on iOS
run_flutter_ios() {
    log "INFO" "🍎 Starting Flutter app on iOS..."
    
    cd "$PROJECT_DIR"
    
    # No need for flutter clean here, moved to the beginning
    
    # Get the booted iOS device ID for Flutter
    local ios_flutter_device_id=$(get_booted_ios_device_id)
    log "DEBUG" "Using iOS device ID for Flutter: $ios_flutter_device_id"
    
    # Wait for Flutter to recognize the iOS device with better detection
    local max_wait=30
    local wait_count=0
    local device_detected=false
    
    while [ $wait_count -lt $max_wait ]; do
        local flutter_devices_output=$(flutter devices 2>/dev/null)
        log "DEBUG" "Flutter devices output: $flutter_devices_output"
        if echo "$flutter_devices_output" | grep -F "$ios_flutter_device_id" > /dev/null; then
            log "SUCCESS" "✅ Flutter recognizes iOS Simulator"
            device_detected=true
            break
        fi
        
        if [[ $wait_count -eq 0 ]] || [[ $((wait_count % 5)) -eq 0 ]]; then
            log "DEBUG" "Waiting for Flutter to recognize iOS Simulator... ($wait_count/$max_wait)"
        fi
        sleep 2
        ((wait_count++))
    done
    
    if ! $device_detected; then
        log "WARNING" "⚠️  Flutter may not have detected iOS device, trying anyway..."
    fi
    
    # Create log file directory if it doesn't exist
    mkdir -p "$(dirname "scripts/flutter_ios.log")"
    
    # Run Flutter on iOS with better error handling
    log "INFO" "🚀 Preparing to launch Flutter on iOS Simulator..."
    log "INFO" "Command: flutter run -d \"$ios_flutter_device_id\" --debug --hot"
    
    # Use timeout-style approach for deployment
    (
        flutter run -d "$ios_flutter_device_id" --debug --hot 2>&1 | tee "scripts/flutter_ios.log"
    ) &
    FLUTTER_IOS_PID=$!
    
    # Give Flutter a moment to start
    sleep 3
    
    # Check if the process is still running (indicates successful start)
    if kill -0 "$FLUTTER_IOS_PID" 2>/dev/null; then
        log "SUCCESS" "✅ Flutter iOS app started successfully (PID: $FLUTTER_IOS_PID)"
        log "INFO" "📝 iOS logs: tail -f scripts/flutter_ios.log"
    else
        log "ERROR" "❌ Flutter iOS app failed to start"
        FLUTTER_IOS_PID=""
    fi
}

# Function to get flutter android device id
get_flutter_android_device_id() {
    local flutter_devices
    flutter_devices=$(flutter devices 2>/dev/null)

    # Try to parse the emulator-xxxx ID from the flutter devices output
    # This looks for a line with "emulator-" and extracts the ID (e.g., emulator-5554)
    local android_device_id
    android_device_id=$(echo "$flutter_devices" | grep -o -E 'emulator-[0-9]+' | head -1)
    
    if [[ -z "$android_device_id" ]]; then
        # Fallback to adb if parsing from flutter devices fails
        log "DEBUG" "Could not parse Android device ID from 'flutter devices', falling back to 'adb devices'."
        android_device_id=$(get_android_device_id) # Uses the existing adb function
    fi

    if [[ -z "$android_device_id" ]]; then
        log "WARNING" "⚠️ No specific Android device ID found. The script might fail."
    else
        log "DEBUG" "Flutter detected Android device with ID: $android_device_id"
    fi

    echo "$android_device_id"
}

# Function to run Flutter app on Android
run_flutter_android() {
    log "INFO" "🤖 Starting Flutter app on Android..."
    
    cd "$PROJECT_DIR"
    
    # No need for flutter clean here
    
    # Wait for Android device to be available with better detection
    local max_wait=30
    local wait_count=0
    local device_detected=false
    local android_device_id
    android_device_id=$(get_flutter_android_device_id)
    
    while [ $wait_count -lt $max_wait ]; do
        local flutter_devices_output=$(flutter devices 2>/dev/null)
        
        if [[ -n "$android_device_id" ]] && echo "$flutter_devices_output" | grep -F "$android_device_id"; then
            log "SUCCESS" "✅ Flutter recognizes Android Emulator: $android_device_id"
            device_detected=true
            break
        fi
        
        if [[ $wait_count -eq 0 ]] || [[ $((wait_count % 5)) -eq 0 ]]; then
            log "DEBUG" "Waiting for Android device to be available... ($wait_count/$max_wait)"
            log "DEBUG" "Target device ID: $android_device_id"
        fi
        sleep 2
        ((wait_count++))
    done
    
    if [[ -z "$android_device_id" ]]; then
        log "ERROR" "❌ Could not determine Android device ID. Skipping deployment."
        return
    fi
    
    if ! $device_detected; then
        log "WARNING" "⚠️  Flutter may not have detected Android device, trying anyway..."
    fi
    
    # Create log file directory if it doesn't exist
    mkdir -p "$(dirname "scripts/flutter_android.log")"
    
    # Run Flutter on Android with better error handling
    log "INFO" "🚀 Preparing to launch Flutter on Android Emulator..."
    log "INFO" "Command: flutter run -d \"$android_device_id\" --debug --hot"
    
    # Use timeout-style approach for deployment
    (
        flutter run -d "$android_device_id" --debug --hot 2>&1 | tee "scripts/flutter_android.log"
    ) &
    FLUTTER_ANDROID_PID=$!
    
    # Give Flutter a moment to start
    sleep 3
    
    # Check if the process is still running (indicates successful start)
    if kill -0 "$FLUTTER_ANDROID_PID" 2>/dev/null; then
        log "SUCCESS" "✅ Flutter Android app started successfully (PID: $FLUTTER_ANDROID_PID)"
        log "INFO" "📝 Android logs: tail -f scripts/flutter_android.log"
    else
        log "ERROR" "❌ Flutter Android app failed to start"
        FLUTTER_ANDROID_PID=""
    fi
}

# Function to monitor Flutter processes
monitor_flutter_processes() {
    log "INFO" "📱 Monitoring Flutter applications..."
    local monitoring_count=0
    
    while true; do
        # Check iOS Flutter process
        if [[ -n "$FLUTTER_IOS_PID" ]] && ! kill -0 "$FLUTTER_IOS_PID" 2>/dev/null; then
            log "WARNING" "⚠️  Flutter iOS process has stopped (PID: $FLUTTER_IOS_PID)"
            FLUTTER_IOS_PID=""
        fi
        
        # Check Android Flutter process
        if [[ -n "$FLUTTER_ANDROID_PID" ]] && ! kill -0 "$FLUTTER_ANDROID_PID" 2>/dev/null; then
            log "WARNING" "⚠️  Flutter Android process has stopped (PID: $FLUTTER_ANDROID_PID)"
            FLUTTER_ANDROID_PID=""
        fi
        
        # Show running processes status
        local ios_status="❌ Stopped"
        local android_status="❌ Stopped"
        local device_check=""
        
        if [[ -n "$FLUTTER_IOS_PID" ]] && kill -0 "$FLUTTER_IOS_PID" 2>/dev/null; then
            ios_status="✅ Running (PID: $FLUTTER_IOS_PID)"
        fi
        
        if [[ -n "$FLUTTER_ANDROID_PID" ]] && kill -0 "$FLUTTER_ANDROID_PID" 2>/dev/null; then
            android_status="✅ Running (PID: $FLUTTER_ANDROID_PID)"
        fi
        
        # Every 60 seconds, show device status
        if [[ $((monitoring_count % 6)) -eq 0 ]]; then
            local flutter_devices=$(flutter devices 2>/dev/null | grep -E "(iOS|emulator)" || echo "No devices detected")
            device_check=" | Devices: $(echo "$flutter_devices" | wc -l | tr -d ' ') detected"
        fi
        
        log "INFO" "📊 Flutter Status - iOS: $ios_status | Android: $android_status$device_check"
        
        # Show tips periodically
        if [[ $monitoring_count -eq 3 ]]; then
            log "INFO" "💡 Tip: You can monitor logs with 'tail -f scripts/flutter_ios.log' and 'tail -f scripts/flutter_android.log'"
        elif [[ $monitoring_count -eq 12 ]]; then
            log "INFO" "💡 Tip: Hot reload is available - press 'r' in Flutter console for hot reload"
        fi
        
        sleep 10
        ((monitoring_count++))
    done
}

# Function to get currently booted iOS simulator ID
get_booted_ios_simulator_id() {
    xcrun simctl list devices | grep "(Booted)" | grep -E "iPhone.*\(" | head -1 | sed -n 's/.*(\([A-F0-9-]*\)).*(Booted).*/\1/p'
}

# Cleanup function
cleanup() {
    log "INFO" "🧹 Starting cleanup process..."
    
    # Kill Flutter processes first
    if [[ -n "$FLUTTER_IOS_PID" ]]; then
        log "DEBUG" "Terminating Flutter iOS process (PID: $FLUTTER_IOS_PID)"
        kill -TERM "$FLUTTER_IOS_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$FLUTTER_IOS_PID" 2>/dev/null || true
    fi
    
    if [[ -n "$FLUTTER_ANDROID_PID" ]]; then
        log "DEBUG" "Terminating Flutter Android process (PID: $FLUTTER_ANDROID_PID)"
        kill -TERM "$FLUTTER_ANDROID_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$FLUTTER_ANDROID_PID" 2>/dev/null || true
    fi
    
    # Kill additional Flutter processes
    pkill -f "flutter run" 2>/dev/null || true
    sleep 1
    
    # Only shutdown simulators/emulators if CLEANUP_ON_EXIT is true (CTRL-C pressed)
    if [[ "$CLEANUP_ON_EXIT" == "true" ]]; then
        log "INFO" "🛑 CTRL-C detected - shutting down simulators and emulators..."
        
        # Shutdown iOS Simulator properly
        local booted_ios_id=$(get_booted_ios_simulator_id)
        if [[ -n "$booted_ios_id" ]]; then
            log "DEBUG" "Shutting down iOS Simulator (ID: $booted_ios_id)"
            xcrun simctl shutdown "$booted_ios_id" 2>/dev/null || true
            sleep 2
        fi
        
        # Kill iOS Simulator app process
        if [[ -n "$IOS_SIM_PID" ]]; then
            log "DEBUG" "Terminating iOS Simulator app (PID: $IOS_SIM_PID)"
            kill -TERM "$IOS_SIM_PID" 2>/dev/null || true
            sleep 1
            kill -KILL "$IOS_SIM_PID" 2>/dev/null || true
        fi
        
        # Additional iOS Simulator cleanup
        pkill -f "iOS Simulator" 2>/dev/null || true
        pkill -f "Simulator" 2>/dev/null || true
        
        # Kill Android emulator processes
        if [[ -n "$ANDROID_EMU_PID" ]]; then
            log "DEBUG" "Terminating Android Emulator (PID: $ANDROID_EMU_PID)"
            kill -TERM "$ANDROID_EMU_PID" 2>/dev/null || true
            sleep 3
            kill -KILL "$ANDROID_EMU_PID" 2>/dev/null || true
        fi
        
        # Additional Android emulator cleanup
        pkill -f "qemu-system" 2>/dev/null || true
        pkill -f "emulator" 2>/dev/null || true
        
        log "SUCCESS" "✅ All simulators and emulators shut down"
    else
        log "INFO" "ℹ️  Keeping simulators running (use CTRL-C to shut them down)"
    fi
    
    # Clean Flutter build cache
    cd "$PROJECT_DIR"
    log "DEBUG" "Cleaning Flutter build cache..."
    flutter clean > /dev/null 2>&1 || true
    
    log "SUCCESS" "✅ Cleanup completed - Flutter processes terminated"
    exit 0
}

# Global flag to track if we should cleanup on exit
CLEANUP_ON_EXIT=false

# Signal handlers - only cleanup on SIGINT (CTRL-C) and SIGTERM
cleanup_signal_handler() {
    log "INFO" "📢 Received termination signal - starting cleanup..."
    CLEANUP_ON_EXIT=true
    cleanup
}

# Trap only interrupt signals, not normal exit
trap cleanup_signal_handler SIGINT SIGTERM

# Main execution function
main() {
    log "INFO" "🚀 MarketSnap Development Emulator Script Starting..."
    log "INFO" "📁 Project Directory: $PROJECT_DIR"
    log "INFO" "🔧 Press CTRL+C to stop all processes and cleanup"
    
    # Step 1: Check prerequisites
    check_prerequisites
    
    # Step 2: Clean and prepare project
    prepare_flutter_project
    
    # Step 3: Setup environment
    setup_environment
    
    # Step 4: Check emulators
    check_emulators
    
    # Step 5: Run Flutter Doctor for diagnostics
    log "INFO" "🩺 Running 'flutter doctor -v' for diagnostics..."
    flutter doctor -v
    log "SUCCESS" "✅ Flutter Doctor check completed"
    
    # Step 6: Launch iOS Simulator
    log "INFO" "🍎 Starting iOS Simulator setup..."
    if ! launch_ios_simulator; then
        log "ERROR" "❌ Failed to launch iOS Simulator"
        exit 1
    fi
    
    # Step 7: Launch Android Emulator  
    log "INFO" "🤖 Starting Android Emulator setup..."
    if ! launch_android_emulator; then
        log "ERROR" "❌ Failed to launch Android Emulator"
        exit 1
    fi
    
    # Step 8: Wait for all emulators to be fully ready and Flutter to recognize them
    log "INFO" "⏳ Waiting for Flutter to recognize all devices..."
    sleep 10 # Increased wait time
    
    # Verify Flutter can see both devices
    local max_device_wait=60 # Increased wait time
    local device_wait_count=0
    local ios_detected=false
    local android_detected=false
    
    while [ $device_wait_count -lt $max_device_wait ]; do
        local flutter_devices
        flutter_devices=$(flutter devices 2>/dev/null)
        
        log "DEBUG" "Attempting device recognition ($((device_wait_count+1))/$max_device_wait)..."
        log "DEBUG" "Current flutter devices output:"
        echo "$flutter_devices" | while IFS= read -r line; do
            log "DEBUG" "  $line"
        done

        if echo "$flutter_devices" | grep -q -E "(iOS|iPhone.*Simulator|apple_ios_simulator)"; then
            ios_detected=true
        fi
        
        # Check for Android device using dynamic detection
        local android_device_id=$(get_android_device_id)
        if [[ -n "$android_device_id" ]] && echo "$flutter_devices" | grep -q "$android_device_id"; then
            android_detected=true
        elif echo "$flutter_devices" | grep -q -E "(emulator-|Android SDK)"; then
            android_detected=true
        fi
        
        if $ios_detected && $android_detected; then
            log "SUCCESS" "✅ Flutter detected both iOS and Android devices"
            break
        fi
        
        log "INFO" "⏳ Waiting for Flutter device recognition... iOS: $ios_detected, Android: $android_detected"
        sleep 5
        ((device_wait_count++))
    done
    
    if ! $ios_detected; then
        log "WARNING" "⚠️  Flutter could not detect the iOS Simulator after $max_device_wait seconds."
    fi
    
    if ! $android_detected; then
        log "WARNING" "⚠️  Flutter could not detect the Android Emulator after $max_device_wait seconds."
    fi
    
    # Proceed even if one is not detected, run_flutter will fail with more logs
    
    # Step 9: Deploy Flutter on iOS
    if $ios_detected; then
        log "INFO" "📱 Deploying Flutter app to iOS..."
        run_flutter_ios
    else
        log "ERROR" "❌ Skipping iOS deployment as device was not detected."
    fi
    
    # Step 10: Wait before deploying to Android
    log "INFO" "⏳ Waiting before deploying to Android..."
    sleep 8
    
    # Step 11: Deploy Flutter on Android
    if $android_detected; then
        log "INFO" "🤖 Deploying Flutter app to Android..."
        run_flutter_android
    else
        log "ERROR" "❌ Skipping Android deployment as device was not detected."
    fi
    
    # Step 12: Wait for apps to initialize
    log "INFO" "⏳ Waiting for Flutter apps to initialize..."
    sleep 10
    
    # Step 13: Display connection info
    log "SUCCESS" "🎉 Development environment is up!"
    log "INFO" "📱 iOS Simulator: Check Simulator app"
    log "INFO" "🤖 Android Emulator: $(get_android_device_id || echo "Running")"
    log "INFO" "📝 iOS logs: scripts/flutter_ios.log"
    log "INFO" "📝 Android logs: scripts/flutter_android.log"
    log "INFO" "🔄 Hot reload: Press 'r' in either terminal where flutter is running"
    log "INFO" "🔄 Hot restart: Press 'R' in either terminal where flutter is running"
    log "INFO" "🛑 To stop Flutter apps and emulators: Press CTRL+C"
    
    # Step 14: Monitor processes continuously
    monitor_flutter_processes
}

# Check if script is being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi 