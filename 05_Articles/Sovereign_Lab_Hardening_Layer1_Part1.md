# Sovereign Lab: Hardening Layer 1 — Part 1: Securing Physical Power

**Date:** May 2026
**Author:** Eric Rivera
**Category:** Systems Engineering / Disaster Recovery / Learning in Public
**Series:** Layer 1 Hardening (Part 1)

---

If you read the last entry in this series — *Hubris, Hardening, and the Resurrection of the Sovereign Lab* — you already know the shape of this story. Hard power cut. Dead OS drive. GRUB rescue shell at 2 AM. A full bare-metal rebuild from backup tapes while the hypervisor sat there looking guilty.

The lab came back. The VMs were restored. The routing was clean, the DNS was authoritative, and the stateful firewall rules survived the cold boot without a scratch. By every reasonable definition, the disaster recovery was a success.

But there was a sentence at the end of that article that I haven't been able to shake:

*"It's a story about hubris, because I knew I needed a UPS and didn't buy one."*

That's the part that keeps the lights on in your head at 3 AM. The disaster wasn't unlucky. It was scheduled. Power fluctuations happen. Brownouts happen. Storms happen. The only reason the lab went down that way was because I let the hard problem become someone else's future problem — and then became the someone else who had to deal with it.

So this series is about doing the thing I should have done before that random Tuesday ever happened. It's about securing **Layer 1: Physical Power** — not just with a UPS on a shelf, but with a full automated power management architecture that can survive an outage and bring the entire lab back online without me touching a single power button.

Here's how I am building it.

---

## The Problem Is More Complicated Than "Buy a UPS"

When people think about UPS protection for a homelab, the mental model is simple: box goes between the wall and the computer, computer stays on when power goes out. Done.

The reality, especially when you're running high-end hardware, is considerably messier.

Both my Proxmox hypervisor and my heavy-compute Windows node (Bahamut, running an Intel i7-10700KF and an AMD Radeon RX 7800 XT) use high-efficiency **Active Power Factor Correction (Active PFC)** power supplies. These units are tuned to work with the smooth, sinusoidal waveform of utility power — and they are notoriously intolerant of "dirty" power. Most consumer UPS units, especially the cheaper ones, don't actually produce a true sine wave on battery. They produce a **stepped approximation** — a blocky, staircase waveform that looks vaguely sinusoidal if you squint.

Active PFC power supplies don't squint. They see that stepped waveform, panic, and either shut down or behave erratically. The very thing that's supposed to protect your hardware becomes another potential failure mode.

So the requirement was clear: **Pure Sine Wave output on battery.** That narrows the field significantly, and the units that fit that spec are typically marketed at enterprise customers with enterprise budgets.

The other problem: I have two machines that need protection, not one. The naive solution — buy a UPS per machine — works fine if you have the budget and the outlet space. I had neither. I needed to think about this differently.

---

## The Architectural Workaround: Network UPS Tools

The solution was **NUT — Network UPS Tools**. It's an open-source daemon that has been quietly doing important work in server rooms for decades, and it solved both problems at once.

The concept is elegant: instead of connecting a UPS to every machine, you connect **one UPS to one machine**, and that machine reads the battery telemetry over USB and broadcasts it across the local network on TCP port `3493`. Every other machine on the network that's running a NUT client can subscribe to that broadcast, watch the same telemetry in real time, and react to power events on their own.

One UPS. One USB cable. Every machine on the network knows exactly what's happening with the battery at any given moment.

This turns a hardware purchasing problem into a software architecture problem — which, frankly, is a trade I will make every single time.

The topology breaks down like this:

- **NUT Master:** The node physically connected to the UPS via USB. Reads the hardware telemetry, runs `upsd` to broadcast it on the network, and is responsible for coordinating the shutdown cascade when the battery gets critical. In the Sovereign Lab, this is the Proxmox hypervisor.
- **NUT Slave:** Any node that polls the Master for telemetry and executes its own shutdown logic based on what it sees. In the Sovereign Lab, this is Bahamut.

---

## The Hardware: An Open Secret in the IT Community

For the UPS itself, I went with an **Amazon Basics 1500VA / 900W Line-Interactive Pure Sine Wave UPS**. This unit has a quiet reputation in homelab and SMB circles: it's a white-labeled **CyberPower CP1500PFCLCD**. Same hardware, same internals, meaningfully lower price point on Amazon. If you look up the NUT compatibility list for the CP1500PFCLCD, the Amazon Basics unit inherits every bit of that support.

1500VA / 900W gives me a comfortable headroom margin. At the Proxmox host's idle draw plus Bahamut running a couple VMs, I'm nowhere near the rated capacity — which translates to a long runtime on battery before the cascade needs to kick in. More on how long exactly in Part 2, when we actually pull the plug and find out.

---

## Step 0: Out-of-Band Management, or "How I Did All of This From Work"

Here's the detail that I'm most proud of in this entire build, not because it's the most technically complex thing I've done, but because it's the thing that *mattered* the most on the day I actually needed it.

I configured the entire Layer 1 power management stack — from scratch, including the UPS driver binding — while sitting at my office desk, miles from the house, during a normal Tuesday workday.

This was possible because of a decision I made much earlier in the Sovereign Lab's life: deploying **Tailscale** directly onto the **bare-metal Proxmox OS**, not inside a VM or container. The distinction is critical. If Tailscale lived in a VM, and the VM host was the thing I needed to troubleshoot, the tunnel would go down the moment I touched anything. By putting it on the bare metal, the out-of-band path stays alive regardless of what's happening to the virtualized network fabric above it.

From the office, I had:

