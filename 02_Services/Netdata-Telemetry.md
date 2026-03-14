# 📊 Sovereign Lab: Netdata Monitor As-Built Documentation

## 1. Container Provisioning (Proxmox Host)

This container was provisioned to act as the primary "Mechanic" for the Sovereign Lab, providing real-time hardware telemetry (CPU, RAM, Disk I/O) for the underlying i5-3570K host and network traffic analysis.

- **LXC ID:** `103`
    
- **Hostname:** `netdata-monitor`
    
- **Network Interface (`eth0`):**
    
    - Bridge: `vmbr0`
        
    - IPv4: `10.0.10.20/24`
        
    - Gateway: `10.0.10.1` (Core-Router)
        

## 2. Pre-Installation OS Configuration

Like other early containers, LXC 103 inherited broken Tailscale MagicDNS settings from the Proxmox host. To ensure the container could reach the internet to download the installation scripts without Proxmox overwriting the fix on reboot, the "Persistence First" method was used.

**Commands Executed (Inside LXC 103):**

```
# Override the broken DNS with public resolvers
pct set 103 --nameserver "1.1.1.1 8.8.8.8"

# Create the Proxmox 'ignore' file to prevent future overwrites
touch /etc/.pve-ignore.resolv.conf
```

## 3. Application Installation

Installed using the official Netdata kickstart script with telemetry disabled for data privacy.

**Installation Command:**

```
wget -O /tmp/netdata-kickstart.sh [https://get.netdata.cloud/kickstart.sh](https://get.netdata.cloud/kickstart.sh) && sh /tmp/netdata-kickstart.sh --disable-telemetry
```

### A. Cloud Integration (The "War Room")

- **Status:** Connected to Netdata Cloud.
    
- **Details:** The node was claimed using a Netdata Cloud token to enable off-site, professional "Single Pane of Glass" visibility and automated health alerting without needing to configure a local Postfix mail relay.
    
- **Local Listening Port:** Verified via `ss -tulpn | grep 19999` that the service binds to `0.0.0.0:19999` (listening on all interfaces, not just localhost).
    

## 4. Network & Client Integrations (The Bahamut Bridge)

Initially, the Netdata UI (`http://10.0.10.20:19999`) was unreachable from the main Windows workstation (Bahamut). Bahamut resides on the home `192.168.0.x` network and did not know how to route traffic to the `10.0.10.x` VLAN.

**The Fix:** A persistent static route was added to Bahamut's Windows routing table, pointing traffic destined for the lab network to the Core-Router's WAN IP.

**Executed in Bahamut PowerShell (Admin):**

```
route -p add 10.0.10.0 mask 255.255.255.0 192.168.0.235
```

## 5. DNS Integration (Technitium)

Once the `dns-primary` (LXC 104) was established as the lab's Source of Truth, Netdata was given a human-readable identity.

- **A Record:** `monitor.sovereign.lab` -> `10.0.10.20`
    
- **PTR Record (Reverse Zone):** `20` -> `monitor.sovereign.lab`
    
- **Access URL:** `http://monitor.sovereign.lab:19999`
    

## 6. Addendum: Pending Issues & Resolution Roadmap

### A. Reverse Proxy / Web Portal Integration

- **Status:** Pending (Scheduled for Next Session).
    
- **Impact:** Currently, accessing the dashboard requires appending the specific `:19999` port to the URL, which is not ideal for a clean enterprise architecture.
    
- **Planned Resolution:** Deploy a Web Portal/Reverse Proxy container (LXC 105 - Nginx/Nginx Proxy Manager). This will strip the need for ports, allowing access via a clean URL like `http://monitor.sovereign.lab` or through a unified lab dashboard at `http://portal.sovereign.lab`.
    

### B. Expanding Telemetry (Node Linking)

- **Status:** Single-node monitoring only.
    
- **Impact:** Netdata is currently only watching the host hardware (via the shared kernel) and LXC 103's specific network traffic. We lack granular insight into the Core-Router's FRR routing engine and the DNS server's load.
    
- **Planned Resolution:** Install lightweight Netdata "child" agents on the Core-Router (LXC 100) and DNS-Primary (LXC 104). Stream their metrics back to `monitor.sovereign.lab` so all lab infrastructure can be viewed from a single, centralized dashboard.