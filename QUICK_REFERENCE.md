# Quick Reference Guide

Quick commands and snippets for managing SSH Login Email Notifications.

## Installation

```bash
# Quick install
chmod +x install.sh && sudo ./install.sh

# Manual install
sudo cp ssh-login-notify.sh /usr/local/bin/
sudo chmod 755 /usr/local/bin/ssh-login-notify.sh
echo "session optional pam_exec.so seteuid /usr/local/bin/ssh-login-notify.sh" | sudo tee -a /etc/pam.d/sshd
```

## Testing

```bash
# Test email system
echo "Test" | mail -s "Test" admin@example.com

# Test notification script manually
sudo PAM_USER="$USER" PAM_RHOST="127.0.0.1" /usr/local/bin/ssh-login-notify.sh

# Test via actual SSH login
ssh user@localhost
```

## Monitoring

```bash
# Watch notifications in real-time
sudo tail -f /var/log/auth.log | grep ssh-login-notify

# View recent notifications
sudo grep ssh-login-notify /var/log/auth.log | tail -20

# Check mail queue
mailq

# View mail logs
sudo tail -f /var/log/mail.log
```

## Configuration Changes

```bash
# Edit configuration
sudo nano /usr/local/bin/ssh-login-notify.sh

# Test configuration syntax
bash -n /usr/local/bin/ssh-login-notify.sh

# View current PAM configuration
grep ssh-login /etc/pam.d/sshd
```

## Rate Limiting

```bash
# View rate limit status
ls -ltr /var/run/ssh-login-notify/

# Clear rate limits (force new emails)
sudo rm -rf /var/run/ssh-login-notify/*

# Disable rate limiting temporarily
sudo sed -i 's/RATE_LIMIT_ENABLED=true/RATE_LIMIT_ENABLED=false/' /usr/local/bin/ssh-login-notify.sh
```

## Troubleshooting

```bash
# Check if PAM line exists
grep -n ssh-login-notify /etc/pam.d/sshd

# Verify script exists and is executable
ls -l /usr/local/bin/ssh-login-notify.sh

# Check script permissions
stat /usr/local/bin/ssh-login-notify.sh

# View PAM errors
sudo grep pam_exec /var/log/auth.log

# Debug mode (add to PAM line)
# session optional pam_exec.so debug seteuid /usr/local/bin/ssh-login-notify.sh
```

## Common Modifications

### Change Email Address

```bash
sudo sed -i 's/EMAIL_TO=.*/EMAIL_TO="newemail@example.com"/' /usr/local/bin/ssh-login-notify.sh
```

### Change Rate Limit Time

```bash
# Change to 10 minutes (600 seconds)
sudo sed -i 's/RATE_LIMIT_SECONDS=.*/RATE_LIMIT_SECONDS=600/' /usr/local/bin/ssh-login-notify.sh
```

### Disable for Specific User

Add to script after line `main() {`:
```bash
[ "$PAM_USER" == "ignored_user" ] && exit 0
```

### Multiple Email Recipients

```bash
sudo sed -i 's/EMAIL_TO=.*/EMAIL_TO="admin@example.com,security@example.com"/' /usr/local/bin/ssh-login-notify.sh
```

## Backup & Restore

```bash
# Backup PAM configuration
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup.$(date +%Y%m%d)

# Restore PAM configuration
sudo cp /etc/pam.d/sshd.backup.YYYYMMDD /etc/pam.d/sshd

# Backup notification script
sudo cp /usr/local/bin/ssh-login-notify.sh /root/ssh-login-notify.sh.backup
```

## Disable/Enable

```bash
# Disable temporarily (comment out PAM line)
sudo sed -i '/ssh-login-notify/s/^/# /' /etc/pam.d/sshd

# Re-enable (uncomment PAM line)
sudo sed -i '/ssh-login-notify/s/^# //' /etc/pam.d/sshd

# Disable permanently
sudo ./uninstall.sh
```

## Performance Monitoring

```bash
# Count notifications sent today
sudo grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep -c "Email sent successfully"

# Find most frequent login IPs
sudo grep ssh-login-notify /var/log/auth.log | grep -oP 'source=\K[0-9.]+' | sort | uniq -c | sort -rn | head

# Check for email failures
sudo grep "Failed to send email" /var/log/auth.log
```

## Integration Examples

### Add Slack Notification

Add to `send_email()` function:
```bash
SLACK_WEBHOOK="https://hooks.slack.com/services/YOUR/WEBHOOK"
curl -s -X POST "$SLACK_WEBHOOK" -H 'Content-Type: application/json' \
  -d "{\"text\":\"SSH: $USERNAME @ $SOURCE_IP -> $HOSTNAME\"}" &
```

