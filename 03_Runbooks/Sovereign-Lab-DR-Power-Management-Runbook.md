# Sovereign Lab: Automated DR & Power Management Runbook

**Last Updated:** 2026-05-13
**Target:** Full Lab Environment (Proxmox Host + Bahamut Node)
**Trigger:** Planned or unplanned power loss event requiring graceful multi-node shutdown and full lab resurrection.
**Estimated Recovery Time:** 30–60 minutes (assumes NUT stack is healthy and BIOS settings are current)

---

## Prerequisites

Before a power event occurs, confirm the following are in place:

- [ ] Both Proxmox host and Bahamut are plugged into the **battery-backed outlets** of the 1500VA Pure Sine Wave UPS
- [ ] NUT Master (`upsd`) is running on Proxmox and bound to the USB UPS device via `usbhid-ups` driver
- [ ] NUT Slave (WinNUT-Client) is running on Bahamut and polling Proxmox on port `3493`
- [ ] Postfix mail relay is active and routing alerts to admin Gmail
- [ ] Tailscale is active on the bare-metal Proxmox OS for OOB management
- [ ] Daily host backup cron job (`/usr/local/bin/pve-host-backup.sh`) is active and writing to `Vault_Backups`
- [ ] Proxmox BIOS: **Restore on AC Power Loss** → `Power On`, **Wait for F1 If Error** → `Disabled`
- [ ] Bahamut BIOS: **Wake-on-LAN** is enabled on the primary Ethernet adapter
- [ ] Windows Fast Startup is **disabled** on Bahamut

---

## 1. Proactive Architecture: Preparing the Hardware

Verify these are in place before any planned test or prior to storm season.

### 1.1 Power Layer (UPS)

```bash
# Verify live UPS telemetry from Proxmox host
upsc amazon-ups@localhost
```

Confirm the output shows:
- `ups.status: OL` — On Line (wall power active)
- `battery.charge: 100` — Fully charged
- `battery.runtime` — At least 2700+ seconds at idle load

### 1.2 NUT Master (Proxmox)

```bash
# Verify driver is bound
upsdrvctl status

# Verify upsd is listening
ss -tlnp | grep 3493

# Verify upsmon event daemon is running
systemctl status nut-monitor
```

### 1.3 NUT Slave (Bahamut)

- Open WinNUT-Client tray icon on Bahamut
- Confirm status shows **On Line** and battery percentage is visible
- Confirm **Immediate stop action** checkbox is enabled
- Confirm shutdown threshold is set to **70%** battery

### 1.4 Automated Backups

```bash
# Confirm the backup cron job is registered
crontab -l | grep pve-host-backup

# Manually trigger to verify it completes without error
/usr/local/bin/pve-host-backup.sh
```

---

## 2. Power Event Response: What Happens Automatically

When the UPS detects loss of wall power, the following cascade executes without manual intervention:

| Time | Event | System |
|:---|:---|:---|
| T+0s | UPS switches to battery. Audible alarm begins. | UPS Hardware |
| T+5s | Proxmox `upsmon` detects `OB` (On Battery) flag. Alert email fires. | Proxmox |
| T+5s | Bahamut WinNUT detects `OB` flag. Countdown begins. | Bahamut |
| T+~70% battery | Bahamut executes `shutdown.exe /s /t 0`. Load shed complete. | Bahamut |
| T+10% battery or <300s runtime | Proxmox receives `LB` (Low Battery) flag. Graceful VM/LXC shutdown begins. | Proxmox |
| T+LB+~60s | Proxmox hypervisor halts. UPS executes killpower. | Proxmox / UPS |

---

## 3. Power Restoration: Full Lab Resurrection

When wall power is restored, execute these steps if the lab does not recover autonomously.

### 3.1 Expected Autonomous Recovery

1. UPS restores power to outlets.
2. Proxmox host powers on automatically (BIOS AC Recovery setting).
3. All VMs and LXCs with **Start at Boot** enabled come online automatically.
4. After 45 seconds, Proxmox cron fires a WoL magic packet to Bahamut:
   ```
   @reboot sleep 45 && /usr/sbin/etherwake <BAHAMUT_MAC>
   ```
5. Bahamut powers on and resumes normal operation.

### 3.2 If Proxmox Does Not Auto-Power-On

**Symptom:** Host stays dark after UPS restores power.

**Check:**
- BIOS `Restore on AC Power Loss` setting — may have been reset if CMOS battery is dead.
- Replace the **CR2032 CMOS battery** if this has happened more than once.
- Re-enter BIOS manually and set:
  - `Restore on AC Power Loss` → `Always On`
  - `Wait for F1 If Error (Halt On)` → `Disabled`

