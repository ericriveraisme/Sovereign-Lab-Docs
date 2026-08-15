# 🏛️ The Sovereign Lab Project

> **Built by [Eric Rivera](https://ericriveraisme.github.io)** — Infrastructure engineer with 12 years across NOC operations, systems administration, and hybrid identity environments. Currently building a self-hosted virtual data center from scratch — designing the routing, DNS, automation, and documentation from the ground up. This project is my workshop and my proof of work.

Welcome to the **Sovereign Lab**. This repository serves as the public documentation, infrastructure-as-code (IaC) repository, and architectural blueprint for an enterprise-grade, self-hosted Proxmox environment.

A recent change to the operating model is the introduction of a local-only AI-assisted Proxmox workflow. The lab architecture remains documented here, while the live connection to the hypervisor is kept outside the Git-tracked repo to protect secrets and keep the public repo focused on architecture and reasoning.

## Quick Access

- Public topology diagram: [Sovereign Lab Public Network Topology v1.0](https://htmlpreview.github.io/?https://raw.githubusercontent.com/ericriveraisme/Sovereign-Lab-Docs/main/Diagrams/Sovereign-Lab-Network-Topology_Public_v1.0.html)
- Diagram source: [Diagrams/Sovereign-Lab-Network-Topology_Public_v1.0.html](Diagrams/Sovereign-Lab-Network-Topology_Public_v1.0.html)
- Local AI + Proxmox integration notes: [04_Change_Logs/AI_Proxmox_MCP_Integration.md](04_Change_Logs/AI_Proxmox_MCP_Integration.md)
- Baseline lab review: [04_Change_Logs/Proxmox_Baseline_Audit_2026-08-15.md](04_Change_Logs/Proxmox_Baseline_Audit_2026-08-15.md)

## 🎯 Project Purpose

The Sovereign Lab is a hands-on infrastructure engineering environment designed to bridge the gap between classroom networking and real systems work. It is a live, self-hosted lab for exploring routing, DNS, virtualization, automation, security, and operational design at a practical level.

The project emphasizes four things:

1. **Operational realism:** Building systems that behave like production infrastructure, not just lab demos.
2. **Self-sovereignty:** Keeping critical services local and under direct control instead of depending on managed cloud primitives.
3. **Documentation-first engineering:** Capturing decisions, failures, recovery paths, and design evolution in public.
4. **Automation and context efficiency:** Using AI-assisted tooling and structured runbooks to reduce friction while keeping the operator in control.

This repository represents a commitment to learning in public and documenting real infrastructure decisions as they evolve.

## 🏗️ Architecture Snapshot

The lab is built around a Proxmox VE environment with a layered, routed topology used to simulate enterprise-style networking and system operations.

### Core Network Model

- **Physical gateway:** Home network at `192.168.0.x`
- **Core router:** LXC-based FRR deployment handling inter-VLAN routing, NAT, policy separation, and lab isolation
- **Management plane:** `10.0.10.0/24` for infrastructure, DNS, monitoring, and admin services
- **User plane:** `10.0.20.0/24` for isolated testing, sandbox workloads, and experimentation
- **Remote access:** Tailscale overlay network for secure SSH, VS Code, and internal connectivity without exposing services broadly

### Current Stack

| ID | Hostname | Role | IP | Stack |
| --- | --- | --- | --- | --- |
| Node | `sovereign` | Hypervisor | `192.168.0.232` | Proxmox VE 9.1.1 |
| 100 | `core-router` | Lab gateway and routing | `10.0.10.1` | Ubuntu / FRR / iptables |
| 101 | `sovereign-ops` | Management workstation | `10.0.10.10` | Debian / Tailscale / SSH |
| 103 | `netdata-monitor` | Telemetry and health | `10.0.10.20` | Ubuntu / Netdata |
| 104 | `dns-primary` | Authoritative DNS | `10.0.10.53` | Ubuntu / Technitium DNS |

## 🧠 Engineering Approach

This project is intentionally structured as both a technical lab and a professional portfolio of systems thinking.

- **Source of truth:** The repo documents the architecture, operational decisions, and recovery procedures.
- **Live state validation:** Proxmox and system state are checked against the repo before and after change windows.
- **Human-led execution:** Changes are reviewed and approved by the operator, even when AI assists with gathering information and drafting recommendations.
- **Operational discipline:** Backups, runbooks, patch planning, and drift review are treated as first-class work.

## ✅ Highlights and Milestones

- [x] **Layer 3 inter-VLAN routing** with FRR and NAT policy enforcement
- [x] **Authoritative DNS** using Technitium for local service discovery and lab naming
- [x] **Zero-trust remote access** with Tailscale overlay networking
- [x] **Automated Git-based router backups** and operational runbook discipline
- [x] **Postfix SMTP relay** for system notifications and operational alerting
- [x] **Workstation migration and bare-metal rebuild workflows** using Git, SSH, and secure automation
- [x] **Telemetry stack** combining Netdata, service monitoring, and health visibility

## 🚀 Current Direction and Future Expansion

The next phase of the lab focuses on making the environment more realistic, more resilient, and more useful as an engineering sandbox.

Planned work includes:

- **AI-assisted operations and drift detection** for Proxmox, VMs, LXCs, and configuration state
- **vWAN / transit expansion** to simulate broader networking and route policy changes
- **FRR and BGP validation** for realistic route advertisement and failover scenarios
- **VLAN and interface hardening** for a more layered network topology
- **Infrastructure automation** using declarative tooling and repeatable provisioning patterns
- **Operational visibility** through service health, alerting, reverse proxying, and dashboarding

This is the foundation of a modern operations mindset: keep the environment observable, documented, and safe to evolve.

## 📍 Repository Navigation

This repo is organized to showcase both architecture and execution.

### Infrastructure

- [01_Infrastructure/Architecture_Overview_1.1.md](01_Infrastructure/Architecture_Overview_1.1.md)
- [01_Infrastructure/Network-Architecture.md](01_Infrastructure/Network-Architecture.md)
- [01_Infrastructure/Core-Router-LXC100.md](01_Infrastructure/Core-Router-LXC100.md)
- [01_Infrastructure/Sovereign-Ops-VM101.md](01_Infrastructure/Sovereign-Ops-VM101.md)

### Services

- [02_Services/Technitium/Technitium-DNS_1.1.md](02_Services/Technitium/Technitium-DNS_1.1.md)
- [02_Services/Netdata-Telemetry.md](02_Services/Netdata-Telemetry.md)
- [02_Services/Tailscale-Mesh.md](02_Services/Tailscale-Mesh.md)

### Runbooks and Operations

- [03_Runbooks/Proxmox-Full-DR-Playbook.md](03_Runbooks/Proxmox-Full-DR-Playbook.md)
- [03_Runbooks/VLAN-Connectivity-Troubleshooting.md](03_Runbooks/VLAN-Connectivity-Troubleshooting.md)
- [08_SOP/Standard Operating Procedure - Automated Git-Based Router Backups.md](08_SOP/Standard%20Operating%20Procedure%20-%20Automated%20Git-Based%20Router%20Backups.md)

### Change Logs and Historical Work

- [04_Change_Logs/AI_Proxmox_MCP_Integration.md](04_Change_Logs/AI_Proxmox_MCP_Integration.md)
- [04_Change_Logs/Leviathan_Node_Migration_Project.md](04_Change_Logs/Leviathan_Node_Migration_Project.md)
- [04_Change_Logs/Leviathan_Project_Review.md](04_Change_Logs/Leviathan_Project_Review.md)

### Articles and Writing

- [05_Articles/Leviathan_Migration_Breaking_The_Glass.md](05_Articles/Leviathan_Migration_Breaking_The_Glass.md)
- [05_Articles/Sovereign_Lab_DNS_Routing_Post.md](05_Articles/Sovereign_Lab_DNS_Routing_Post.md)
- [05_Articles/Sovereign_Lab_DR_Chronicle_Draft.md](05_Articles/Sovereign_Lab_DR_Chronicle_Draft.md)

## 🛡️ Core Design Principles

- **Persistence first:** Configuration is designed to survive reboot, migration, and recovery events.
- **Least privilege:** Access is intentionally scoped and reviewed before being expanded.
- **Observable systems:** Health, telemetry, and route validation are treated as foundational requirements.
- **Document everything:** The repo is both an operational record and a technical narrative of how the lab evolved.

---

_This project reflects a modern systems engineering approach: build for resilience, prove the work in public, and keep the architecture honest through documentation and live validation._

- [x] **Layer 3 Inter-VLAN Routing** — FRR-powered router-on-a-stick topology with NAT masquerading
- [x] **Authoritative DNS** — Technitium DNS server as the single source of truth for `.sovereign.lab`
- [x] **Zero-Trust Remote Access** — Tailscale mesh overlay for secure SSH and VS Code Remote
- [x] **Automated Router Backups** — Cron-driven SCP + Git pipeline with email alerting ([see SOP](08_SOP/Standard%20Operating%20Procedure%20-%20Automated%20Git-Based%20Router%20Backups.md))
- [x] **Postfix SMTP Relay** — Gmail relay for system notifications ([see SOP](08_SOP/Standard%20Operating%20Procedure%20-%20Postfix%20Gmail%20SMTP%20Relay.md))
- [x] **Workstation Migration (Leviathan)** — Full WSL-to-native-Linux migration with Ed25519 auth and Git automation ([read the story](05_Articles/Leviathan_Migration_Breaking_The_Glass.md))
- [x] **Telemetry & Monitoring** — Netdata cloud-integrated health dashboards across all nodes

## 🚀 Active Roadmap

- [ ] 🤖 **Local AI Operations Layer:** Use a read-only Proxmox MCP connection to inspect live cluster state, compare it to repo documentation, and reduce context switching during lab changes
- [ ] 🧭 **Baseline and Drift Validation:** Maintain a live inventory and drift check for Proxmox nodes, VMs, LXCs, and route state before and after topology changes
- [ ] 🌐 **vWAN / Transit Expansion:** Extend the lab beyond the current single-node design into a multi-link, routed, and more realistic WAN-style topology
- [ ] 🛣️ **FRR + BGP Expansion:** Add richer routing logic, upstream path testing, and validation of route advertisements and failover behavior
- [ ] 🔌 **Interface and VLAN Rollout:** Expand vmbr design, VLAN-aware uplinks, and segmentation for new lab services and test paths
- [ ] 💓 **External Heartbeat Alerts (Uptime Kuma):** Dead Man's Snitch for WAN drop notifications and upstream outage detection
- [ ] 🌐 **Unified Web Portal (Reverse Proxy):** Nginx Proxy Manager for clean URLs to internal services
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
| [Sovereign Lab Disaster Recovery](05_Articles/Sovereign_Lab_DR_Chronicle_Draft.md) | Disaster Recovery update with timeline of RTO and MTTR |

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
