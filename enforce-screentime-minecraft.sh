#!/bin/bash
# enforce-screentime-minecraft.sh
# Enforce Screen Time downtime rules for Minecraft Java Edition
#
# Minecraft Java Edition runs in the Java Virtual Machine and bypasses
# macOS Screen Time controls. This script terminates Minecraft processes
# to enforce parental control settings like other apps on the system.

set -euo pipefail

# Configuration
readonly SCRIPT_NAME="screentime-enforce"
readonly GRACE_PERIOD=2  # seconds to wait before force termination
readonly ENFORCEMENT_WINDOW_HOURS=6  # Only enforce within this many hours after scheduled time

# Log using macOS unified logging system
log_info() {
    logger -t "$SCRIPT_NAME" -p user.notice "$1"
}

log_error() {
    logger -t "$SCRIPT_NAME" -p user.error "$1"
}

# Check if we're within the enforcement window
# This prevents terminating Minecraft the next morning if the system was asleep during shutdown time
check_enforcement_window() {
    # Get the scheduled hour and minute from the plist
    local plist_path="/Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist"

    if [[ ! -f "$plist_path" ]]; then
        log_error "Configuration file not found: $plist_path"
        return 1
    fi

    local scheduled_hour scheduled_minute

    # Use plutil for reliable XML parsing
    scheduled_hour=$(plutil -extract StartCalendarInterval.Hour raw "$plist_path" 2>/dev/null)
    scheduled_minute=$(plutil -extract StartCalendarInterval.Minute raw "$plist_path" 2>/dev/null)

    if [[ -z "$scheduled_hour" || -z "$scheduled_minute" ]]; then
        log_error "Could not read scheduled time from $plist_path"
        return 1
    fi

    # Get current time
    local current_hour current_minute
    current_hour=$(date +%H)
    current_minute=$(date +%M)

    # Convert times to minutes since midnight for easier comparison
    local scheduled_minutes current_minutes
    scheduled_minutes=$((10#$scheduled_hour * 60 + 10#$scheduled_minute))
    current_minutes=$((10#$current_hour * 60 + 10#$current_minute))

    # Calculate the enforcement window (scheduled time to scheduled time + ENFORCEMENT_WINDOW_HOURS)
    local window_end_minutes
    window_end_minutes=$((scheduled_minutes + ENFORCEMENT_WINDOW_HOURS * 60))

    # Check if current time is within the window
    # Handle wraparound past midnight
    if ((window_end_minutes >= 1440)); then
        # Window extends past midnight
        if ((current_minutes >= scheduled_minutes || current_minutes < (window_end_minutes - 1440))); then
            log_info "Current time ($current_hour:$(printf "%02d" $current_minute)) is within enforcement window (${scheduled_hour}:$(printf "%02d" $scheduled_minute) + ${ENFORCEMENT_WINDOW_HOURS}h)"
            return 0
        fi
    else
        # Normal case: window doesn't cross midnight
        if ((current_minutes >= scheduled_minutes && current_minutes < window_end_minutes)); then
            log_info "Current time ($current_hour:$(printf "%02d" $current_minute)) is within enforcement window (${scheduled_hour}:$(printf "%02d" $scheduled_minute) + ${ENFORCEMENT_WINDOW_HOURS}h)"
            return 0
        fi
    fi

    log_info "Current time ($current_hour:$(printf "%02d" $current_minute)) is outside enforcement window (${scheduled_hour}:$(printf "%02d" $scheduled_minute) + ${ENFORCEMENT_WINDOW_HOURS}h) - skipping enforcement"
    return 1
}

# Main execution
main() {
    log_info "Checking for Minecraft processes during Screen Time downtime..."

    # Check if we're within the enforcement window
    if ! check_enforcement_window; then
        log_info "Outside enforcement window - exiting without action"
        return 0
    fi

    # Find java processes with minecraft in command line
    # Using grep with bracket trick to exclude grep itself from results
    local minecraft_pids
    minecraft_pids=$(ps aux | grep -i '[j]ava.*minecraft' | awk '{print $2}' || true)

    if [ -z "$minecraft_pids" ]; then
        log_info "No Minecraft processes found - Screen Time rules compliant"
        return 0
    fi

    log_info "Found potential Minecraft processes: $minecraft_pids"

    # Validate and process each PID
    for pid in $minecraft_pids; do
        # Validate PID is numeric
        if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
            log_error "Invalid PID format detected: $pid - skipping"
            continue
        fi

        # Verify process still exists and is a Java process
        if ! ps -p "$pid" > /dev/null 2>&1; then
            log_info "Process $pid already terminated"
            continue
        fi

        if ! ps -p "$pid" -o comm= 2>/dev/null | grep -q java; then
            log_info "Process $pid is not a Java process - skipping"
            continue
        fi

        log_info "Terminating Minecraft process $pid (graceful)"
        if kill "$pid" 2>/dev/null; then
            log_info "Termination signal sent successfully to $pid"
        else
            log_error "Failed to send termination signal to $pid"
            continue
        fi

        # Wait for graceful termination
        sleep "$GRACE_PERIOD"

        # Check if still running, force termination if needed
        if ps -p "$pid" > /dev/null 2>&1; then
            log_info "Process $pid still running, forcing termination"
            if kill -9 "$pid" 2>/dev/null; then
                log_info "Process $pid terminated successfully"
            else
                log_error "Failed to terminate process $pid"
            fi
        else
            log_info "Process $pid terminated gracefully"
        fi
    done

    log_info "Screen Time enforcement complete - Minecraft terminated"
    return 0
}

# Execute main function
main
exit $?
