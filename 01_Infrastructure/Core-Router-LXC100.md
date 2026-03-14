# 🧭 Core-Router (LXC 100)
**Last Updated:** 2026-03-13
**Role:** Primary Data Plane & Layer 3 Gateway
**Engine:** FRRouting (FRR)

## Node Specifications
* **Hypervisor:** Proxmox VE (Local_SSD)
* **Architecture:** Unprivileged LXC
* **Management CLI:** `vtysh` (Cisco-style routing shell)

## Interface Configuration (Topology)
The router acts as the boundary between the physical home network and the Sovereign Lab internal mesh.

| Interface | Type | IP Address | Subnet Mask | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `eth0` | WAN / Edge | `192.168.0.235` | `/24` | Default route out to the physical ISP router via `vmbr0`. |
| `eth1` | LAN / Gateway| `10.0.10.1` | `/24` | Layer 3 Gateway for internal lab traffic (VLAN 10). |

## Persistent Configurations
* **Routing Logic Location:** `/etc/frr/frr.conf`
* **Backup Protocol:** Any changes made inside `vtysh` must be written to memory (`write mem`) and the `frr.conf` file backed up to Git. If the container reboots without a saved config, the lab loses all routing.

## Known Anomalies
* **The Ghost IP:** `eth0` is prone to picking up `192.168.0.232` as a squatter IP, which null-routes WAN traffic. Handled automatically via Runbook `Evict-Ghost-IP.md`.