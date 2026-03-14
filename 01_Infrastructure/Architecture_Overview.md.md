# 🏛️ Sovereign Lab: Architecture Overview
**Last Updated:** 2026-03-13
**Status:** Active Production

## 1. Networking Core (The "Lighthouse")
The foundation of the lab is built on CCNA-aligned routing principles, utilizing a dedicated virtual router rather than consumer-grade flat networking.

* **Node:** `Core-Router` (LXC 100)
* **Routing Engine:** FRRouting (FRR) managed via the `vtysh` CLI.
* **Interfaces & Topology:**
  * **WAN (eth0):** `192.168.0.235/24` (Bridged via `vmbr0`)
  * **LAN (eth1):** `10.0.10.1/24` (VLAN 10 Gateway)

> **The Gold Master Rule:** After any routing changes in `vtysh`, always run `write mem` and manually back up `/etc/frr/frr.conf`. Without this file, the lab loses its routing brain on reboot.

### Network Subnetting Logic
For our internal VLAN 10 (`10.0.10.0/24`), the usable host calculation follows standard IPv4 logic:
$$\text{Usable Hosts} = 2^{32 - \text{prefix}} - 2$$
$$2^{32 - 24} - 2 = 2^8 - 2 = 254 \text{ usable IPs}$$
* Gateway: `.1`
* Usable Range: `.2` to `.254`
* Broadcast: `.255`

## 2. Management & Operations (The "Cockpit")
* **Node:** `sovereign-ops` (VM 101)
* **Tailscale IP:** `100.122.30.25`
* **Role:** Centralized management console, Ansible controller (planned), and primary jump box.
* **Authentication:** Password-less SSH enforced using `id_ed25519` keys verified across all administrative endpoints.

## 3. Storage Architecture (The 3-Tier Rule)
To ensure absolute data persistence, the lab strictly adheres to a 3-tier redundancy model. Proxmox native solutions (like CIFS) are preferred over custom scripts (like rsync) to reduce maintenance overhead.

| Tier | Name | Medium | Location | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Tier 1 (Active)** | `Local_SSD` | ZFS/LVM-Thin | Proxmox Internal | High-speed IO for active VMs/LXCs. |
| **Tier 2 (Backup)** | `Vault_Backups` | Physical HDD | Proxmox Internal (SATA) | Local snapshots and automated weekly backups. |
| **Tier 3 (Off-site)** | `Bahamut_P_Drive` | SMB/CIFS | Remote (Bahamut) | Off-site redundancy routed via the Tailscale mesh. |

## 4. Hardware Assets (The "Sentinels")
The physical endpoints used to interface with the Sovereign core.
* **Tiamat:** Primary Laptop (Windows/WSL) - Mobile command and control.
* **Bahamut:** Main Workstation (Windows/WSL) - Heavy lifting, documentation hub, and Tier 3 storage provider.

## 5. Critical Automated Interventions
* **The Ghost IP Fix:** A persistent script located at `/usr/local/bin/evict-ghost-ip.sh` on the `Core-Router`. It runs via `@reboot` cron to automatically delete the `192.168.0.232` squatter IP from `eth0`, ensuring upstream routing doesn't fail.
* **Postfix Mailer:** Placeholder fix implemented to ensure internal LXC/VM mailing capabilities do not hang the system.