## 1. Overview

This SOP details the automated backup pipeline for the Sovereign Lab Core-Router. The system uses a Bash script executed via Cron on the `sovereign-ops` management VM. It pulls the active configuration via SCP and versions it in a central GitHub repository.

### Key Features:

- **Idempotency**: The script only pushes to GitHub if the configuration has actually changed, preventing empty commits and Git history clutter.
    
- **Pre-Flight Syncing**: The script fetches and pulls remote Git changes before running to prevent `merge conflict` and `rejected push` errors.
    
- **Deterministic Alerting**: Integrates with Postfix to send explicit email notifications based on the outcome (Success/Changed, Success/No Change, or Failure).
    
- **Secure Pathing**: Utilizes absolute paths and runs under a locked-down user environment (`chmod 700`).
    

## 2. Prerequisites

- **SSH Trust**: The `sovereign-ops` VM must have key-based SSH access to the Core-Router (`root@10.0.10.1`).
    
- **Git Authentication**: The VM must be authenticated with GitHub via SSH keys.
    
- **Mail Infrastructure**: Postfix must be configured as an SMTP relay to route alerts to an external administrator email.
    

## 3. Deployment Instructions

### Step 1: Place the Script

Place the backup script in the designated scripts directory and secure it using the principle of least privilege:

```
nano ~/scripts/backup_router.sh
# (Paste script contents here)
chmod 700 ~/scripts/backup_router.sh
```

### Step 2: Configure the Cron Job

The script is scheduled to run daily at Midnight UTC. Open the crontab:

```
crontab -e
```

Add the following configuration, ensuring the `PATH` and `HOME` variables are explicitly declared so the Cron daemon can locate the necessary Git and SSH binaries:

```
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
HOME=/home/eric

# Run the Core-Router backup every night at Midnight UTC
0 0 * * * /home/eric/scripts/backup_router.sh >> /home/eric/scripts/cron_output.log 2>&1
```

## 4. Troubleshooting

- **Missing Logs**: Ensure the `HOME` variable in the crontab matches the actual user path (`/home/eric`, not `/home/eric-rivera`).
    
- **Git Push Rejected**: This occurs if the local repository is out of sync with GitHub. The script's "Pre-Flight Sync" logic (`git fetch` and `git pull --no-rebase`) is designed to automatically resolve this.
    
- **Sendmail Errors**: Ensure `mailutils` and `postfix` are installed and configured correctly.