### 3.3 If Proxmox Halts at "UEFI Defaults Loaded / Press F1"

This is CMOS battery failure. The board forgot its settings after standby power was cut.

1. Press F1 to continue into BIOS.
2. Re-apply all settings from Section 3.2.
3. Save and reboot.
4. **Schedule CR2032 battery replacement immediately.**

### 3.4 If Bahamut Does Not Wake via WoL

**Symptom:** WoL magic packet fires but Bahamut stays in S5 (off).

**Checklist:**
- [ ] Windows Fast Startup is disabled (prevents true S5 entry on graceful shutdown)
- [ ] Bahamut BIOS: `Wake on LAN / Resume by PCIe` → `Enabled` *(this is wiped on CMOS clear)*
- [ ] Ethernet adapter in Device Manager: `Allow this device to wake the computer` → Checked
- [ ] Proxmox cron is registered: `crontab -l | grep etherwake`

**Manual Wake (from Proxmox or Sovereign-Ops):**
```bash
/usr/sbin/etherwake <BAHAMUT_MAC_ADDRESS>
# or
wakeonlan <BAHAMUT_MAC_ADDRESS>
```

### 3.5 If Bahamut PSU Will Not Power On After Hard Cutoff

**Symptom:** Power button is completely unresponsive. No POST, no fans, nothing.

**Root Cause:** Active PFC PSU tripped internal safety breaker due to dirty UPS killpower voltage drop.

**Fix:**
1. Fully unplug the power cable from the wall/UPS.
2. Hold the chassis power button for **60 seconds** to drain capacitive flea power.
3. Reconnect power cable.
4. Attempt normal power-on.

---

## 4. Proxmox Bare-Metal DR (OS Drive Failure)

If the Proxmox OS drive has failed completely, follow the full [Proxmox-Full-DR-Playbook](Proxmox-Full-DR-Playbook.md).

Key principles:
- The `Sovereign_VMs` data SSD (`sdb`) is separate from the OS drive — VMs survive OS failure.
- `Vault_Backups` (Tier 2, local HDD) requires **no network** to access — it is the first recovery resource.
- Do not trust Windows Diskpart health status — always verify with `dmesg` from Ubuntu Live USB.

---

## 5. The Chaos Test: Full Systems Validation

Run after any significant architectural change, BIOS update, or CMOS clear event.

### 5.1 Pre-Test Checklist

- [ ] All volatile work on Bahamut is saved or closed
- [ ] All Sovereign Lab VMs/LXCs are running and healthy
- [ ] Postfix mail relay is verified working (`echo "test" | mail -s "NUT test" <admin_email>`)
- [ ] UPS is at 100% charge
- [ ] You have confirmed Bahamut's WoL settings are active in BIOS

### 5.2 Test Execution

1. **The Event:** Physically unplug the 1500VA UPS from the wall outlet. Do not touch either computer.
2. **Verify Detection:** UPS audible alarm sounds. WinNUT on Bahamut shows transition to battery power.
3. **Verify Load Shedding:** At 70% battery, Bahamut executes graceful OS shutdown automatically.
4. **Verify Hypervisor Protection:** At 10% / <300s, Proxmox gracefully halts all containers and powers off.
5. **The Resurrection:** Plug UPS back in. Do not manually power on either machine.
6. **Verify Auto-Boot:** Both nodes power on without intervention within ~2 minutes.
7. **Verify Network Fabric:** All Start-at-Boot VMs come online. Routing and DNS resolve correctly.
8. **Boundary Test (Stateful Firewall):**
   - Ping Bahamut from the Ghost container → **Success** (expected)
   - Ping Ghost from Bahamut → **Drop/Failure** (expected — confirms stateful FRRouting rules survived cold boot)

### 5.3 Post-Test Documentation

- Record test date and outcome in `04_Change_Logs/`
- If any step failed, update this runbook with root cause and fix before closing the ticket

---

## 6. Known Hardware Caveats Reference

| Node | Caveat | Mitigation |
|:---|:---|:---|
| **Proxmox (AsRock Z77 Extreme4)** | CMOS battery dead — forgets BIOS settings after full power cut | Replace CR2032. Re-apply AC recovery and halt settings after every CMOS clear. |
| **Bahamut (i7-10700KF)** | CMOS clear causes POST failure — no iGPU for memory retraining | Strip GPU. Single-stick RAM in slot A2. Force re-train. Reinstall components. |
| **Bahamut (Active PFC PSU)** | Trips internal breaker on dirty UPS killpower cut | 60-second flea power drain before attempting power-on. |
| **Bahamut (WoL)** | BIOS WoL setting wiped on every CMOS clear | Must physically re-enable in BIOS after any CMOS clear event. |
