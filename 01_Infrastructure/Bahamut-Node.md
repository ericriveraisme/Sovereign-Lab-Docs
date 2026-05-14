# 🖥️ Bahamut (Heavy Compute Node)

**Last Updated:** 2026-05-13
**Role:** Heavy Compute / GPU Node / NUT Slave / Tier 3 Storage Provider
**Status:** Active

---

## Node Specifications

| Component | Detail |
|:---|:---|
| **CPU** | Intel Core i7-10700KF (iGPU disabled — no integrated graphics) |
| **GPU** | AMD Radeon RX 7800 XT |
| **PSU** | High-efficiency Active PFC |
| **OS** | Windows 10/11 |
| **NUT Client** | WinNUT-Client (gawindx fork v2.1) |
| **Physical Location** | Home office — same physical switch as Proxmox host |

---

## Networking

| Property | Value |
|:---|:---|
| **IP Address** | `192.168.0.222` |
| **Proxmox Host** | `192.168.0.232` |
| **Layer** | Physical Layer 2 switch — direct to Proxmox host |
| **NUT Polling Target** | `192.168.0.232:3493` |
| **Tailscale** | Not installed on this node (Tailscale lives on Proxmox bare metal) |

---

## Role in DR Architecture

Bahamut acts as the **sacrificial node** in the NUT master/slave power cascade. Its job is to shed load *first*, preserving UPS battery capacity for the Proxmox hypervisor and its hosted VMs/LXCs.

### NUT Slave Configuration

- **Config file:** `C:\NUT\etc\upsmon.conf`
- **Monitor directive:**
  ```
  MONITOR ups@192.168.0.232 1 bahamut-client <PASSWORD> slave
  ```
- **NUT service registered as Windows Service (LocalSystem):**
  ```cmd
  sc.exe create "NUT" binPath= "C:\NUT\bin\nut.exe" start= auto DisplayName= "Network UPS Tools"
  ```
- **Shutdown command (cross-platform fix — Windows absolute path):**
  ```
  SHUTDOWNCMD "C:\\Windows\\System32\\shutdown.exe /s /t 0"
  ```

### Shutdown Thresholds

| Trigger | Threshold | Action |
|:---|:---|:---|
| Battery % (WinNUT GUI) | 70% | Graceful `shutdown.exe /s /t 0` |
| **Immediate stop action** flag | Must be **Enabled** | Without this, % thresholds are treated as warnings only |
| Master FSD signal | Proxmox Low Battery (10%) | Override — forces shutdown even if local threshold hasn't triggered |

### Windows OS Overrides

| Setting | Location | Value |
|:---|:---|:---|
| AutoEndTasks | `HKCU\Control Panel\Desktop` | `1` — Forces all apps to close without dialogs |
| Fast Startup | Control Panel → Power Options | **Disabled** — Required for true S5 state and WoL to work |

---

## Power Restoration & Wake-on-LAN

Because Bahamut executes a **graceful OS shutdown**, it enters an S5 (soft-off) state. The BIOS "Restore on AC Power Loss" setting does **not** apply to S5 — only to nodes that physically lost power while running.

Bahamut is brought back online via **Wake-on-LAN (WoL)** from Proxmox:

```bash
# Proxmox cron (runs 45 seconds after Proxmox boots)
@reboot sleep 45 && /usr/sbin/etherwake <BAHAMUT_MAC_ADDRESS>
```

### WoL Prerequisites

- [ ] Windows Fast Startup is disabled
- [ ] Ethernet adapter in Device Manager: `Allow this device to wake the computer` → **Checked**
- [ ] Bahamut BIOS: `Wake on LAN / Resume by PCIe` → **Enabled** *(wiped on every CMOS clear)*

---

## Role as Tier 3 Storage

Bahamut hosts an SMB share (`P:` drive) that Proxmox mounts as the **Tier 3 off-site** backup target:

| Property | Detail |
|:---|:---|
| **Share Name** | `Bahamut_P_Drive` |
| **Protocol** | SMB/CIFS |
| **Proxmox Mount** | Mounted via Proxmox Storage → CIFS |
| **Reachable Via** | Tailscale mesh (requires Tailscale on Proxmox host to be up) |
| **DR Caveat** | If Core-Router LXC is down, Tailscale routing may not reach this share. Fall back to Tier 2 (`Vault_Backups`) first. |

---

## Known Hardware Caveats

### PSU Active PFC Safety Breaker

- **Symptom:** After a dirty UPS killpower cut, Bahamut's power button is completely unresponsive. No POST, no fans.
- **Root Cause:** Active PFC PSU trips its internal safety breaker on sudden voltage loss.
- **Fix:**
  1. Unplug power cable from wall/UPS.
  2. Hold chassis power button for **60 seconds** to drain capacitive flea power.
  3. Reconnect and power on normally.

### Intel KF Processor POST Failure After CMOS Clear

- **Symptom:** After shorting JBAT1, system hangs at POST with white CPU debug light. No display output.
- **Root Cause:** i7-10700KF has no integrated graphics. Memory retraining fails on a complex hardware profile.
- **Fix:**
  1. Remove GPU and all RAM sticks.
  2. Install **one stick of RAM in slot A2 only**.
  3. Power on — allow bare-minimum memory retraining to complete.
  4. Enter BIOS and verify baseline settings.
  5. Reinstall GPU and remaining RAM.

### WoL Setting Wiped on CMOS Clear

- **Symptom:** Bahamut does not respond to WoL magic packet after CMOS clear.
- **Root Cause:** BIOS WoL setting resets to default (disabled) on every CMOS clear.
- **Fix:** Physically access BIOS after any CMOS clear and re-enable `Wake on LAN / Resume by PCIe`.
