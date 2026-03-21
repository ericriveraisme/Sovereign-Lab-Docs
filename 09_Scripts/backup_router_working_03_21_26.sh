#!/bin/bash

# ==============================================================================
# Sovereign Lab: Core-Router Automated Backup Script
# Description: Pulls frr.conf via SCP, checks for changes, and versions in Git.
# ==============================================================================

# --- Configuration (ABSOLUTE PATHS ONLY FOR CRON) ---
ROUTER_IP="10.0.10.1"
DOCS_PATH="/home/eric/Sovereign-Lab-Docs"
BACKUP_DIR="$DOCS_PATH/04_Change_Logs/router_backups"
LOG_FILE="/home/eric/scripts/backup_log.txt"
ADMIN_EMAIL="ericriveraisme@gmail.com" 
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# --- Functions ---
# Function for CRITICAL failures (Logs error and sends alert email via Postfix)
log_and_fail() {
    local MSG="❌ ERROR: $1"
    echo "[$TIMESTAMP] $MSG" | tee -a "$LOG_FILE"
    
    # Bulletproof cron email delivery using Here-Doc and absolute sendmail path
    /usr/sbin/sendmail -t <<EOF
To: $ADMIN_EMAIL
Subject: Sovereign Lab Alert - Backup FAILED

The router backup script failed at $TIMESTAMP.
Reason: $1
Check logs at $LOG_FILE
EOF

    exit 1
}

# Standard logging function
log_message() {
    echo "[$TIMESTAMP] $1" | tee -a "$LOG_FILE"
}

log_message "🚀 Starting backup process..."

# --- 1. Git Pre-flight Sync ---
# Ensures the local ops VM matches GitHub before attempting to add new files.
cd "$DOCS_PATH" || log_and_fail "Could not enter directory $DOCS_PATH"

# Explicitly tell Git who is running this so background merges don't fail
/usr/bin/git config user.name "Sovereign Ops VM"
/usr/bin/git config user.email "ericriveraisme@gmail.com"

/usr/bin/git fetch origin main >> "$LOG_FILE" 2>&1

LOCAL=$(/usr/bin/git rev-parse HEAD)
REMOTE=$(/usr/bin/git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    log_message "🔄 Remote changes detected. Syncing local repository..."
    if ! /usr/bin/git pull origin main --no-rebase >> "$LOG_FILE" 2>&1; then
        log_and_fail "Git pull failed. Manual merge required."
    fi
fi

# --- 2. Configuration Pull ---
log_message "🛰️ Pulling frr.conf from Core-Router..."
if ! /usr/bin/scp root@$ROUTER_IP:/etc/frr/frr.conf "$BACKUP_DIR/frr_$TIMESTAMP.conf"; then
    log_and_fail "SCP transfer failed. Check router SSH/connectivity."
fi

# Update the 'latest' pointer for easy reference
cp "$BACKUP_DIR/frr_$TIMESTAMP.conf" "$BACKUP_DIR/frr_latest.conf"

# --- 3. Deterministic Git Operations & Emails ---
/usr/bin/git add .

# Attempt to commit. If there are no changes, commit fails and moves to 'else'.
if /usr/bin/git commit -m "Auto-Backup: Core-Router config ($TIMESTAMP)"; then
    # SCENARIO A: Success (Data Changed)
    if /usr/bin/git push origin main >> "$LOG_FILE" 2>&1; then
        log_message "✅ Success: Config pushed to GitHub."
        
        /usr/sbin/sendmail -t <<EOF
To: $ADMIN_EMAIL
Subject: Sovereign Lab - Backup SUCCESS

A new configuration change was detected on the Core-Router and backed up successfully to GitHub at $TIMESTAMP.
EOF

    else
        log_and_fail "Git push failed after commit. Check GitHub SSH keys."
    fi
else
    # SCENARIO B: Success (No Data Changed)
    # The script ran successfully, but the router config hasn't changed since yesterday.
    log_message "ℹ️ Notice: No changes detected."
    
    /usr/sbin/sendmail -t <<EOF
To: $ADMIN_EMAIL
Subject: Sovereign Lab - Backup Status (No Changes)

The automated backup ran successfully at $TIMESTAMP, but no changes were detected in the Core-Router configuration.
EOF

fi
