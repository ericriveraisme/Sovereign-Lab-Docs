# 🏛️ Sovereign Lab: Architecture Overview
**Last Updated:** 2026-03-13
**Status:** Active Production

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
* **Tiamat:** Primary Laptop (Windows/WSL) - Mobile command and control.
* **Bahamut:** Main Workstation (Windows/WSL) - Heavy lifting, documentation hub, and Tier 3 storage provider.

