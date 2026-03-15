- [ ] **Hostname & IP:** Assigned unique hostname and static IP in the 10.0.10.x range.
    
- [ ] **DNS/Tailscale:** Joined to the Tailscale mesh if remote access is required.
    
- [ ] **SSH Keys:** New `id_ed25519.pub` from Leviathan added to `authorized_keys`.
    
- [ ] **Updates:** `sudo apt update && sudo apt upgrade -y` performed.
    
- [ ] **Firewall:** UFW enabled and minimal ports opened.
    
- [ ] **Persistence Check:** Configuration verified to survive a reboot.
    
- [ ] **Backups:** Node added to Proxmox backup schedule (Tier 1).