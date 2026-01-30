#!/bin/bash
# install.sh - Idempotent installer for enforce-screentime-minecraft
# Usage: curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash
# Usage: curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash -s -- --time=20:30

set -euo pipefail

# Configuration
readonly GITHUB_RAW_BASE="${GITHUB_RAW_BASE:-https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main}"
readonly SCRIPT_NAME="enforce-screentime-minecraft.sh"
readonly PLIST_NAME="com.user.enforce-screentime-minecraft.plist"
readonly INSTALL_DIR="/usr/local/bin"
readonly LAUNCHD_DIR="/Library/LaunchDaemons"
readonly SCRIPT_PATH="${INSTALL_DIR}/${SCRIPT_NAME}"
readonly PLIST_PATH="${LAUNCHD_DIR}/${PLIST_NAME}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Default shutdown time (7:05 PM)
# These will be overridden if an existing installation is found
SHUTDOWN_HOUR=19
SHUTDOWN_MINUTE=5

# Check if there's an existing installation and preserve the configured time
preserve_existing_time() {
    if [[ -f "$PLIST_PATH" ]]; then
        # Extract current hour and minute from existing plist
        local current_hour current_minute
        current_hour=$(sed -n '/<key>Hour<\/key>/{n;s/.*<integer>\([0-9]*\)<\/integer>.*/\1/p;}' "$PLIST_PATH")
        current_minute=$(sed -n '/<key>Minute<\/key>/{n;s/.*<integer>\([0-9]*\)<\/integer>.*/\1/p;}' "$PLIST_PATH")

        if [[ -n "$current_hour" && -n "$current_minute" ]]; then
            SHUTDOWN_HOUR=$current_hour
            SHUTDOWN_MINUTE=$current_minute
            log_info "Found existing installation with time ${SHUTDOWN_HOUR}:$(printf "%02d" $SHUTDOWN_MINUTE)"
            log_info "Preserving your configured time (use --time=HH:MM to change it)"
        fi
    fi
}

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

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --time=*)
                local time="${1#*=}"
                if [[ $time =~ ^([0-9]{1,2}):([0-9]{2})$ ]]; then
                    SHUTDOWN_HOUR="${BASH_REMATCH[1]}"
                    SHUTDOWN_MINUTE="${BASH_REMATCH[2]}"

                    # Validate hour (0-23) and minute (0-59)
                    if ((SHUTDOWN_HOUR < 0 || SHUTDOWN_HOUR > 23)); then
                        log_error "Hour must be between 0 and 23"
                        exit 1
                    fi
                    if ((SHUTDOWN_MINUTE < 0 || SHUTDOWN_MINUTE > 59)); then
                        log_error "Minute must be between 0 and 59"
                        exit 1
                    fi
                else
                    log_error "Invalid time format. Use --time=HH:MM (e.g., --time=19:05)"
                    exit 1
                fi
                shift
                ;;
            --hour=*)
                SHUTDOWN_HOUR="${1#*=}"
                if ((SHUTDOWN_HOUR < 0 || SHUTDOWN_HOUR > 23)); then
                    log_error "Hour must be between 0 and 23"
                    exit 1
                fi
                shift
                ;;
            --minute=*)
                SHUTDOWN_MINUTE="${1#*=}"
                if ((SHUTDOWN_MINUTE < 0 || SHUTDOWN_MINUTE > 59)); then
                    log_error "Minute must be between 0 and 59"
                    exit 1
                fi
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Enforce Screen Time for Minecraft - Installer

Usage:
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash -s -- --time=20:30

Options:
  --time=HH:MM     Set shutdown time (24-hour format, default: 19:05)
  --hour=HH        Set shutdown hour (0-23, default: 19)
  --minute=MM      Set shutdown minute (0-59, default: 5)
  -h, --help       Show this help message

Examples:
  # Install with default time (7:05 PM)
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash

  # Install with custom time (8:30 PM)
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash -s -- --time=20:30

  # Update existing installation, do not change configured time
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash

  # Update existing installation
  curl -fsSL https://raw.githubusercontent.com/ahammond/enforce-screentime-minecraft/main/install.sh | sudo bash -s -- --time=21:00
EOF
}

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

