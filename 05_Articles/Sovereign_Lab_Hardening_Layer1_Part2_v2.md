# Sovereign Lab: Hardening Layer 1 — Part 2: The Chaos Test & Hardware Realities

**Date:** May 2026
**Author:** Eric Rivera
**Category:** Systems Engineering / Disaster Recovery / Learning in Public
**Series:** Layer 1 Hardening (Part 2)

---

At the end of Part 1, the Sovereign Lab had a functioning NUT Master. The Proxmox hypervisor was reading live telemetry from the UPS, broadcasting it across the network, and capable of executing a graceful shutdown before the battery ran dry. The alerting pipeline was verified. The out-of-band management tunnel was holding.

The problem was Bahamut.

That i7-10700KF. That RX 7800 XT. All of that power draw — running from the same UPS battery that Proxmox was now counting on for its survival window. Without a slave configuration on Bahamut, there was no coordination, no priority, no cascade. If the power cut out, both machines would just keep running side by side until the UPS gave up, and everything would die hard regardless of how well the NUT Master was configured.

The fix required being physically at the machine. So I went home, sat down at Bahamut, and got to work.

---

## Configuring the Sacrificial Node

The architectural intent here is deliberate and a little brutal: **Bahamut is designed to die first.**

Not because Bahamut doesn't matter, but because the Proxmox hypervisor matters more. The VMs, the Core-Router, the DNS server, the network fabric — all of that lives on Proxmox. Bahamut is heavy compute. Important, but replaceable in a power event. The strategy is to have Bahamut aggressively shed its load at an early battery threshold, handing that capacity back to the UPS exclusively for Proxmox to use during its graceful shutdown sequence.

This kind of coordinated sacrifice is exactly what the NUT master/slave architecture is built for.

I installed the `gawindx` fork of WinNUT-Client on Bahamut and pointed it at the Proxmox host:

```
MONITOR ups@192.168.0.232 1 bahamut-client <PASSWORD> slave
```

The credentials came from the `upsd.users` file I'd already set up on the Proxmox side. The handshake verified cleanly — Bahamut could see the live battery telemetry. `OL`. On Line. 100% charge. Ready.

I set the shutdown threshold to 70% battery and configured what I thought were the right timers. Then I walked over to the wall.

---

## The Chaos Test, Attempt One

I pulled the plug.

The UPS alarm sounded immediately — a steady, insistent beep that is specifically designed to make you feel like you've done something wrong. Which, technically, I had. Intentionally.

The core hypervisor behaved exactly as designed. `upsmon` on Proxmox detected the `OB` (On Battery) state within seconds. The alert email fired. I watched the battery percentage tick down in the Proxmox dashboard.

Bahamut did nothing.

At 70% battery — the threshold I'd configured — Bahamut was still sitting at the Windows desktop, completely indifferent to the situation. 60%. 50%. Bahamut kept running. I watched it eat through the battery capacity that was supposed to be Proxmox's safety margin, and at some point I made the call: plug the power back in and figure out what went wrong before we actually drain the battery.

The software had been silently misconfigured in two separate ways simultaneously, which is the kind of thing that makes you feel both stupid and impressed at the same time.

---

## The Two Configuration Traps

### Trap 1: The Runtime Misinterpretation

The WinNUT GUI has a setting: *"Shutdown if runtime lower than [X] seconds."*

Reading that, the natural interpretation is: "shut down if we've been running on battery for more than X seconds." Elapsed time. A countdown from the moment the power cut out.

That is not what it measures.

It measures the UPS's *remaining* runtime estimate — the battery management system's calculation of how many seconds of capacity are left at the current load. The two numbers can look similar in the early minutes of a power event, which is why the misconfiguration isn't immediately obvious. But they diverge quickly. Setting the timer to 120 seconds doesn't mean "shut down after two minutes on battery." It means "shut down when the UPS calculates it has less than two minutes of charge remaining" — which, at 70% battery with a 1500VA unit running modest loads, might be 30 or 40 minutes into the event.

By the time that threshold triggers, the whole point of early load shedding is already gone.

### Trap 2: The Immediate Action Flag

WinNUT has a checkbox in its configuration: *"Immediate stop action."*

When this is unchecked, percentage-based thresholds like "shut down at 70% battery" are treated as local *warnings* only. The client logs the condition, maybe shows a notification, but doesn't actually execute the shutdown. It waits for the NUT Master to broadcast an explicit Forced Shutdown (FSD) signal before doing anything.

