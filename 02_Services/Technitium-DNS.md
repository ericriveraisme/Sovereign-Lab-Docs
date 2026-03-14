# 🏛️ Sovereign Lab: Technitium DNS As-Built Documentation

## 1. Container Provisioning (Proxmox Host)

The container was provisioned on the Proxmox host to act as the primary lightweight DNS resolver for the `10.0.10.0/24` management VLAN.

- **LXC ID:** `104`
    
- **Hostname:** `dns-primary`
    
- **OS Template:** `ubuntu-24.04-standard_24.04-1_amd64.tar.zst`
    
- **Storage:** `Sovereign_VMs` (1 Core, 1024 MB RAM)
    
- **Network Interface (`eth0`):**
    
    - Bridge: `vmbr0`
        
    - IPv4: `10.0.10.53/24`
        
    - Gateway: `10.0.10.1` (Core-Router)
        

**Creation Command Used:**

```
pct create 104 local:vztmpl/ubuntu-24.04-standard_24.04-1_amd64.tar.zst \
  --hostname dns-primary \
  --password [redacted] \
  --net0 name=eth0,bridge=vmbr0,gw=10.0.10.1,ip=10.0.10.53/24 \
  --storage Sovereign_VMs \
  --memory 1024 \
  --cores 1 \
  --start 1
```

## 2. Pre-Installation OS Configuration

To bypass the Proxmox host's Tailscale MagicDNS inheritance (which prevented LXC 104 from reaching the internet to download its packages), a manual DNS override was applied via the Proxmox shell:

```
pct set 104 --nameserver "1.1.1.1 8.8.8.8"
pct restart 104
```

## 3. Application Installation

Installed via the official automated bash script inside LXC 104:

```
curl -sSL [https://download.technitium.com/dns/install.sh](https://download.technitium.com/dns/install.sh) | sudo bash
```

## 4. Technitium UI Configuration (`http://10.0.10.53:5380`)

### A. General Settings

- **Admin Password:** Changed from default to a secure password.
    
- **Settings > General > DNS Server Name:** Set to `dns.sovereign.lab`. (This ensures the server identifies itself properly during `nslookup` requests instead of returning "UnKnown").
    

### B. Proxy / Forwarders

- **Settings > Proxy/Forwarders > Forwarders:**
    
    - `1.1.1.1` (Cloudflare)
        
    - `8.8.8.8` (Google)
        
- **Enable Recursion:** `Checked` (Allows the server to fetch answers from the forwarders for public domains).
    

### C. Forward Lookup Zones (Names to IPs)

- **Zone Name:** `sovereign.lab` (Type: Primary)
    
- **A Records Added:**
    
    - Name: `dns` | IP Address: `10.0.10.53`
        
    - Name: `monitor` | IP Address: `10.0.10.20`
        
    - Name: `ops` | IP Address: `10.0.10.25` _(Note: Prepared/suggested for the Sovereign Ops VM)_
        

### D. Reverse Lookup Zones (IPs to Names)

- **Zone Name:** `10.0.10.in-addr.arpa` (Type: Primary)
    
- **PTR Records Added:**
    
    - Name: `53` | Domain Name: `dns.sovereign.lab`
        
    - Name: `20` | Domain Name: `monitor.sovereign.lab`
        

### E. Explicitly Removed/Disabled Configurations

- **Tailscale Conditional Forwarder (`tail54e211.ts.net`):** A forwarder zone pointing to `100.100.100.100` was created but **deleted**.
    
    - _Reasoning:_ LXC 104 does not have a route to the Tailnet `100.x.x.x` subnet. Leaving this active caused `DnsClientNoResponseException` timeouts and server failures.
        

## 5. Network & Client Integrations

To ensure the lab uses this new Source of Truth, the following external settings were applied:

- **Proxmox Host (Node) DNS:**
    
    - Search Domain: `sovereign.lab`
        
    - DNS Server 1: `10.0.10.53`
        
    - DNS Server 2: `1.1.1.1`
        
    - _(This forces all newly created LXCs to inherit Technitium as their DNS instead of Tailscale)._
        
- **Bahamut (Windows Workstation) Network Adapter:**
    
    - Static DNS set to `10.0.10.53` as Primary and `1.1.1.1` as Alternate.

## 6. Addendum: Pending Issues & Resolution Roadmap

### A. Proxmox DNS Record Inheritance & Updating
* **Symptom:** Despite updating the Proxmox Node's global DNS settings to point to `10.0.10.53`, DNS records and settings in Proxmox are not updating or applying to containers as expected. 
* **Impact:** Newly created or existing LXCs may still struggle with DNS resolution or fall back to stale configurations (like the host's Tailscale MagicDNS). This currently requires manual intervention (e.g., `pct set <id> --nameserver`) to force connectivity.
* **Planned Resolution:** Investigate Proxmox's `/etc/resolv.conf` symlink behavior, which is often heavily manipulated by `systemd-resolved` or the host-level Tailscale daemon. We need to ensure the host's network bridge reliably passes the new `10.0.10.53` DNS settings to the `lxc.net.0` configuration during container provisioning.

### B. Tailscale MagicDNS Integration (The `.ts.net` Barrier)
* **Symptom:** Technitium cannot currently act as a Conditional Forwarder for the Tailscale domain (`tail54e211.ts.net`).
* **Impact:** Lab services and VMs that rely solely on Technitium for DNS cannot resolve your Tailscale machine names (e.g., `bahamut.tail54e211.ts.net`). 
* **Root Cause:** LXC 104 (dns-primary) exists purely on the `10.0.10.0/24` subnet and does not have the Tailscale daemon installed. It currently has no Layer 3 route to reach the `100.100.100.100` Tailscale resolver.
* **Planned Resolution:** Architect a "Subnet Router" or "Gateway" solution. Future phases will involve either configuring the Core-Router (LXC 100) to properly route `100.x.x.x` traffic into the Tailnet, or deploying a dedicated Gateway LXC to bridge the local lab DNS with the Tailscale network.