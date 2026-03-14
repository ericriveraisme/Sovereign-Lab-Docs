# 🛠️ Runbook: Inter-VLAN Connectivity Fix
**Problem:** LXC/VM cannot reach Gateway (10.0.10.1).
**Cause:** Missing VLAN Tag in Proxmox Network Hardware settings.
**Fix:** 1. Open Proxmox GUI > [LXC/VM] > Network.
2. Edit the interface (net0).
3. Set **VLAN Tag** to `10`.
4. Restart networking or the container.