The FSD signal only comes from Proxmox when *Proxmox* hits its own Low Battery threshold — by which point the whole load-shedding strategy has already failed.

Enabling *Immediate stop action* changes the behavior: the local threshold now triggers an immediate, unconditional shutdown without waiting for master permission. Which is exactly what "sacrificial node" means.

### Trap 3: Windows Won't Let You Shut Down

With both traps corrected, I ran a controlled test — and hit a third problem. WinNUT issued the shutdown command. Windows acknowledged it. And then a dialog box appeared asking if I wanted to close a background application that had "unsaved changes."

Windows, in its infinite wisdom, was protecting me from myself. By default, the OS will block or delay a shutdown if any application objects to it — even unattended background processes. This is a reasonable behavior for a desktop operating system. It is a catastrophic behavior for an automated power management system.

The fix was a registry edit that tells Windows to stop asking and just terminate everything:

```
HKEY_CURRENT_USER\Control Panel\Desktop
AutoEndTasks = 1
```

With that set, the shutdown command is unconditional. No dialogs. No negotiation. When WinNUT says it's time to go, it's time to go.

---

## The Chaos Test, Attempt Two

Three fixes applied. I walked back over to the wall.

This time, the cascade ran exactly as intended. The UPS alarm sounded. Proxmox detected `OB` and fired the alert email. As the battery ticked toward 70%, WinNUT on Bahamut registered the threshold, checked the `Immediate stop action` flag, and issued the unconditional shutdown. The GPU spun down. The fans stopped. Bahamut was off.

The load on the UPS dropped noticeably as Bahamut's draw disappeared from the circuit.

Proxmox continued running — now with significantly more battery headroom — until the UPS reached the hardware Low Battery threshold at around 10% charge. At that point, the `LB` flag propagated to Proxmox's `upsmon`, which gracefully suspended all running VMs and LXCs and halted the hypervisor. The UPS executed a killpower sequence to protect the lead-acid cells from deep discharge.

Total runtime from the plug pull to Proxmox halt: **over 48 minutes.**

The software architecture had worked perfectly.

---

## Then the Power Came Back On

I plugged the UPS back into the wall. The UPS clicked. Power restored.

Proxmox came up automatically — the BIOS "Restore on AC Power Loss" setting doing exactly what it was configured to do. The VMs with Start at Boot enabled initialized in sequence. The Core-Router came up, FRRouting rebuilt its routing table, and the network fabric reassembled itself cleanly.

Bahamut did not come back.

Not a flicker. Not a failed POST. The chassis was simply dark. The power button produced no response whatsoever.

---

## The PSU Killpower Hangover

The culprit was the UPS's final protective act, and it's worth understanding what actually happens when a UPS exhausts its battery.

A lead-acid battery that is discharged below a certain voltage threshold suffers permanent damage. To prevent this, UPS firmware doesn't just let the battery slowly drain to zero — it executes a **killpower** sequence. At some point near the critical threshold, the UPS completely cuts power to all outlets. Hard. Immediate. No gradual ramp-down, no soft transition.

From the perspective of Bahamut's high-efficiency Active PFC power supply, this looks like a sudden, violent voltage collapse on the input rail. Active PFC units are designed to regulate smoothly across a wide input range — but they are not designed for instantaneous input drops. Bahamut's PSU detected the anomaly, panicked, and tripped its internal protection circuit. The breaker inside the PSU opened to protect the components downstream.

The result: a perfectly functional machine that refuses to acknowledge the existence of the power button, because the internal circuitry is sitting behind an open breaker that doesn't reset on its own.

**The fix is deeply counterintuitive:** you have to fully discharge the residual capacitive energy stored in the PSU before the protection circuit will reset.

1. Unplug the power cable completely from the wall and the PSU.
2. Press and hold the chassis power button for a full **60 seconds**.
3. The button press drains the remaining charge from the PSU's internal capacitors through the motherboard — what technicians call "flea power."
4. Once the capacitors are empty, the protection circuit resets.
5. Reconnect the power cable. Normal power-on resumes.

After the 60-second drain, Bahamut posted cleanly and booted into Windows without issue.

---

## The CMOS Clear Rabbit Hole

During triage — before I'd diagnosed the PSU issue — I had cleared the CMOS trying to rule out a POST problem. On most hardware, CMOS clear is a routine operation. On this specific hardware configuration, it was not.