### Add Telegram Notification

```bash
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"
MESSAGE="SSH Login: $USERNAME from $SOURCE_IP on $HOSTNAME"
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$TELEGRAM_CHAT_ID&text=$MESSAGE" &
```

### Log to Custom File

```bash
echo "$(date) - $USERNAME logged in from $SOURCE_IP" >> /var/log/ssh-logins.log
```

## System Service Commands

```bash
# Restart SSH (if needed after PAM changes)
sudo systemctl restart sshd

# Check SSH status
sudo systemctl status sshd

# View SSH service logs
sudo journalctl -u sshd -f
```

## Uninstallation

```bash
# Quick uninstall
sudo ./uninstall.sh

# Manual uninstall
sudo sed -i '/ssh-login-notify/d' /etc/pam.d/sshd
sudo rm -f /usr/local/bin/ssh-login-notify.sh
sudo rm -rf /var/run/ssh-login-notify
```

## Common Issues & Fixes

### Issue: No emails received

```bash
# Check mail configuration
echo "Test" | mail -s "Test" $EMAIL_TO

# Check script execution
sudo grep "Email sent" /var/log/auth.log

# Verify PAM is triggering script
sudo grep pam_exec /var/log/auth.log
```

### Issue: Permission denied

```bash
# Fix script permissions
sudo chmod 755 /usr/local/bin/ssh-login-notify.sh
sudo chown root:root /usr/local/bin/ssh-login-notify.sh

# Fix rate limit directory
sudo mkdir -p /var/run/ssh-login-notify
sudo chmod 755 /var/run/ssh-login-notify
```

### Issue: Rate limiting too aggressive

```bash
# Increase rate limit time or disable
sudo nano /usr/local/bin/ssh-login-notify.sh
# Change RATE_LIMIT_SECONDS or set RATE_LIMIT_ENABLED=false
```

### Issue: Emails delayed

```bash
# Check mail queue
mailq

# Force mail queue processing (postfix)
sudo postfix flush

# Check mail server status
sudo systemctl status postfix
```

## Security Commands

```bash
# View failed login attempts
sudo grep "Failed password" /var/log/auth.log | tail -20

# Block an IP (using firewall)
sudo ufw deny from 203.0.113.42

# Check active SSH sessions
who
w

# View SSH login history
last | head -20

# Monitor live SSH connections
sudo watch -n 1 'ss -tn | grep :22'
```

## Useful Logs

```bash
# SSH authentication logs
/var/log/auth.log         # Debian/Ubuntu
/var/log/secure           # RHEL/CentOS

# Mail logs
/var/log/mail.log         # Debian/Ubuntu
/var/log/maillog          # RHEL/CentOS

# System logs
/var/log/syslog           # General system log
journalctl                # Systemd journal
```

## One-Liners

```bash
# Count logins per user today
sudo grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "ssh-login-notify" | grep -oP 'user=\K\w+' | sort | uniq -c

# Find unique IPs that logged in today
sudo grep "$(date +%Y-%m-%d)" /var/log/auth.log | grep "ssh-login-notify" | grep -oP 'source=\K[0-9.]+' | sort -u

# Check if notification system is active
pgrep -f ssh-login-notify && echo "Active" || echo "Not running"

# Verify PAM configuration
grep -q ssh-login-notify /etc/pam.d/sshd && echo "Configured" || echo "Not configured"

# Get notification statistics
sudo grep ssh-login-notify /var/log/auth.log | awk '{print $NF}' | sort | uniq -c
```

## Environment Variables (for testing)

```bash
# Available PAM environment variables
PAM_USER        # Username attempting login
PAM_RHOST       # Remote hostname/IP
PAM_SERVICE     # Service name (usually 'sshd')
PAM_TYPE        # PAM module type
PAM_TTY         # Terminal device

# Test with custom values
sudo PAM_USER="testuser" PAM_RHOST="192.168.1.100" PAM_SERVICE="sshd" /usr/local/bin/ssh-login-notify.sh
```

## Cron Job for Log Rotation (if needed)

```bash
# Add to /etc/cron.daily/ssh-notify-cleanup
#!/bin/bash
# Clean up old rate limit files (older than 24 hours)
find /var/run/ssh-login-notify -type f -mtime +1 -delete
```

## Mail Configuration Quick Test

```bash
# Test mail command
echo "Body" | mail -s "Subject" user@example.com

# Test with verbose output
echo "Body" | mail -v -s "Subject" user@example.com

# Check if mail command exists
command -v mail && echo "Found" || echo "Not found"

# View mail configuration (postfix)
postconf | grep relayhost
```
