# 🏛️ The Sovereign Lab Project

> **Built by [Eric Rivera](https://ericriveraisme.github.io)** — Infrastructure engineer with 12 years across NOC operations, systems administration, and hybrid identity environments. Currently building a self-hosted virtual data center from scratch — designing the routing, DNS, automation, and documentation from the ground up. This project is my workshop and my proof of work.

Welcome to the **Sovereign Lab**. This repository serves as the public documentation, infrastructure-as-code (IaC) repository, and architectural blueprint for an enterprise-grade, self-hosted Proxmox environment.

## 🎯 Project Purpose

The Sovereign Lab was created to bridge the gap between theoretical networking concepts (like CCNA) and practical, hands-on systems engineering. The core objective is to build an environment that is:

1. **Resilient:** Survives hardware failures, configuration mistakes, and network drops.
    
2. **Sovereign:** Completely self-hosted, bypassing reliance on external cloud providers for core routing, DNS, and telemetry.
    
3. **Isolated yet Accessible:** Utilizes logical network separation (VLANs) while remaining accessible from anywhere via a secure zero-trust overlay network.
    

This project represents a commitment to "Learning in Public," documenting the real-world challenges of building a data center on a desk.

## 🏗️ High-Level Architecture

The lab is built on a single Proxmox Virtual Environment (PVE) node, logically partitioned using a "Router-on-a-Stick" topology.

### Network Topology

- **Physical Gateway:** Home Network (`192.168.0.x`)
    
- **Core-Router (LXC):** The heart of the lab. Powered by FRR (Free Range Routing), it handles inter-VLAN routing, NAT masquerading, and isolates the lab from the broader home network.
    
- **VLAN 10 (Management Plane):** `10.0.10.0/24` - Infrastructure, DNS, Monitoring.
    
- **VLAN 20 (User Plane):** `10.0.20.0/24` - Isolated playground for testing and user-space applications.
    

### Security & Remote Access

- **Tailscale:** Deployed as the primary secure overlay network (`.ts.net`), allowing seamless, secure SSH and VS Code Remote access into the management plane without exposing ports to the public internet.
    

## 💻 Current Infrastructure (The Stack)

|        |                   |                        |                 |                          |
| ------ | ----------------- | ---------------------- | --------------- | ------------------------ |
| **ID** | **Hostname**      | **Role**               | **IP Address**  | **Tech Stack**           |
| `Node` | `sovereign`       | Hypervisor             | `192.168.0.232` | Proxmox VE 9.1.1         |
| `100`  | `core-router`     | Lab Gateway & Routing  | `10.0.10.1`     | Ubuntu / FRR / iptables  |
| `101`  | `sovereign-ops`   | Management Workstation | `10.0.10.10`    | Debian / Tailscale / SSH |
| `103`  | `netdata-monitor` | Telemetry & Health     | `10.0.10.20`    | Ubuntu / Netdata         |
| `104`  | `dns-primary`     | "Source of Truth" DNS  | `10.0.10.53`    | Ubuntu / Technitium DNS  |

## 🛡️ Core Design Principles

- **The Source of Truth:** Bypassing default/inherited configurations (like hypervisor MagicDNS) in favor of a dedicated, locally hosted DNS server (Technitium) to manage forward/reverse zones for the `.sovereign.lab` domain.
    
- **Persistence First:** Ensuring that every network change, route, or interface configuration survives a hard reboot.
    
- **3-Tier Backup Strategy:** 1. Local Compute (SSD) for fast execution.
    
    2. Local Vault (HDD) for scheduled Proxmox snapshot backups.
    
    3. Off-Site Sync via automated `rsync` jobs to external workstations.
    

## ✅ Completed Milestones

- [x] **Layer 3 Inter-VLAN Routing** — FRR-powered router-on-a-stick topology with NAT masquerading
- [x] **Authoritative DNS** — Technitium DNS server as the single source of truth for `.sovereign.lab`
- [x] **Zero-Trust Remote Access** — Tailscale mesh overlay for secure SSH and VS Code Remote
- [x] **Automated Router Backups** — Cron-driven SCP + Git pipeline with email alerting ([see SOP](08_SOP/Standard%20Operating%20Procedure%20-%20Automated%20Git-Based%20Router%20Backups.md))
- [x] **Postfix SMTP Relay** — Gmail relay for system notifications ([see SOP](08_SOP/Standard%20Operating%20Procedure%20-%20Postfix%20Gmail%20SMTP%20Relay.md))
- [x] **Workstation Migration (Leviathan)** — Full WSL-to-native-Linux migration with Ed25519 auth and Git automation ([read the story](05_Articles/Leviathan_Migration_Breaking_The_Glass.md))
- [x] **Telemetry & Monitoring** — Netdata cloud-integrated health dashboards across all nodes

## 🚀 Active Roadmap

- [ ] 🎛️ **Intelligent Telemetry (Pulse):** AI-driven "Patrol" health checks for proactive Proxmox monitoring
- [ ] 💓 **External Heartbeat Alerts (Uptime Kuma):** Dead Man's Snitch for WAN drop notifications
- [ ] 🌐 **Unified Web Portal (Reverse Proxy):** Nginx Proxy Manager for clean URLs to internal services
- [ ] 🛣️ **Subnet Routing / Tailscale Gateway:** Bridge for internal LXCs to reach `.ts.net` nodes
- [ ] 📜 **Infrastructure as Code (IaC):** Terraform and Ansible for automated container provisioning
- [ ] 🛠️ **Enhanced Hypervisor Management:** `ProxMenux` for streamlined PVE administration
- [ ] 🗄️ **Hardware Asset Tracking:** `RackPeak` for visual server documentation

---

## 📂 Documentation Index

Everything in this repository is navigable from here. Click any link to jump directly to the document.

### Infrastructure

| Document | Description |
|----------|-------------|
| [Architecture Overview](01_Infrastructure/Architecture_Overview_1.1.md) | High-level system design, backup strategy, hardware inventory |
| [Core Router (LXC 100)](01_Infrastructure/Core-Router-LXC100.md) | FRR routing engine, interface config, known anomalies |
| [Network Architecture](01_Infrastructure/Network-Architecture.md) | VLAN topology and DNS hierarchy |
| [Sovereign-Ops (VM 101)](01_Infrastructure/Sovereign-Ops-VM101.md) | Management cockpit — automation, backups, monitoring |
| [Ghost-User (VM 102)](01_Infrastructure/Ghost-User-VM102.md) | Isolated sandbox for enterprise scenario testing |

### Services

| Document | Description |
|----------|-------------|
| [Technitium DNS v1.1](02_Services/Technitium/Technitium-DNS_1.1.md) | Authoritative DNS — zones, records, troubleshooting |
| [Technitium DNS v1.0](02_Services/Technitium/Technitium-DNS_1.0.md) | Original as-built with UI walkthroughs and known issues |
| [Netdata Telemetry](02_Services/Netdata-Telemetry.md) | Cloud-integrated monitoring, DNS integration, reverse proxy roadmap |
| [Tailscale Mesh](02_Services/Tailscale-Mesh.md) | Zero-trust overlay network — authorized nodes and roles |

### Runbooks

| Document | Description |
|----------|-------------|
| [Evict Ghost IP](03_Runbooks/Evict-Ghost-IP.md) | Resolve WAN IP conflicts on the core router |
| [Postfix Hang Resolution](03_Runbooks/Postfix-Hang-Resolution.md) | Fix stalled Postfix mail queue |
| [VLAN Connectivity Troubleshooting](03_Runbooks/VLAN-Connectivity-Troubleshooting.md) | Step-by-step inter-VLAN reachability diagnosis |

### Standard Operating Procedures

| Document | Description |
|----------|-------------|
| [Automated Git-Based Router Backups](08_SOP/Standard%20Operating%20Procedure%20-%20Automated%20Git-Based%20Router%20Backups.md) | Cron scheduling, SCP pull, Git sync, email alerting |
| [Postfix Gmail SMTP Relay](08_SOP/Standard%20Operating%20Procedure%20-%20Postfix%20Gmail%20SMTP%20Relay.md) | App passwords, credential hashing, test procedures |

### Automation & Scripts

| Document | Description |
|----------|-------------|
| [Router Backup Script](09_Scripts/Core-Router%20Backup%20Script%20-%20Held%20on%20SovereignOps%20VM.md) | Documentation for the production backup pipeline |
| [backup_router_working_03_21_26.sh](09_Scripts/backup_router_working_03_21_26.sh) | Production bash script — SCP, Git pre-flight sync, email alerts |

### Change Logs & Project History

| Document | Description |
|----------|-------------|
| [Leviathan Node Migration](04_Change_Logs/Leviathan_Node_Migration_Project.md) | WSL → native Linux migration — Tailscale, SSH, Git automation |
| [Leviathan Project Review](04_Change_Logs/Leviathan_Project_Review.md) | Retrospective — Ed25519 auth, backup pipeline verification |
| [Router Config Backups](04_Change_Logs/router_backups/) | Timestamped FRR configuration snapshots |

### Articles & Write-Ups

| Document | Description |
|----------|-------------|
| [Breaking the Glass — Leviathan Migration](05_Articles/Leviathan_Migration_Breaking_The_Glass.md) | The full story of leaving WSL behind and building on bare metal |
| [Leviathan Project Draft](05_Articles/Leviathan_Project_Article_Draft.md) | Companion piece on troubleshooting culture and automation |
| [DNS & Routing Deep Dive](05_Articles/Sovereign_Lab_DNS_Routing_Post.md) | Layer 3 routing puzzles, ghost IPs, and DNS authority |

### Templates & Reference

| Document | Description |
|----------|-------------|
| [New Node Checklist](06_Templates/Checklist-New-Node.md) | Provisioning checklist — hostname, DNS, SSH, firewall, backups |
| [Lab Backlog](Lab-Backlog.md) | Prioritized task tracker with book references |

### Knowledge Base

| Document | Description |
|----------|-------------|
| [Practical Linux Sysadmin — Ch.1](07_Knowledge_Base/Practical_Linux_System_Administration/Chapter-1-Summary.md) | Notes on the sysadmin mindset and fundamentals |

---

_"Amateurs hack systems. Professionals build architecture."_
