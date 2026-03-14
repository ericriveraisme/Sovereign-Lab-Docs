# 🛰️ The DNS Handshake & The Ghost in the Machine: Hardening the Sovereign Lab

**Date:** March 14, 2026

**Author:** Eric

**Category:** Systems Engineering / Learning in Public

After 12 years in the "Help Desk" trenches, you’d think I’d be used to things just... breaking. But when you’re building your own Sovereign Data Center on your desk during an overnight shift, every "Connection Timed Out" feels personal.

Today, I hit a wall with my internal DNS routing that took me back to the basics of CCNA theory. Here’s how I moved past the "it's not working" phase and into "Persistence First" engineering.

## 🏗️ The Architecture: Why Not Just "Plug and Play"?

My lab runs on a Proxmox node partitioned with a "Router-on-a-Stick" topology. At the heart is `core-router` (an LXC running FRR).

- **Management VLAN 10:** `10.0.10.0/24`
    
- **DNS Server (Technitium):** `10.0.10.53`
    
- **Proxmox Host IP:** `192.168.0.232`
    

**The "Why":** Most home labs rely on the ISP router or a basic flat network. If I did that, I'd never learn how subnets actually interact. By isolating the lab behind an FRRouting (FRR) instance, I am forced to handle NAT, Masquerading, and Layer 3 transitions manually. It's the difference between driving an automatic and building the transmission from scratch.

## 👻 The Problem: The Ghost IP

The first hurdle was a "squatter" IP. My Core-Router's WAN interface (`eth0`) kept pulling `192.168.0.232` via DHCP alongside its static `.235`. This created a routing conflict—the router didn't know which IP to use for its default gateway out to the ISP, effectively killing my internet access across the entire lab.

**The Solution:** Instead of manually deleting it every time, I wrote a "Persistence First" eviction script.

**The "Why":** In a professional environment, you can't rely on "clicking around" to fix recurring issues. Automated remediation is the goal. I set this script to run on every reboot via `@reboot` in my crontab to ensure the environment is "clean" before the first packet ever moves.

```
#!/bin/bash
# Evict the Ghost IP to restore WAN routing
TARGET_IP="192.168.0.232/24"
INTERFACE="eth0"

if ip addr show $INTERFACE | grep -q $TARGET_IP; then
    ip addr del $TARGET_IP dev $INTERFACE
    echo "Ghost IP evicted."
fi
```

## 🗺️ The Routing Trap: Bridging the Gap

The second issue was more subtle. My Proxmox Host could see the Gateway (`10.0.10.1`), but it couldn't talk to the DNS server at `10.0.10.53`. I was trying to route traffic through an internal gateway before the host even knew where that gateway lived.

**The "Why":** This is a classic Layer 3 logic puzzle. The Proxmox Host (on the `192.168.0.x` subnet) has no inherent way to know that `10.0.10.x` lives inside the Core-Router unless I tell it. I had to point a static route on the Host toward the **WAN IP** of the router.

I made it stick through a reboot by editing `/etc/network/interfaces`:

```
# Added to /etc/network/interfaces under vmbr0
# Tells the host: "If you want to reach the Lab, go to the Router's WAN side"
post-up ip route add 10.0.10.0/24 via 192.168.0.235
```

## 🎯 The Result: Authority Secured

After a cold boot test (the ultimate "Chaos Test"), the infrastructure held. I ran the golden test from the host shell:

`nslookup dns.sovereign.lab 10.0.10.53`

**The Output:**

`Server: 10.0.10.53`

`Address: 10.0.10.53#53`

`Name: dns.sovereign.lab`

`Address: 10.0.10.53`

Success. My "Source of Truth" is finally authoritative.

## 💡 The Takeaway

Coming from 12 years in help desk, it’s easy to just look for the "Reboot" button. But in the Sovereign Lab, I’m learning to be the one who defines _why_ the reboot works. I'm moving away from being a "user of systems" to an "architect of systems." If you're learning in public like me, don't be afraid to break your routing table. That’s where the real lessons are hidden.

**Next Up:** Deploying **Pulse** for AI-driven monitoring. See you in the terminal.