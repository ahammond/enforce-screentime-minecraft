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

# Log using macOS unified logging system
log_info() {
    logger -t "$SCRIPT_NAME" -p user.notice "$1"
}

log_error() {
    logger -t "$SCRIPT_NAME" -p user.error "$1"
}

# Main execution
main() {
    log_info "Checking for Minecraft processes during Screen Time downtime..."

    # Find java processes with minecraft in command line
    # Using grep with bracket trick to exclude grep itself from results
    local minecraft_pids
    minecraft_pids=$(ps aux | grep -i '[j]ava.*minecraft' | awk '{print $2}' || true)

    if [ -z "$minecraft_pids" ]; then
        log_info "No Minecraft processes found - Screen Time rules compliant"
        return 0
    fi

    log_info "Found Minecraft processes bypassing Screen Time: $minecraft_pids"

    # Attempt graceful termination first
    for pid in $minecraft_pids; do
        if ! ps -p "$pid" > /dev/null 2>&1; then
            log_info "Process $pid already terminated"
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
