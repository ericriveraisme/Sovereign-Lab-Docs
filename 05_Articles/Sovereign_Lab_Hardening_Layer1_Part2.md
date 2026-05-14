# Sovereign Lab: Hardening Layer 1 — Part 2: The Chaos Test & Hardware Realities

**Status:** Draft — Pending Voice/Narrative Rework
**Publish Target:** 2026-05-14
**Series:** Layer 1 Hardening (Part 2 of 4)
**Tags:** Proxmox, NUT, WinNUT, UPS, Chaos Test, PSU, CMOS, Homelab

---

## Context

In Part 1, we successfully established out-of-band management via Tailscale and configured the Proxmox hypervisor as the NUT Master. The core telemetry was flowing, and automated event alerts were routing through Postfix. The next step was integrating the heavy-compute Windows node, Bahamut, as a NUT Slave, and executing the ultimate validation: **The Chaos Test**.

A disaster recovery plan is purely theoretical until you pull the plug from the wall. When I finally cut the power to the Sovereign Lab, the core hypervisor performed flawlessly — surviving for over 48 minutes before gracefully shutting down at the critical 10% battery threshold. However, integrating a modern Windows desktop and high-end enthusiast hardware into an enterprise-style power shedding cascade revealed several edge-case hardware realities that required deep, low-level troubleshooting.

---

## The Sacrificial Node: Taming the WinNUT Client

The architectural goal was to have Bahamut (the power-hungry GPU node) instantly shut itself down during an outage, shedding the load and preserving the UPS battery exclusively for the Proxmox VMs.

During the Chaos Test, Bahamut ignored its custom timers and stubbornly stayed online until Proxmox issued the final network-wide kill command.

Troubleshooting the modern `gawindx` fork of WinNUT-Client revealed two critical configuration traps:

1. **The Runtime Misinterpretation:** The GUI setting for *"Shutdown if runtime lower than"* does not measure elapsed time on battery — it measures the UPS's calculated *remaining* time. Setting this to 120 seconds meant the PC would wait until the battery was almost entirely dead before acting.

2. **The Immediate Action Flag:** The *"Immediate stop action"* box must be checked. Otherwise, local percentage thresholds are treated merely as warnings while the client waits for the master node's permission to shut down.

3. **Windows Protections:** Because WinNUT runs in user space rather than as a strict system service, Windows will block its shutdown commands to "protect" unsaved work. Overriding this required a registry edit:

   ```
   Registry Path: Computer\HKEY_CURRENT_USER\Control Panel\Desktop
   String Value:  AutoEndTasks = 1
   ```

---

## Hardware Realities: PSU Breakers and Memory Training Amnesia

Once power was restored, Proxmox booted perfectly. Bahamut, however, was completely dead — power button unresponsive. This led to a cascade of low-level hardware interventions.

### The PSU "Killpower" Hangover

When a UPS battery exhausts itself, it executes a hard power cut to the outlets to prevent deep-discharging the lead-acid cells. Bahamut's high-efficiency Active PFC power supply detected this sudden, "dirty" voltage drop, panicked, and tripped its internal safety breaker.

**Fix:** A complete 60-second "flea power" discharge — unplugging the wall cable and holding the chassis power button to drain the residual standby capacitors before the PSU would allow the motherboard to wake up.

### Clearing CMOS on an Intel "KF" Processor

During triage, I shorted the JBAT1 pins to clear the CMOS. On a modern motherboard paired with an Intel i7-10700KF (a processor with physically disabled integrated graphics) and a dedicated RX 7800 XT, this caused a severe POST hang. The motherboard forgot its memory timings and PCIe lane configurations, resulting in a persistent white CPU debug light.

**Resolution:** The classic **Single-Stick RAM Trick** — removing the GPU and all memory, placing exactly one stick of RAM in the primary A2 slot, and forcing the CPU to run a bare-minimum memory retraining algorithm. Once the system successfully POSTed, all components were safely reinstalled.

---

## Closing the Loop: Wake-on-LAN

The final lesson of the Chaos Test revolved around the "Restore on AC Power Loss" BIOS setting. This feature only triggers if a computer physically loses power while turned on. Because Bahamut executed a **graceful OS shutdown** via WinNUT, its motherboard entered a soft-off (S5) state. When the UPS restored wall power, Bahamut stayed asleep.

To achieve true zero-touch recovery, the architecture was updated to use **Wake-on-LAN (WoL)**. Proxmox — which *does* suffer hard power loss at 10% battery — boots automatically when AC power returns. It is now configured with a delayed cron job to fire a magic packet across the switch, manually waking Bahamut from S5:

```bash
@reboot sleep 45 && /usr/sbin/etherwake AA:BB:CC:DD:EE:FF
```

---

## Lessons Learned Summary

| Issue / Symptom | Root Cause | Architectural Fix |
|:---|:---|:---|
| Node ignored shutdown timers | WinNUT GUI parameters misunderstood; Windows blocked app shutdown | Enable Immediate stop action; Set `AutoEndTasks=1` in Registry |
| Node completely unresponsive to power button | PSU safety circuits tripped by "dirty" UPS killpower drop | 60-second hardware "flea power" capacitive discharge |
| CPU Debug Light / POST failure after CMOS clear | Motherboard memory training failure on complex hardware profile | Strip GPU; single-stick RAM in slot A2; force re-train |
| Node fails to auto-boot when power restores | BIOS AC Recovery ignores nodes in S5 (graceful shutdown) state | Disable Windows Fast Startup; configure Proxmox to issue WoL magic packet on boot |

With the hardware idiosyncrasies documented and mitigated, the Sovereign Lab is primed for a flawless, end-to-end disaster recovery validation.
