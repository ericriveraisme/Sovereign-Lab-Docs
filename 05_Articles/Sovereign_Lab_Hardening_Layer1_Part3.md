# Sovereign Lab: Hardening Layer 1 — Part 3: Native Services & Hardware Persistence

**Status:** Draft — Pending Voice/Narrative Rework
**Publish Target:** 2026-05-15
**Series:** Layer 1 Hardening (Part 3 of 4)
**Tags:** Proxmox, NUT, Windows Service, sc.exe, CMOS, BIOS, Chaos Test, Homelab

---

## Author's Note: Learning in Public

In Part 2, we discovered the limitations of user-space applications (like the WinNUT GUI) when trying to execute automated load shedding. Today, we ripped out the GUI and replaced it with a native Windows service, proving that true Infrastructure as Code (IaC) requires system-level persistence.

But as we quickly learned, the most bulletproof software architecture on earth can still be brought to its knees by a 10-cent CMOS battery. Here is the chronological log of how we pushed the Sovereign Lab's disaster recovery to the next level.

---

## Phase 1: Establishing the Master-Slave Link

The first step was binding our Windows workstation (Bahamut) to the Proxmox Master (PVE) which physically monitors the UPS.

- **Credential Sync:** Retrieved the `bahamut-client` credentials from the PVE host's `/etc/nut/upsd.users` file.
- **Client Configuration:** Configured Bahamut to act as a strict NUT Slave by editing `C:\NUT\etc\upsmon.conf`:

  ```
  MONITOR ups@192.168.0.232 1 bahamut-client <PASSWORD> slave
  ```

- Successfully verified the handshake in the foreground using the `.\nut.exe -N` command.

---

## Phase 2: Transitioning to a Native Windows Service

The previous architecture relied on WinNUT, a GUI wrapper. The fatal flaw: if no user was logged into Bahamut, the graceful shutdown would fail.

We migrated to the official `nut.exe` binary running as a background **Windows Service** (LocalSystem).

### Forcing the Service Registration

The specific Windows build of `nut.exe` we used lacked the internal `-i` installation flag. To bypass this, we used native Windows Service Control (`sc.exe`) to manually register the daemon:

```cmd
sc.exe create "NUT" binPath= "C:\NUT\bin\nut.exe" start= auto DisplayName= "Network UPS Tools"
```

### Telemetry Verification

With the service running, we used `.\upsc.exe amazon-ups@192.168.0.232` to verify live battery metrics and the crucial `OL` (On Line) status.

---

## Phase 3: Cross-Platform Execution & Threshold Logic

With telemetry established, we defined how Bahamut reacts to the UPS draining.

- **Threshold Strategy:** We opted to stick with the hardware's default "Low Battery" trigger (typically 10–20%) rather than creating a custom 65% override on the Proxmox master.
- **The Cross-Platform Logic Leak:** During configuration, we caught a critical cross-platform error. The default NUT configuration uses Linux/Unix paths for its shutdown execution (`/sbin/shutdown -h +0`). If triggered, Windows would simply throw a "File Not Found" error while the battery drained to zero.

  We corrected the `SHUTDOWNCMD` to use the native Windows executable with absolute paths:

  ```
  SHUTDOWNCMD "C:\\Windows\\System32\\shutdown.exe /s /t 0"
  ```

---

## Phase 4: The 10% Chaos Test & The Hardware Wall

With the service running, we unplugged the UPS from the wall. The software logic was flawless: at 10% battery, Proxmox broadcasted the **Final Shutdown (FSD)** signal, and Bahamut successfully executed a graceful `shutdown.exe /s /t 0`.

**The problem arose when the power was restored.**

### The AsRock Z77 Extreme4 Amnesia

When the UPS clicked back on, the Proxmox host powered up but immediately halted at a black screen reading:

> **"UEFI Defaults have been loaded. Press F1 to Continue."**

This was a textbook hardware failure unmasking itself during a software test. The 12-year-old motherboard's **CR2032 CMOS battery** had died. When the UPS cut the standby voltage to the PSU, the motherboard forgot the "Restore on AC Power Loss" setting we had enabled earlier in the day.

---

## Lessons Learned & Next Steps

| Node | Issue | The "Sovereign" Fix |
|:---|:---|:---|
| **Proxmox (Master)** | BIOS Amnesia / F1 Halt on Boot | Replace the CR2032 battery. Re-enable **Restore on AC Power Loss** → `Always On` and **Wait for F1 if Error** → `Disabled`. |
| **Bahamut (Slave)** | Remained powered off after grid restoration | Access BIOS and configure "State after G3" / "AC Power Recovery" to `Power On` or `Last State`. |

This exercise proved the ultimate rule of systems engineering: **Automation stops where the BIOS begins.**

A perfect software shutdown protocol is useless without a hardware-level 'Auto-Power-On' policy. By identifying the dead CMOS battery and locking in the native Windows service, the Sovereign Lab is now one step closer to true, zero-touch disaster recovery.