1. **Direct SSH into the Proxmox hypervisor** over the Tailscale tunnel — completely bypassing the FRRouting edge firewall that controls all other network ingress.
2. **Proxmox Web GUI access** at `https://[Tailscale-IP]:8006` — no port forwarding, no exposed surface on the home router.
3. **Zero-Touch PKI authentication** using an `ed25519` key pair — so even if someone intercepted the tunnel, there was no password to brute-force.

The point of an out-of-band management plane is that it exists precisely for the moments when the in-band path is broken. This was one of those moments, and it worked exactly as intended.

---

## Configuring the NUT Master: Taming the Linux Kernel

With a shell open on the Proxmox host, the first task was getting NUT installed and bound to the UPS hardware.

```bash
apt update && apt install nut nut-client -y
```

Setting NUT to `netserver` mode in `/etc/nut/nut.conf` tells it to run as a server — broadcasting telemetry to the network rather than running as a local client.

The hardware binding is configured in `/etc/nut/ups.conf`. The `usbhid-ups` driver handles the CyberPower USB protocol, and `port = auto` lets the kernel find the device without hard-coding a path:

```ini
[amazon-ups]
  driver = usbhid-ups
  port = auto
  desc = "Amazon Basics 1500VA UPS"
```

Then I ran into the wall that every Linux administrator runs into when dealing with USB hardware: the kernel's default security posture.

Linux applies strict default permissions to USB device files. When the `usbhid-ups` driver tried to bind to the UPS for the first time, it didn't have the right permissions yet. The daemon threw a `Driver not connected` error and refused to proceed. Normally, the fix is straightforward: unplug the USB cable and replug it, which triggers the kernel to re-evaluate device permissions from scratch.

Except I was in an office. The UPS was at home. I wasn't replugging anything.

The workaround is to use `udevadm` — the Linux device manager — to force the kernel to reload its rules and re-trigger the permission evaluation without physical intervention:

```bash
udevadm control --reload-rules
udevadm trigger
upsdrvctl stop && upsdrvctl start
```

`udevadm trigger` effectively simulates the "replug" event in software, causing the kernel to re-run its rule evaluation against all currently connected devices. The driver caught the permission update, bound to the hardware, and connected cleanly.

If you're ever configuring NUT on a headless server you can't physically touch, file this one away. It will save you a trip.

With the driver bound, I configured `upsd` to listen on all interfaces and set up the two access profiles in `upsd.users` — one for the Proxmox master itself (`proxmox-admin`) and one for Bahamut to authenticate as a slave (`bahamut-client`). Then I opened TCP port `3493` in the Proxmox Datacenter firewall and verified the live telemetry stream was broadcasting:

```bash
upsc amazon-ups@localhost
```

The output showed what I needed to see: `ups.status: OL` — On Line. Wall power present. Battery at 100%. The UPS was talking, and Proxmox was listening.

---

## The Alerting Pipeline: Teaching the Lab to Talk

A UPS that silently manages a power event isn't good enough. If the power goes out at 2 AM and my Proxmox host gracefully shuts down — and I have no idea — I'm waking up the next morning to a dead lab and no context for why. That's not acceptable.

Infrastructure must self-report. The lab needs to be able to reach out and tell me what's happening.

I wired the NUT event system into the Proxmox host's existing Postfix mail relay using the `NOTIFYCMD` directive and `+EXEC` flags in `upsmon.conf`. When `upsmon` detects a critical state change — specifically the `ONBATT` (On Battery) and `LOWBATT` (Low Battery) events — it immediately calls an alerting script:

```bash
# /usr/local/bin/nut-alert.sh
echo "SOVEREIGN LAB ALERT: UPS power event. Status: $(upsc amazon-ups@localhost ups.status)" \
  | mail -s "UPS ALERT: Power Event Detected" admin@example.com
```

Event-driven is the critical one — it fires the millisecond the UPS detects a wall power loss. But I added a second, scheduled layer as well: a cron job that runs every Monday morning and generates a weekly health digest:

```
0 8 * * 1 /usr/local/bin/ups-report.sh
```

The weekly report distills the raw `upsc` output into a readable snapshot: battery charge percentage, current load wattage, estimated runtime at current draw, and input voltage from the wall. It's not exciting reading. It's not supposed to be. It's the kind of thing you glance at on a Monday morning and say "good" and move on — until one Monday when the runtime estimate is 40% lower than last week and you realize the battery is starting to age.

Both pipelines were tested remotely before I left the office. The event alert fired clean. The weekly report landed in my inbox formatted exactly as intended. The lab had learned to talk.

---

## What's Been Built — and What's Still Missing

At this point, the Sovereign Lab has a functioning NUT Master. The Proxmox host is reading the UPS telemetry, broadcasting it on the network, and alerting me the moment power conditions change. If the wall power cuts out right now, Proxmox will gracefully shut itself down before the battery drains — and I'll have an email in my pocket before the lights even stop flickering.

But Bahamut is still completely unprotected.

That high-efficiency Active PFC power supply. That GPU. All of that power draw pulling from the same UPS battery that Proxmox is now trying to protect. Without a slave configuration on Bahamut, there's no coordination. Bahamut just keeps running — burning through battery capacity that Proxmox needs to execute a clean shutdown — until the UPS runs dry and everything dies hard anyway.

That's the next problem. And fixing it requires being physically at the machine, which means waiting until I get home.

**Next: The Chaos Test.** We configure Bahamut as the sacrificial node — the machine that sheds load first, buying time for the hypervisor. And then we do the thing that makes all of this real: walk over to the wall, pull the plug, and find out if the architecture actually works.

---

*Eric Rivera — Sovereign Lab Architect (in training)*
*Learning in public, one power event at a time.*
