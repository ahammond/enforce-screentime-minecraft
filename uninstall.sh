#!/bin/bash
# uninstall.sh - Uninstaller for enforce-screentime-minecraft
# Usage: curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/uninstall.sh | sudo bash

set -euo pipefail

# File locations
readonly PLIST_PATH="/Library/LaunchDaemons/com.user.enforce-screentime-minecraft.plist"
readonly SCRIPT_PATH="/usr/local/bin/enforce-screentime-minecraft.sh"
readonly SERVICE_LABEL="com.user.enforce-screentime-minecraft"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}==>${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}Warning:${NC} $1"
}

log_error() {
    echo -e "${RED}Error:${NC} $1" >&2
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Check if service is loaded
is_loaded() {
    launchctl list | grep -q "$SERVICE_LABEL"
}

# Unload the LaunchDaemon
unload_daemon() {
    log_info "Checking if Screen Time enforcement is active..."

    if is_loaded; then
        log_info "Stopping Screen Time enforcement..."
        if launchctl bootout system "$PLIST_PATH" 2>/dev/null; then
            log_info "Enforcement stopped successfully"
        else
            log_warn "Could not stop enforcement (it may not be running)"
        fi
    else
        log_info "Enforcement is not currently running"
    fi
}

# Remove the plist file
remove_plist() {
    log_info "Removing configuration file..."

    if [[ -f "$PLIST_PATH" ]]; then
        if rm "$PLIST_PATH"; then
            log_info "Configuration file removed"
        else
            log_error "Failed to remove configuration file: $PLIST_PATH"
            return 1
        fi
    else
        log_info "Configuration file not found (already removed?)"
    fi
}

# Remove the script
remove_script() {
    log_info "Removing enforcement script..."

    if [[ -f "$SCRIPT_PATH" ]]; then
        if rm "$SCRIPT_PATH"; then
            log_info "Enforcement script removed"
        else
            log_error "Failed to remove script: $SCRIPT_PATH"
            return 1
        fi
    else
        log_info "Enforcement script not found (already removed?)"
    fi
}

# Verify uninstallation
verify_uninstall() {
    log_info "Verifying uninstallation..."

    local errors=0

    if is_loaded; then
        log_error "Enforcement is still loaded in the system"
        errors=$((errors + 1))
    fi

    if [[ -f "$PLIST_PATH" ]]; then
        log_error "Configuration file still exists: $PLIST_PATH"
        errors=$((errors + 1))
    fi

    if [[ -f "$SCRIPT_PATH" ]]; then
        log_error "Script file still exists: $SCRIPT_PATH"
        errors=$((errors + 1))
    fi

    if [[ $errors -eq 0 ]]; then
        log_info "Uninstallation verified successfully"
        return 0
    else
        log_error "Uninstallation incomplete - $errors issue(s) found"
        return 1
    fi
}

# Show completion message
show_completion() {
    cat << EOF

${GREEN}✓${NC} Uninstallation complete!

Screen Time enforcement has been removed from your system.
Minecraft will no longer be automatically shut down.

If you want to reinstall:
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash

For more information: https://github.com/ahammond/enforce-screentime-minecraft
EOF
}

# Main uninstallation flow
main() {
    check_root

    echo
    log_info "Starting Screen Time enforcement uninstallation..."
    echo

    unload_daemon
    remove_plist
    remove_script

    if verify_uninstall; then
        show_completion
        exit 0
    else
        echo
        log_error "Uninstallation completed with errors"
        log_error "Some files may need to be removed manually"
        exit 1
    fi
}

# Run main function
main "$@"
