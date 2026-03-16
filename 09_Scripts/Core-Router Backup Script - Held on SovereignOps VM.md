#!/bin/bash

# ==============================================================================
# Sovereign Lab: Core-Router Automated Backup Script
# Description: Pulls frr.conf via SCP, checks for changes, and versions in Git.
# ==============================================================================

# --- Configuration ---
ROUTER_IP="10.0.10.1"
DOCS_PATH="$HOME/Sovereign-Lab-Docs"
BACKUP_DIR="$DOCS_PATH/04_Change_Logs/router_backups"
LOG_FILE="$HOME/scripts/backup_log.txt"
ADMIN_EMAIL="ericriveraisme@gmail.com" 
TIMESTAMP=$(date +"%Y-%m-%d_%H%M")

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# --- Functions ---
# Function for CRITICAL failures (Logs error and sends alert email)
log_and_fail() {
    local MSG="❌ ERROR: $1"
    echo "[$TIMESTAMP] $MSG" | tee -a "$LOG_FILE"
    echo -e "Subject: Sovereign Lab Alert - Backup FAILED\n\nThe router backup script failed at $TIMESTAMP.\nReason: $1\nCheck logs at $LOG_FILE" | sendmail "$ADMIN_EMAIL"
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
log_message "🔄 Syncing with GitHub..."
git fetch origin main >> "$LOG_FILE" 2>&1

LOCAL=$(git rev-parse @)
REMOTE=$(git rev-parse @{u})

if [ "$LOCAL" != "$REMOTE" ]; then
    log_message "ℹ️ Local is behind remote. Pulling updates..."
    if ! git pull origin main --no-rebase >> "$LOG_FILE" 2>&1; then
        log_and_fail "Git pull failed. Manual merge required."
    fi
fi

# --- 2. Configuration Pull ---
log_message "🛰️ Pulling frr.conf from Core-Router..."
if ! scp root@$ROUTER_IP:/etc/frr/frr.conf "$BACKUP_DIR/frr_$TIMESTAMP.conf"; then
    log_and_fail "SCP transfer failed. Check router SSH/connectivity."
fi

# Update the 'latest' pointer for easy reference
cp "$BACKUP_DIR/frr_$TIMESTAMP.conf" "$BACKUP_DIR/frr_latest.conf"

# --- 3. Deterministic Git Operations & Emails ---
git add .

# Attempt to commit. If there are no changes, commit fails and moves to 'else'.
if git commit -m "Auto-Backup: Core-Router config ($TIMESTAMP)"; then
    # SCENARIO A: Success (Data Changed)
    if git push origin main >> "$LOG_FILE" 2>&1; then
        log_message "✅ Success: Config pushed to GitHub."
        echo -e "Subject: Sovereign Lab - Backup SUCCESS\n\nA new configuration change was detected and backed up at $TIMESTAMP." | sendmail "$ADMIN_EMAIL"
    else
        log_and_fail "Git push failed after commit. Check GitHub SSH keys."
    fi
else
    # SCENARIO B: Success (No Data Changed)
    # The script ran successfully, but the router config hasn't changed since yesterday.
    log_message "ℹ️ Notice: No changes detected."
    echo -e "Subject: Sovereign Lab - No Changes\n\nBackup ran at $TIMESTAMP. No configuration changes detected. No push was necessary." | sendmail "$ADMIN_EMAIL"
fi

log_message "🏁 Backup cycle complete."