Bahamut's motherboard is paired with an Intel **i7-10700KF** — the "KF" suffix indicating that the integrated graphics are physically disabled on the silicon. There is no iGPU fallback. The only display output comes from the discrete RX 7800 XT.

When CMOS is cleared, the motherboard loses its memory training profile and PCIe configuration. On the next boot, it starts from absolute zero — trying to initialize memory, train the IMC, and configure PCIe lanes all at once, on a complex hardware profile, with no iGPU to output diagnostic video. The result was a persistent white CPU debug light and a machine that sat at a blank screen indefinitely, giving no indication of what was happening internally.

The resolution is the **Single-Stick RAM Trick**:

1. Remove the GPU entirely.
2. Remove all but one stick of RAM.
3. Place that single stick in the primary training slot (A2 on most boards).
4. Power on without the GPU — the board will train memory against the simplest possible configuration.
5. Once POST completes and BIOS is accessible, verify the baseline settings.
6. Power off, reinstall GPU and remaining RAM, boot normally.

It worked. The board retrained, the white debug light cleared, and the system came up to BIOS. All hardware reinstalled without issue.

Filed, documented, and absolutely going to happen again the next time I clear the CMOS — so it's good to have it written down.

---

## The Last Problem: Bahamut Won't Wake Up

With the PSU back online and hardware verified, I hit the final gap in the architecture.

When power was restored, Proxmox came back automatically. Bahamut didn't. And the reason is a subtle but important distinction in how BIOS power recovery settings actually work.

The *"Restore on AC Power Loss"* setting only applies to machines that **lost power while running**. It handles the case where the machine was on, power cut unexpectedly, and now power has returned — the BIOS triggers a boot cycle to return to the previous state.

But Bahamut didn't lose power while running. Bahamut executed a **graceful OS shutdown** via WinNUT before the UPS ever cut the outlets. When the OS shutdown completed, Bahamut entered an **S5** state — soft power off. The motherboard is technically "on" in the sense that standby power is present, but the system is fully halted. S5 is a completely different power state than hard power loss, and the BIOS AC recovery mechanism doesn't touch it.

So when the UPS restored power, the BIOS saw: "power returned, but the last known state was S5." Recovery policy: do nothing.

The solution is **Wake-on-LAN**. WoL allows a machine in S5 to be powered on remotely by sending a specially formatted network packet — a "magic packet" — to its MAC address. The NIC stays powered in a low-power listening state even in S5, waiting for the signal.

The updated architecture:

- Windows Fast Startup disabled on Bahamut — required for a true S5 state that WoL can reach
- Ethernet adapter configured to wake on magic packet
- Proxmox configured with a boot-time cron job:

```bash
@reboot sleep 45 && /usr/sbin/etherwake <BAHAMUT_MAC>
```

The 45-second delay gives Proxmox time to fully initialize its network stack and bring up the internal bridges before firing the packet. After that window, the magic packet goes out, the NIC wakes Bahamut from S5, and the machine boots into Windows without anyone touching a button.

---

## What the Chaos Test Actually Taught

The table at the end of every post-mortem is the part people skip to. Here's mine, but read the sections above — the context is what makes these fixable next time.

| Symptom | Root Cause | Fix |
|:---|:---|:---|
| Bahamut ignored shutdown timer | WinNUT runtime setting measures *remaining* battery time, not elapsed | Switch to battery % threshold instead |
| Bahamut stayed online past % threshold | `Immediate stop action` unchecked — threshold treated as warning only | Enable `Immediate stop action` in WinNUT |
| Windows blocked the shutdown command | OS protection dialogs intercepted the automated shutdown | `AutoEndTasks = 1` in the registry |
| Bahamut power button unresponsive after restore | Active PFC PSU tripped internal breaker on dirty UPS killpower cut | 60-second flea power drain before reconnecting |
| POST hang / white debug light after CMOS clear | i7-10700KF has no iGPU; memory retraining fails on complex profile | Single-stick RAM in slot A2, no GPU, force retrain |
| Bahamut didn't auto-boot after power restore | BIOS AC recovery doesn't apply to machines in S5 (graceful shutdown) | Disable Windows Fast Startup; Proxmox fires WoL magic packet at boot |

---

*Eric Rivera — Sovereign Lab Architect (in training)*
*Learning in public, one blown PSU breaker at a time.*
