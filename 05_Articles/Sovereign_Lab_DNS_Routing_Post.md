# 🛰️ The DNS Handshake & The Ghost in the Machine: Hardening the Sovereign Lab

**Date:** March 14, 2026

**Author:** Eric

**Category:** Systems Engineering / Learning in Public

---

After 12 years in the Help Desk trenches, you'd think I'd be used to things just... breaking. But when you're building your own Sovereign Data Center on your desk during an overnight shift, every "Connection Timed Out" feels personal.

I've been reading *Practical Linux System Administration* lately, and one idea from Chapter 1 keeps echoing in my head: the "Sysadmin Mindset" isn't just about fixing things — it's about understanding *why* they break, documenting the fix, and building a system so the problem never happens again. That's the lens I'm trying to apply to everything in this lab now.

Today, I hit a wall with my internal DNS routing that dragged me all the way back to CCNA theory. I'm sharing how I worked through it — with AI as a thinking partner and a lot of stubborn persistence — because I think the debugging process is where the real learning happens.

## 🏗️ The Architecture: Why Not Just "Plug and Play"?

My lab runs on a single Proxmox node using a "Router-on-a-Stick" topology. At the heart of it is `core-router` (LXC 100) — a lightweight container running FRRouting (FRR) that acts as the primary Layer 3 gateway for everything inside the lab.

- **Management VLAN 10:** `10.0.10.0/24` — the backbone where all core services live
- **DNS Server (Technitium):** `10.0.10.53` — the lab's internal "Source of Truth"
- **Proxmox Host:** `192.168.0.232` — sitting on the physical home network, outside the lab's VLAN

**The "Why":** Most home labs just let the ISP router handle DNS and routing. It works, but you never learn what's actually happening underneath. I chose to isolate everything behind FRR so I'd be forced to handle NAT, masquerading, and Layer 3 transitions by hand. It's the difference between driving an automatic and building the transmission from scratch.

The DNS side is intentional too. I'm running Technitium as a dedicated authoritative resolver with Cloudflare (1.1.1.1) as the upstream forwarder over DNS-over-TLS. No inherited ISP configurations. I wanted a DNS server that I own, that I configured, and that I can point every machine in the lab toward. It resolves `dns.sovereign.lab`, `monitor.sovereign.lab`, `ops.sovereign.lab` — all records I defined. That's why I call it the "Source of Truth."

## 👻 The Problem: The Ghost IP

The first hurdle was a "squatter" IP. My Core-Router's WAN interface (`eth0`) kept pulling `192.168.0.232` via DHCP alongside its static `.235`. Two IPs, one interface, and the kernel didn't know which one to use for the default gateway. The result: internet access across the entire lab dropped.

This was the kind of problem that, in a help desk mindset, you'd fix manually and move on. Run `ip addr del`, confirm it's gone, keep working. But it kept coming back on every reboot. And in a lab where I'm trying to practice "Persistence First" engineering — meaning *every* configuration survives a hard reboot — a manual fix is a failure.

**The Solution:** I wrote an eviction script and wired it into `@reboot` via crontab, so the ghost gets exorcised before the first packet ever moves.

There's a line I keep coming back to from Chapter 1 of that book: *"Laziness is a virtue."* Not the kind where you skip the work — the kind where you spend two hours automating a five-minute task because you know your future self will forget. That's what this script is. It's five lines of bash that mean I never have to think about this problem again.

```bash
#!/bin/bash
# Evict the Ghost IP to restore WAN routing
TARGET_IP="192.168.0.232/24"
INTERFACE="eth0"

if ip addr show $INTERFACE | grep -q $TARGET_IP; then
    ip addr del $TARGET_IP dev $INTERFACE
    echo "Ghost IP evicted."
fi
```

I also wrote a formal runbook for this in my documentation. It sounds like overkill for a home lab — but the discipline of documenting the *what*, *why*, and *how* for every fix is what separates reactive troubleshooting from building real operational knowledge.

## 🗺️ The Routing Trap: Bridging the Gap

The second issue was more subtle, and honestly, it's the one that taught me the most.

My Proxmox Host could ping the Gateway (`10.0.10.1`), but it couldn't talk to the DNS server at `10.0.10.53`. I stared at this for a while. The gateway was *right there*. How could it see the door but not walk through it?

The answer is a classic Layer 3 logic puzzle, and it clicked when I mapped it out: the Proxmox Host lives on `192.168.0.x` — the physical home network. The lab lives on `10.0.10.x` — a completely different subnet behind the Core-Router. The host has no inherent way to know that `10.0.10.x` exists unless I explicitly tell it: *"If you want to reach the lab, hand your packets to the router's WAN IP."*

This wasn't the only DNS-adjacent rabbit hole, either. Earlier in the build, I had Technitium configured with a Conditional Forwarder for Tailscale's MagicDNS domain (`tail54e211.ts.net`), which was silently causing `DnsClientNoResponseException` timeouts across the board. Removing that forwarder cleared the noise so I could actually see the routing problem underneath. Lessons like that are why I'm learning to test one layer at a time.

**The Fix:** A persistent static route in `/etc/network/interfaces`:

```
# Added to /etc/network/interfaces under vmbr0
# Tells the host: "If you want to reach the Lab, go to the Router's WAN side"
post-up ip route add 10.0.10.0/24 via 192.168.0.235
```

The `post-up` directive is key — it means this route gets applied every time the interface comes up, surviving every reboot. No manual intervention required. Persistence First.

## 🎯 The Result: Authority Secured

After a cold boot test — the ultimate "Chaos Test" — the infrastructure held. I ran the golden test from the host shell:

```
nslookup dns.sovereign.lab 10.0.10.53
```

**The Output:**

```
Server:  10.0.10.53
Address: 10.0.10.53#53

Name:    dns.sovereign.lab
Address: 10.0.10.53
```

That response means Technitium is answering authoritatively for the `sovereign.lab` zone. It's not forwarding, it's not guessing — it's resolving from records I defined. And because the architecture survived a full power cycle, I know it's not held together by luck or a warm cache.

Since this fix, the same DNS infrastructure has been extended to the rest of the lab. Netdata telemetry resolves at `monitor.sovereign.lab`, the management cockpit at `ops.sovereign.lab`, and reverse PTR records point back cleanly. One fix, and the whole naming layer clicked into place.

## 💡 The Takeaway

I'll be honest — I didn't figure all of this out alone. I used AI as a sounding board and a research partner throughout this process. When I was stuck on the routing logic, I talked it through with Copilot the same way I'd talk it through with a senior engineer. It didn't build the lab for me, but it helped me ask better questions and verify my understanding. I think being transparent about that matters, especially when you're learning in public.

Coming from 12 years in help desk, the instinct is to find the "Reboot" button and move on. But in the Sovereign Lab, I'm learning to be the one who defines *why* the reboot works. I'm moving away from being a "user of systems" toward being an "architect of systems" — someone who documents the intent in Obsidian, versions the config in Git, and builds automation that protects against my own future mistakes.

The book I'm reading puts it well: a good sysadmin doesn't just fix problems — a good sysadmin builds systems where the problem can never happen again. I'm not there yet. But every script, every runbook, and every article like this one gets me a little closer.

If you're learning in public like me, don't be afraid to break your routing table. That's where the real lessons are hiding.

**Next Up:** Deploying **Pulse** for AI-driven monitoring. See you in the terminal.
