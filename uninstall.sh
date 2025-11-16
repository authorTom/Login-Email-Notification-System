#!/bin/bash
#
# Uninstallation Script for SSH Login Email Notification
#
# This script removes the SSH login notification system
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_NAME="ssh-login-notify.sh"
INSTALL_PATH="/usr/local/bin/$SCRIPT_NAME"
PAM_CONFIG="/etc/pam.d/sshd"
RATE_LIMIT_DIR="/var/run/ssh-login-notify"

# ============================================================================
# FUNCTIONS
# ============================================================================

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

confirm_uninstall() {
    echo ""
    print_warning "This will remove the SSH login notification system."
    print_warning "You will no longer receive email alerts for SSH logins."
    echo ""
    read -p "Are you sure you want to continue? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstall cancelled"
        exit 0
    fi
}

remove_pam_config() {
    print_info "Removing PAM configuration..."

    if [ ! -f "$PAM_CONFIG" ]; then
        print_warning "PAM config not found: $PAM_CONFIG"
        return 0
    fi

    # Backup before modification
    local backup="$PAM_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$PAM_CONFIG" "$backup"
    print_info "PAM config backed up to: $backup"

    # Remove ssh-login-notify lines
    if grep -q "ssh-login-notify" "$PAM_CONFIG"; then
        sed -i '/ssh-login-notify/d' "$PAM_CONFIG"
        # Remove empty lines and comment lines left behind
        sed -i '/^# SSH Login Email Notification$/d' "$PAM_CONFIG"
        print_info "PAM configuration removed"
    else
        print_warning "No ssh-login-notify configuration found in PAM"
    fi
}

remove_script() {
    print_info "Removing notification script..."

    if [ -f "$INSTALL_PATH" ]; then
        rm -f "$INSTALL_PATH"
        print_info "Script removed: $INSTALL_PATH"
    else
        print_warning "Script not found: $INSTALL_PATH"
    fi
}

remove_rate_limit_dir() {
    print_info "Removing rate limit directory..."

    if [ -d "$RATE_LIMIT_DIR" ]; then
        rm -rf "$RATE_LIMIT_DIR"
        print_info "Rate limit directory removed: $RATE_LIMIT_DIR"
    else
        print_warning "Rate limit directory not found: $RATE_LIMIT_DIR"
    fi
}

clean_logs() {
    print_info "Cleaning up log entries..."

    # Note: We don't actually remove syslog entries as they're part of system logs
    # Just inform the user
    print_info "Log entries remain in syslog for audit purposes"
    print_info "To view past notifications: grep ssh-login-notify /var/log/auth.log"
}

print_summary() {
    echo ""
    echo "============================================================================"
    print_info "Uninstallation Complete!"
    echo "============================================================================"
    echo ""
    print_info "Removed components:"
    echo "  - Notification script"
    echo "  - PAM configuration"
    echo "  - Rate limit directory"
    echo ""
    print_info "SSH logins will no longer trigger email notifications"
    echo ""
    print_info "To reinstall, run: sudo ./install.sh"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "============================================================================"
    echo "SSH Login Email Notification - Uninstallation Script"
    echo "============================================================================"

    check_root
    confirm_uninstall
    remove_pam_config
    remove_script
    remove_rate_limit_dir
    clean_logs
    print_summary
}

# Execute main function
main

exit 0
