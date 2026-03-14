# 🏛️ The Sovereign Lab Project

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

|   |   |   |   |   |
|---|---|---|---|---|
|**ID**|**Hostname**|**Role**|**IP Address**|**Tech Stack**|
|`Node`|`sovereign`|Hypervisor|`192.168.0.232`|Proxmox VE 8+|
|`100`|`core-router`|Lab Gateway & Routing|`10.0.10.1`|Ubuntu / FRR / iptables|
|`101`|`sovereign-ops`|Management Workstation|`10.0.10.10`|Debian / Tailscale / SSH|
|`103`|`netdata-monitor`|Telemetry & Health|`10.0.10.20`|Ubuntu / Netdata|
|`104`|`dns-primary`|"Source of Truth" DNS|`10.0.10.53`|Ubuntu / Technitium DNS|

## 🛡️ Core Design Principles

- **The Source of Truth:** Bypassing default/inherited configurations (like hypervisor MagicDNS) in favor of a dedicated, locally hosted DNS server (Technitium) to manage forward/reverse zones for the `.sovereign.lab` domain.
    
- **Persistence First:** Ensuring that every network change, route, or interface configuration survives a hard reboot.
    
- **3-Tier Backup Strategy:** 1. Local Compute (SSD) for fast execution.
    
    2. Local Vault (HDD) for scheduled Proxmox snapshot backups.
    
    3. Off-Site Sync via automated `rsync` jobs to external workstations.
    

## 🚀 Future Roadmap

The lab is a living environment. Upcoming milestones include:

- [ ] **Unified Web Portal (Reverse Proxy):** Deploying Nginx/Nginx Proxy Manager to route clean URLs (e.g., `portal.sovereign.lab`) to internal services, stripping the need for port memorization.
    
- [ ] **Subnet Routing / Tailscale Gateway:** Architecting a dedicated bridge to allow internal lab LXCs to resolve and reach Tailscale `.ts.net` nodes without installing Tailscale on every container.
    
- [ ] **Distributed Telemetry:** Expanding Netdata from a single-node monitor to a master-child architecture, pulling live metrics from the Core-Router and DNS servers.
    
- [ ] **Automated Alerting:** Configuring a Postfix SMTP Relay to dispatch critical alerts to mobile devices.
    
- [ ] **Infrastructure as Code (IaC):** Transitioning manual container provisioning to automated deployments using Terraform/Ansible.
    

_“Amateurs hack systems. Professionals build architecture.”_
