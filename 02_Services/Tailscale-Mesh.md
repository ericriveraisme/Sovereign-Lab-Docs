# 🌐 Tailscale Mesh Network
**Last Updated:** 2026-03-13
**Role:** Secure Remote Access & Tier 3 Backup Transport

## Architecture
Tailscale establishes a WireGuard-backed mesh network, allowing administrative access to the Sovereign Lab without opening inbound ports on the physical ISP router.

## Authorized Nodes
* `sovereign-ops` (`100.122.30.25`) - Lab Management
* `Tiamat` - Mobile Command (Windows/WSL)
* `Bahamut` - Workstation & Tier 3 Storage Provider

## Operational Notes
* Tailscale serves as the transport layer for pushing Tier 3 backups to the `Bahamut_P_Drive` SMB share.
* **Monitoring:** Tailscale's admin console acts as our secondary "Dead Man's Switch." If the lab drops offline completely, checking the Tailscale node status is Step 1 of troubleshooting.