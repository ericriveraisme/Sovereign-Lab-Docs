# 🎛️ Sovereign-Ops (VM 101)
**Last Updated:** 2026-03-13
**Role:** Management Cockpit & Control Plane

## Node Specifications
* **Hypervisor:** Proxmox VE (Local_SSD)
* **Architecture:** Virtual Machine (VM)
* **Authentication:** Password-less SSH enforced via `id_ed25519` key pairs.

## Networking
* **Tailscale Mesh IP:** `100.122.30.25`
* **Access Protocol:** This node acts as the primary "Jump Box." All administrative tasks, scripts, and eventual Ansible playbooks should be executed from this machine.

## Hosted Services
*(Currently acting as a baseline management node. Slated to host Uptime Kuma for internal heartbeat monitoring.)*