# 🛠️ Runbook: Evict Ghost IP (WAN Conflict)
**Last Updated:** 2026-03-13
**Target:** `Core-Router` (LXC 100)

## The Problem
The router occasionally pulls a secondary squatter IP (`192.168.0.232`) on the WAN interface (`eth0`) alongside its static `192.168.0.235` address. This creates a routing conflict, causing all lab VMs to lose internet access.

## The Automated Solution
A persistent bash script runs at boot to automatically identify and strip the conflicting IP.

### 1. The Script (`/usr/local/bin/evict-ghost-ip.sh`)
```bash
#!/bin/bash
# Sovereign Lab: Ghost IP Eviction
# Removes the 192.168.0.232 squatter IP from eth0 to restore WAN routing.

TARGET_IP="192.168.0.232/24"
INTERFACE="eth0"

# Check if the IP exists on the interface
if ip addr show $INTERFACE | grep -q $TARGET_IP; then
    echo "Ghost IP $TARGET_IP detected. Evicting..."
    ip addr del $TARGET_IP dev $INTERFACE
    echo "Eviction complete. WAN routing restored."
else
    echo "Interface clean. No action required."
fi