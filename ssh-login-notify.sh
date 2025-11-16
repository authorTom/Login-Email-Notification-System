#!/bin/bash
#
# SSH Login Email Notification Script
# Sends email alert whenever a user logs in via SSH
# Designed to be triggered by PAM
#

# ============================================================================
# CONFIGURATION
# ============================================================================

# Email settings
EMAIL_TO="admin@example.com"
EMAIL_FROM="ssh-monitor@$(hostname -f)"
EMAIL_SUBJECT="SSH Login Alert: $(hostname)"

# Rate limiting (prevent email spam)
RATE_LIMIT_ENABLED=true
RATE_LIMIT_SECONDS=300  # Only send one email per user per 5 minutes
RATE_LIMIT_DIR="/var/run/ssh-login-notify"

# Logging
LOG_TO_SYSLOG=true
SYSLOG_TAG="ssh-login-notify"

# ============================================================================
# FUNCTIONS
# ============================================================================

log_message() {
    local level="$1"
    local message="$2"

    if [ "$LOG_TO_SYSLOG" = true ]; then
        logger -t "$SYSLOG_TAG" -p "auth.$level" "$message"
    fi
}

check_rate_limit() {
    local username="$1"
    local current_time=$(date +%s)
    local rate_file="$RATE_LIMIT_DIR/$username"

    if [ "$RATE_LIMIT_ENABLED" != true ]; then
        return 0
    fi

    # Create rate limit directory if it doesn't exist
    if [ ! -d "$RATE_LIMIT_DIR" ]; then
        mkdir -p "$RATE_LIMIT_DIR" 2>/dev/null
        chmod 755 "$RATE_LIMIT_DIR" 2>/dev/null
    fi

    # Check if rate limit file exists
    if [ -f "$rate_file" ]; then
        local last_time=$(cat "$rate_file" 2>/dev/null)
        local time_diff=$((current_time - last_time))

        if [ $time_diff -lt $RATE_LIMIT_SECONDS ]; then
            log_message "info" "Rate limit active for user $username (${time_diff}s since last email)"
            return 1
        fi
    fi

    # Update rate limit timestamp
    echo "$current_time" > "$rate_file" 2>/dev/null
    return 0
}

get_login_info() {
    # Gather information about the login
    USERNAME="${PAM_USER:-$USER}"
    USER_ID=$(id -u "$USERNAME" 2>/dev/null || echo "unknown")
    LOGIN_TIME=$(date '+%Y-%m-%d %H:%M:%S %Z')
    LOGIN_TIMESTAMP=$(date '+%s')
    HOSTNAME=$(hostname -f)

    # Get SSH connection information
    if [ -n "$PAM_RHOST" ]; then
        SOURCE_IP="$PAM_RHOST"
    elif [ -n "$SSH_CONNECTION" ]; then
        SOURCE_IP=$(echo "$SSH_CONNECTION" | awk '{print $1}')
    else
        SOURCE_IP="unknown"
    fi

    # Try to resolve hostname from IP
    if [ "$SOURCE_IP" != "unknown" ] && [ -n "$SOURCE_IP" ]; then
        SOURCE_HOST=$(host "$SOURCE_IP" 2>/dev/null | awk '{print $NF}' | sed 's/\.$//')
        if [ -z "$SOURCE_HOST" ] || [ "$SOURCE_HOST" = "3(NXDOMAIN)" ]; then
            SOURCE_HOST="$SOURCE_IP"
        fi
    else
        SOURCE_HOST="unknown"
    fi

    # Get SSH client details
    if [ -n "$SSH_CLIENT" ]; then
        SSH_PORT=$(echo "$SSH_CLIENT" | awk '{print $3}')
    else
        SSH_PORT="unknown"
    fi

    # Get terminal info
    TERMINAL="${PAM_TTY:-${SSH_TTY:-unknown}}"

    # Get authentication method (if available)
    AUTH_METHOD="unknown"
    if [ -n "$PAM_TYPE" ]; then
        AUTH_METHOD="$PAM_TYPE"
    fi
}

send_email() {
    # Check if mail command is available
    if ! command -v mail >/dev/null 2>&1 && ! command -v sendmail >/dev/null 2>&1; then
        log_message "error" "No mail utility found (mail or sendmail required)"
        return 1
    fi

    # Compose email body
    local email_body=$(cat <<EOF
SSH Login Detected
==================

Server Information:
-------------------
Hostname: $HOSTNAME
Time: $LOGIN_TIME

User Information:
-----------------
Username: $USERNAME
User ID: $USER_ID
Terminal: $TERMINAL

Connection Details:
-------------------
Source IP: $SOURCE_IP
Source Host: $SOURCE_HOST
SSH Port: $SSH_PORT
Auth Method: $AUTH_METHOD

---
This is an automated security notification.
If this login was unauthorized, please investigate immediately.
EOF
)

    # Send email using available mail utility
    if command -v mail >/dev/null 2>&1; then
        echo "$email_body" | mail -s "$EMAIL_SUBJECT - User: $USERNAME from $SOURCE_IP" \
            -a "From: $EMAIL_FROM" "$EMAIL_TO" 2>/dev/null
    elif command -v sendmail >/dev/null 2>&1; then
        (
            echo "To: $EMAIL_TO"
            echo "From: $EMAIL_FROM"
            echo "Subject: $EMAIL_SUBJECT - User: $USERNAME from $SOURCE_IP"
            echo ""
            echo "$email_body"
        ) | sendmail -t 2>/dev/null
    fi

    local status=$?
    if [ $status -eq 0 ]; then
        log_message "info" "Email sent successfully for user $USERNAME from $SOURCE_IP"
        return 0
    else
        log_message "error" "Failed to send email for user $USERNAME (exit code: $status)"
        return 1
    fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
    # Run in background to not delay login
    (
        # Gather login information
        get_login_info

        # Log the login attempt
        log_message "info" "SSH login detected: user=$USERNAME, source=$SOURCE_IP, host=$SOURCE_HOST"

        # Check rate limit
        if ! check_rate_limit "$USERNAME"; then
            exit 0
        fi

        # Send email notification
        send_email

    ) &

    # Don't wait for background process
    disown
}

# Execute main function
main

exit 0
