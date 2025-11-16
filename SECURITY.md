# Security Considerations

This document outlines security considerations for the SSH Login Email Notification system.

## Overview

The notification system is designed with security in mind, but administrators should be aware of potential risks and mitigation strategies.

## Security Features

### 1. Rate Limiting

**Purpose**: Prevent email bombing and resource exhaustion

**Implementation**:
- Default: One email per user per 5 minutes
- Configurable via `RATE_LIMIT_SECONDS` in the script
- Rate limit data stored in `/var/run/ssh-login-notify/`

**Benefits**:
- Prevents attackers from flooding your inbox with login notifications
- Reduces system resource consumption
- Mitigates potential DoS vectors

### 2. Background Execution

**Purpose**: Prevent login delays and potential blocking

**Implementation**:
- Script runs in background (forked process)
- Uses `disown` to detach from parent
- PAM configured as `optional` (won't block login on failure)

**Benefits**:
- Login process is not delayed by email sending
- Failed email delivery won't prevent user access
- System remains accessible even if script fails

### 3. Privilege Separation

**Purpose**: Run with minimal privileges

**Implementation**:
- PAM configured with `seteuid` option
- Script runs as the logging-in user, not root
- Rate limit directory has 755 permissions (world-writable tracking)

**Alternative**: Remove `seteuid` if you need root privileges for specific tasks

### 4. Logging to Syslog

**Purpose**: Audit trail and debugging

**Implementation**:
- All events logged to syslog with `auth` facility
- Tagged as `ssh-login-notify`
- Logs both successes and failures

**Benefits**:
- Centralized logging for security monitoring
- Integration with log management systems (SIEM)
- Audit trail for compliance

## Potential Risks and Mitigations

### 1. Information Disclosure

**Risk**: Email contains sensitive information about your infrastructure
- Server hostnames
- IP addresses
- Usernames
- Network topology hints

**Mitigations**:
- Ensure email transport is encrypted (use TLS)
- Use secure email providers
- Restrict access to the recipient email account
- Consider using internal email only (no external delivery)

**Best Practices**:
```bash
# Use internal email addresses only
EMAIL_TO="security-team@internal.company.com"

# Or use encrypted channels
# Configure your mail system to always use TLS
```

### 2. Email Interception

**Risk**: Emails sent in plaintext could be intercepted

**Mitigations**:
- Configure your mail server to use TLS/SSL
- Use authenticated SMTP
- Consider VPN or internal-only mail routing
- Use SPF, DKIM, and DMARC to prevent spoofing

**Recommended Mail Configuration** (for Postfix):
```
# /etc/postfix/main.cf
smtp_use_tls = yes
smtp_tls_security_level = encrypt
smtp_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1
```

### 3. Resource Exhaustion

**Risk**: Attacker performs rapid logins to exhaust resources

**Mitigations**:
- Rate limiting (enabled by default)
- SSH connection rate limiting (sshd_config)
- Fail2ban or similar intrusion prevention
- Monitor for unusual activity patterns

**Recommended SSH Configuration** (/etc/ssh/sshd_config):
```
# Limit concurrent unauthenticated connections
MaxStartups 10:30:60

# Limit authentication attempts
MaxAuthTries 3

# Connection rate limiting
ClientAliveInterval 300
ClientAliveCountMax 2
```

### 4. Script Injection

**Risk**: Malicious data in environment variables could be exploited

**Mitigations**:
- Script uses proper quoting
- Variables are not evaluated in dangerous contexts
- No `eval` or similar dangerous commands used
- Input is not executed as shell commands

**Security Features in Script**:
- All variables properly quoted
- No user input directly executed
- Mail body constructed safely
- No SQL injection vectors (no database)

### 5. PAM Configuration Errors

**Risk**: Incorrect PAM configuration could block logins

**Mitigations**:
- Use `optional` directive (not `required`)
- Script runs in background (won't block)
- Backup PAM config before modifications
- Test thoroughly before production deployment

**Safe Testing Procedure**:
1. Keep an existing SSH session open
2. Make PAM changes
3. Test login from another session
4. If locked out, restore from existing session
5. Revert using backup if needed

## Hardening Recommendations

### 1. Restrict Script Permissions

```bash
# Script should be owned by root and not writable by others
chown root:root /usr/local/bin/ssh-login-notify.sh
chmod 755 /usr/local/bin/ssh-login-notify.sh
```

### 2. Secure Rate Limit Directory

```bash
# Ensure rate limit directory has proper permissions
mkdir -p /var/run/ssh-login-notify
chmod 755 /var/run/ssh-login-notify

# Alternative: Use /var/lib for persistent storage
RATE_LIMIT_DIR="/var/lib/ssh-login-notify"
mkdir -p "$RATE_LIMIT_DIR"
chmod 755 "$RATE_LIMIT_DIR"
```

### 3. Monitor the Notification System

```bash
# Watch for notification failures
sudo tail -f /var/log/auth.log | grep ssh-login-notify

# Set up alerts for multiple failed notifications
# (could indicate mail system issues)

# Monitor rate limiting effectiveness
ls -ltr /var/run/ssh-login-notify/
```

### 4. Regular Security Audits

- Review PAM configuration regularly
- Audit email logs for anomalies
- Check for unusual login patterns
- Verify mail system security settings
- Update script when security issues are discovered

### 5. Integration with Security Tools

#### Fail2ban Integration

Create `/etc/fail2ban/filter.d/ssh-login-notify.conf`:
```ini
[Definition]
failregex = ssh-login-notify.*Failed to send email for user <USER>
ignoreregex =
```

#### SIEM Integration

Export auth logs to your SIEM:
```bash
# Example: Forward to remote syslog
# /etc/rsyslog.d/50-ssh-notify.conf
:programname, isequal, "ssh-login-notify" @@siem-server:514
```

## Compliance Considerations

### Audit Requirements

This system can help meet compliance requirements:

- **PCI-DSS**: Requirement 10.2.5 - Monitor access to audit trails
- **HIPAA**: Access monitoring and logging requirements
- **SOX**: IT access controls and monitoring
- **GDPR**: Security monitoring (Article 32)

### Data Retention

Email notifications contain personal data:
- Consider data retention policies
- Implement automatic email deletion after retention period
- Document in privacy policy if required

### Privacy Considerations

Inform users about login monitoring:
```bash
# Add to /etc/motd or /etc/ssh/sshd_config Banner
echo "All login activity is monitored and reported to system administrators." >> /etc/motd
```

## Incident Response

### If You Receive an Unauthorized Login Alert

1. **Immediate Actions**:
   - Change compromised user password immediately
   - Check for other active sessions: `who`, `w`, `last`
   - Review auth logs: `sudo grep sshd /var/log/auth.log`
   - Check for suspicious processes: `ps aux`, `top`

2. **Investigation**:
   - Identify source IP and reverse DNS
   - Check if IP is in threat intelligence feeds
   - Review user's recent command history
   - Look for persistence mechanisms (cron, systemd, rc.local)

3. **Containment**:
   - Block source IP via firewall
   - Disable compromised account if necessary
   - Rotate SSH keys
   - Enable 2FA if not already active

4. **Recovery**:
   - Remove any malicious artifacts
   - Restore from clean backups if needed
   - Update security measures

5. **Post-Incident**:
   - Document the incident
   - Update security procedures
   - Improve monitoring/alerting
   - Train users on security best practices

## Additional Security Measures

Beyond this notification system, consider:

1. **Multi-Factor Authentication (MFA)**
   - Google Authenticator PAM module
   - Duo Security integration
   - Hardware tokens (YubiKey)

2. **SSH Key-Based Authentication**
   - Disable password authentication
   - Use strong key types (ed25519, rsa 4096)
   - Implement key rotation policies

3. **Network Segmentation**
   - Restrict SSH access to jump hosts/bastion servers
   - Use VPN for administrative access
   - Implement zero-trust network architecture

4. **Intrusion Detection**
   - Deploy Fail2ban or similar tools
   - Use OSSEC or similar HIDS
   - Monitor with NIDS (Suricata, Snort)

5. **Regular Updates**
   - Keep SSH daemon updated
   - Apply security patches promptly
   - Subscribe to security mailing lists

## Support and Updates

- Report security issues: [Create GitHub issue - mark as security]
- Check for updates regularly
- Review security advisories for OpenSSH and Linux

## License

This security document is provided for informational purposes.
The notification system is provided "as-is" without warranty.
