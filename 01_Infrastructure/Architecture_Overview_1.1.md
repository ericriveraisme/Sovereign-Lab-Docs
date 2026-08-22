# 🏛️ Sovereign Lab: Architecture Overview
**Last Updated:** 2026-08-22
**Version:** 1.2
**Status:** Active Production
**Last Verified Against Live State:** 2026-08-22 (see [Infrastructure-State-Snapshot.md](Infrastructure-State-Snapshot.md); refresh via [SOP](../08_SOP/Standard%20Operating%20Procedure%20-%20Infrastructure%20Documentation%20Refresh.md) if older than 30 days)

## 1.  🛰️ Networking & Routing

The lab utilizes a "Router-on-a-Stick" topology with the Core-Router (LXC 100) serving as the primary gateway.

### 🗺️ Static Routing & Persistence

To ensure the Proxmox Host can communicate with the internal Management Plane (VLAN 10), a persistent static route is configured on the host bridge.

- **Gateway:** `192.168.0.235` (Core-Router WAN)
    
- **Target Subnet:** `10.0.10.0/24` (Management VLAN)
    
- **Persistence Method:** `post-up` directive in `/etc/network/interfaces`.
    

```
# Host /etc/network/interfaces snippet
auto vmbr0
iface vmbr0 inet static
    address 192.168.0.232/24
    post-up ip route add 10.0.10.0/24 via 192.168.0.235
```

## 🗺️ DNS Topology (Source of Truth)

The lab ignores external/ISP DNS in favor of an internal authoritative resolver.

- **Primary DNS:** `10.0.10.53` (Technitium)
    
- **Internal Domain:** `.sovereign.lab`
    
- **Upstream:** Cloudflare (1.1.1.1) via DNS-over-TLS.

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
* **Tiamat:** Linux Compute Node — migrated from Windows. Secondary workstation.
* **Bahamut:** Main Workstation (Windows 10/11) — Heavy compute (i7-10700KF / RX 7800 XT), documentation hub, Tier 3 storage provider, and **NUT Slave**. See [Bahamut-Node.md](Bahamut-Node.md).

## 5. ⚡ Power Management Architecture
The lab uses **Network UPS Tools (NUT)** in a master/slave topology to provide coordinated, graceful shutdown across all nodes during power events.

| Component | Role | Detail |
|:---|:---|:---|
| **Amazon Basics 1500VA** | UPS Hardware | CyberPower CP1500PFCLCD OEM. Pure Sine Wave. USB-connected to Proxmox. |
| **Proxmox Host** | NUT Master | Reads USB telemetry. Broadcasts on TCP `3493`. Issues FSD to all slaves at LB threshold. |
| **Bahamut** | NUT Slave | Polls Proxmox on `3493`. Sheds load at 70% battery. Native Windows Service (LocalSystem). |

### Shutdown Cascade
1. UPS detects power loss → broadcasts `OB` flag.
2. Bahamut WinNUT detects `OB` → graceful shutdown at 70% battery (sacrificial node).
3. Proxmox detects `LB` (10% / ≤300s) → gracefully halts all VMs/LXCs → powers off.
4. UPS executes killpower.

### Restoration Cascade
1. AC power restored → UPS powers outlets.
2. Proxmox auto-boots (BIOS: `Restore on AC Power Loss` → `Always On`).
3. All Start-at-Boot VMs/LXCs come online.
4. Proxmox cron fires WoL magic packet to Bahamut after 45s delay.
5. Bahamut wakes from S5 and reconnects to NUT Master.

See [NUT-Power-Management.md](../02_Services/NUT-Power-Management.md) for full configuration details.
See [Sovereign-Lab-DR-Power-Management-Runbook.md](../03_Runbooks/Sovereign-Lab-DR-Power-Management-Runbook.md) for operational runbook.