# Download file from GitHub
download_file() {
    local filename=$1
    local url="${GITHUB_RAW_BASE}/${filename}"
    local temp_file
    temp_file=$(mktemp)

    log_info "Downloading ${filename}..." >&2
    if curl -fsSL "$url" -o "$temp_file"; then
        echo "$temp_file"
        return 0
    else
        log_error "Failed to download ${filename} from ${url}"
        rm -f "$temp_file"
        return 1
    fi
}

# Check if launchd job is currently loaded
is_loaded() {
    launchctl list | grep -q "com.user.enforce-screentime-minecraft"
}

# Install or update the script
install_script() {
    local temp_script
    temp_script=$(download_file "$SCRIPT_NAME")

    if [[ -f "$SCRIPT_PATH" ]]; then
        log_info "Updating existing script..."
    else
        log_info "Installing script..."
    fi

    mv "$temp_script" "$SCRIPT_PATH"
    chmod +x "$SCRIPT_PATH"
    chown root:wheel "$SCRIPT_PATH"

    log_info "Script installed to ${SCRIPT_PATH}"
}

# Install or update the plist
install_plist() {
    local temp_plist
    temp_plist=$(download_file "$PLIST_NAME")

    # Replace time placeholders
    sed -i '' "s/__HOUR__/${SHUTDOWN_HOUR}/g" "$temp_plist"
    sed -i '' "s/__MINUTE__/${SHUTDOWN_MINUTE}/g" "$temp_plist"

    local was_loaded=false
    if [[ -f "$PLIST_PATH" ]]; then
        log_info "Updating existing launchd configuration..."
        if is_loaded; then
            was_loaded=true
            log_info "Unloading current configuration..."
            launchctl unload "$PLIST_PATH" 2>/dev/null || true
        fi
    else
        log_info "Installing launchd configuration..."
    fi

    mv "$temp_plist" "$PLIST_PATH"
    chown root:wheel "$PLIST_PATH"
    chmod 644 "$PLIST_PATH"

    log_info "Loading launchd configuration..."
    launchctl load "$PLIST_PATH"

    log_info "Configuration installed to ${PLIST_PATH}"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."

    if [[ ! -f "$SCRIPT_PATH" ]]; then
        log_error "Script not found at ${SCRIPT_PATH}"
        return 1
    fi

    if [[ ! -x "$SCRIPT_PATH" ]]; then
        log_error "Script is not executable"
        return 1
    fi

    if [[ ! -f "$PLIST_PATH" ]]; then
        log_error "Plist not found at ${PLIST_PATH}"
        return 1
    fi

    if ! is_loaded; then
        log_error "Launchd job is not loaded"
        return 1
    fi

    log_info "Installation verified successfully"
    return 0
}

# Show completion message
show_completion() {
    local hour_12
    local ampm

    # Convert to 12-hour format for display
    if ((SHUTDOWN_HOUR == 0)); then
        hour_12=12
        ampm="AM"
    elif ((SHUTDOWN_HOUR < 12)); then
        hour_12=$SHUTDOWN_HOUR
        ampm="AM"
    elif ((SHUTDOWN_HOUR == 12)); then
        hour_12=12
        ampm="PM"
    else
        hour_12=$((SHUTDOWN_HOUR - 12))
        ampm="PM"
    fi

    echo
    echo -e "${GREEN}✓${NC} Installation complete!"
    echo
    echo "Minecraft will be terminated at ${hour_12}:$(printf "%02d" $SHUTDOWN_MINUTE) ${ampm} (${SHUTDOWN_HOUR}:$(printf "%02d" $SHUTDOWN_MINUTE)) daily."
    cat << EOF

Next steps:
  • Test the script: sudo ${SCRIPT_PATH}
  • View logs: log show --predicate 'eventMessage contains "screentime-enforce"' --last 1h
  • Update time: Re-run installer with --time=HH:MM
  • Temporarily disable: sudo launchctl unload ${PLIST_PATH}
  • Re-enable: sudo launchctl load ${PLIST_PATH}

For more information: https://github.com/ahammond/enforce-screentime-minecraft
EOF
}

# Main installation flow
main() {
    check_root
    preserve_existing_time  # Check for existing time before parsing args
    parse_args "$@"         # Command line args override preserved time

    log_info "Starting enforce-screentime-minecraft installation..."
    log_info "Shutdown time: ${SHUTDOWN_HOUR}:$(printf "%02d" $SHUTDOWN_MINUTE)"

    install_script
    install_plist
    verify_installation
    show_completion
}

# Run main function
main "$@"
