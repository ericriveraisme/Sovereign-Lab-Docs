## 🛠️ Node Migration: Tiamat → Leviathan

**Date:** 2026-03-15
**Status:** Operational
**OS:** Ubuntu 24.04 LTS Desktop

## 📋 Overview

Migrated primary workstation from Windows/WSL (Tiamat) to native Linux (Leviathan). This move aligns with the **Sovereign Lab Protocol** of maintaining a native Linux environment for better tool parity and lower latency when managing the Proxmox cluster.


## 🌐 Networking (Tailscale Mesh)

- **Tailscale IP:**  <levi_ip>
- **Role:** Primary Management Cockpit.
    
- **Verification:** `tailscale ip -4` confirmed connectivity to `sovereign-ops` (OPS_IP).
    

## 🔑 Security & Access

Generated a new modern identity key using the Ed25519 curve.

- **Command:** `ssh-keygen -t ed25519 -C "LAB_USER"`
    
- **Public Key:** Distributed to `sovereign-ops` and Proxmox host via `ssh-copy-id`.
    

## 🚀 SSH Workflow (Config Hub)

Modified `~/.ssh/config` to eliminate the need for memorizing IP addresses.

Plaintext

```
Host ops
    HostName OPS_IP
    User [username]
    IdentityFile /home/USER_ID/.ssh/id_ed25519
```

- **Outcome:** Password-less authentication verified. Accessing the lab is now a simple `ssh ops` command.
    

## 📚 Learning Roadmap Reference

- **Current Focus:** _Practical Linux System Administration_ (Chapter 1).
    
- **Objective:** Internalize the "Sysadmin Mindset"—documentation, automation, and system-wide thinking.