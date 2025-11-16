#!/bin/bash
#
# Installation Script for SSH Login Email Notification
#
# This script automates the installation and configuration of the
# SSH login notification system using PAM.
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
PAM_BACKUP="/etc/pam.d/sshd.backup.$(date +%Y%m%d_%H%M%S)"
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

check_mail_utility() {
    print_info "Checking for mail utilities..."

    if command -v mail >/dev/null 2>&1; then
        print_info "Found 'mail' utility"
        return 0
    elif command -v sendmail >/dev/null 2>&1; then
        print_info "Found 'sendmail' utility"
        return 0
    else
        print_warning "No mail utility found!"
        print_warning "Please install one of the following:"
        print_warning "  - Debian/Ubuntu: sudo apt-get install mailutils"
        print_warning "  - RHEL/CentOS: sudo yum install mailx"
        print_warning "  - Fedora: sudo dnf install mailx"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

configure_email() {
    print_info "Email configuration"
    echo ""

    read -p "Enter recipient email address: " EMAIL_TO

    if [ -z "$EMAIL_TO" ]; then
        print_error "Email address is required"
        exit 1
    fi

    read -p "Enter 'from' email address [ssh-monitor@$(hostname -f)]: " EMAIL_FROM
    if [ -z "$EMAIL_FROM" ]; then
        EMAIL_FROM="ssh-monitor@$(hostname -f)"
    fi

    read -p "Enable rate limiting? (Y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        RATE_LIMIT_ENABLED="false"
    else
        RATE_LIMIT_ENABLED="true"
        read -p "Rate limit seconds [300]: " RATE_LIMIT_SECONDS
        if [ -z "$RATE_LIMIT_SECONDS" ]; then
            RATE_LIMIT_SECONDS=300
        fi
    fi

    print_info "Configuration:"
    print_info "  Recipient: $EMAIL_TO"
    print_info "  From: $EMAIL_FROM"
    print_info "  Rate limiting: $RATE_LIMIT_ENABLED"
    if [ "$RATE_LIMIT_ENABLED" = "true" ]; then
        print_info "  Rate limit: ${RATE_LIMIT_SECONDS}s"
    fi
    echo ""
}

update_script_config() {
    print_info "Updating script configuration..."

    sed -i "s/^EMAIL_TO=.*/EMAIL_TO=\"$EMAIL_TO\"/" "$SCRIPT_NAME"
    sed -i "s/^EMAIL_FROM=.*/EMAIL_FROM=\"$EMAIL_FROM\"/" "$SCRIPT_NAME"
    sed -i "s/^RATE_LIMIT_ENABLED=.*/RATE_LIMIT_ENABLED=$RATE_LIMIT_ENABLED/" "$SCRIPT_NAME"
    sed -i "s/^RATE_LIMIT_SECONDS=.*/RATE_LIMIT_SECONDS=$RATE_LIMIT_SECONDS/" "$SCRIPT_NAME"
}

install_script() {
    print_info "Installing notification script to $INSTALL_PATH..."

    if [ ! -f "$SCRIPT_NAME" ]; then
        print_error "Script file '$SCRIPT_NAME' not found in current directory"
        exit 1
    fi

    cp "$SCRIPT_NAME" "$INSTALL_PATH"
    chmod 755 "$INSTALL_PATH"
    chown root:root "$INSTALL_PATH"

    print_info "Script installed successfully"
}

configure_pam() {
    print_info "Configuring PAM for SSH notifications..."

    if [ ! -f "$PAM_CONFIG" ]; then
        print_error "PAM SSH config not found: $PAM_CONFIG"
        exit 1
    fi

    # Backup PAM config
    print_info "Backing up PAM config to $PAM_BACKUP..."
    cp "$PAM_CONFIG" "$PAM_BACKUP"

    # Check if already configured
    if grep -q "ssh-login-notify.sh" "$PAM_CONFIG"; then
        print_warning "PAM already configured for ssh-login-notify.sh"
        read -p "Reconfigure? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 0
        fi
        # Remove old configuration
        sed -i '/ssh-login-notify.sh/d' "$PAM_CONFIG"
    fi

    # Add PAM configuration
    echo "" >> "$PAM_CONFIG"
    echo "# SSH Login Email Notification" >> "$PAM_CONFIG"
    echo "session optional pam_exec.so seteuid $INSTALL_PATH" >> "$PAM_CONFIG"

    print_info "PAM configuration updated"
}

create_rate_limit_dir() {
    if [ "$RATE_LIMIT_ENABLED" = "true" ]; then
        print_info "Creating rate limit directory..."
        mkdir -p "$RATE_LIMIT_DIR"
        chmod 755 "$RATE_LIMIT_DIR"
    fi
}

test_notification() {
    print_info "Testing notification..."
    echo ""
    read -p "Send a test email? (Y/n): " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        return 0
    fi

    print_info "Executing test notification (check your email)..."
    sudo -u $SUDO_USER PAM_USER="$SUDO_USER" PAM_RHOST="127.0.0.1" "$INSTALL_PATH"

    print_info "Test notification sent. Check your email at $EMAIL_TO"
}

print_summary() {
    echo ""
    echo "============================================================================"
    print_info "Installation Complete!"
    echo "============================================================================"
    echo ""
    print_info "Next Steps:"
    echo "  1. Verify mail is configured and working on this server"
    echo "  2. SSH logins will now trigger email notifications to: $EMAIL_TO"
    echo "  3. Test by logging in via SSH from another terminal"
    echo "  4. Check logs: sudo grep ssh-login-notify /var/log/auth.log"
    echo ""
    print_info "Configuration Files:"
    echo "  - Script: $INSTALL_PATH"
    echo "  - PAM config: $PAM_CONFIG"
    echo "  - PAM backup: $PAM_BACKUP"
    if [ "$RATE_LIMIT_ENABLED" = "true" ]; then
        echo "  - Rate limit dir: $RATE_LIMIT_DIR"
    fi
    echo ""
    print_info "To modify email settings, edit: $INSTALL_PATH"
    echo ""
    print_warning "Important: Ensure your mail system is configured correctly!"
    print_warning "Test with: echo 'test' | mail -s 'Test' $EMAIL_TO"
    echo ""
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    echo "============================================================================"
    echo "SSH Login Email Notification - Installation Script"
    echo "============================================================================"
    echo ""

    check_root
    check_mail_utility
    configure_email
    update_script_config
    install_script
    create_rate_limit_dir
    configure_pam
    test_notification
    print_summary
}

# Execute main function
main

exit 0
