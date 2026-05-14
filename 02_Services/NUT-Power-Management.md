# ⚡ NUT — Network UPS Tools: Power Management

**Last Updated:** 2026-05-13
**Architecture:** Master / Slave
**Master Node:** Proxmox Host (`192.168.0.232`)
**Slave Node:** Bahamut (`192.168.0.222`)
**UPS Hardware:** Amazon Basics 1500VA / 900W (OEM: CyberPower CP1500PFCLCD)

---

## Overview

The Sovereign Lab uses **Network UPS Tools (NUT)** to broadcast UPS telemetry across the local network, enabling multiple machines to share a single UPS and execute their own graceful shutdowns in a coordinated cascade.

The UPS is physically connected to the Proxmox host via USB. Proxmox acts as the NUT Master, reading the hardware state and broadcasting it on the network. Bahamut acts as the NUT Slave, polling Proxmox and reacting to power events.

---

## 1. Hardware

| Component | Detail |
|:---|:---|
| **UPS Model** | Amazon Basics 1500VA / 900W Line-Interactive |
| **OEM Equivalent** | CyberPower CP1500PFCLCD (Pure Sine Wave) |
| **Connection to Master** | USB to Proxmox host |
| **NUT Driver** | `usbhid-ups` (CyberPower HID subdriver) |
| **Network Port** | TCP `3493` |

---

## 2. NUT Master (Proxmox)

### 2.1 Driver Configuration

`/etc/nut/ups.conf`:
```ini
[amazon-ups]
  driver = usbhid-ups
  port = auto
  desc = "Amazon Basics 1500VA UPS"
```

### 2.2 upsd Network Configuration

`/etc/nut/upsd.conf`:
```ini
LISTEN 0.0.0.0 3493
```

Proxmox Datacenter firewall must allow inbound TCP on port `3493`.

### 2.3 User Access Profiles

`/etc/nut/upsd.users`:
```ini
[proxmox-admin]
  password = <PASSWORD>
  actions = SET
  instcmds = ALL
  upsmon master

[bahamut-client]
  password = <PASSWORD>
  upsmon slave
```

### 2.4 upsmon Shutdown Threshold

`/etc/nut/upsmon.conf`:
```ini
MONITOR amazon-ups@localhost 1 proxmox-admin <PASSWORD> master
SHUTDOWNCMD "/sbin/shutdown -h +0"
MINSUPPLIES 1
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
POWERDOWNFLAG /etc/killpower
FINALDELAY 5
```

**Shutdown Trigger:** Proxmox relies on the hardware **"Low Battery" (LB)** flag — triggered by UPS firmware at **10% charge or ≤300 seconds** of runtime remaining.

### 2.5 Restarting / Verifying the NUT Stack

```bash
# Reload udev rules (needed after USB re-bind)
udevadm control --reload-rules && udevadm trigger

# Restart driver
upsdrvctl stop && upsdrvctl start

# Verify driver bound
upsdrvctl status

# Verify upsd is listening
ss -tlnp | grep 3493

# Check live telemetry
upsc amazon-ups@localhost

# Check upsmon daemon
systemctl status nut-monitor
```

---

## 3. Alerting Pipeline

### 3.1 Event-Driven Alerts

`/etc/nut/upsmon.conf` `NOTIFYCMD` is configured with a `+EXEC` flag on critical events. When `OB` (On Battery) or `LB` (Low Battery) is detected, `upsmon` calls:

```bash
/usr/local/bin/nut-alert.sh
```

This script sends an immediate email alert via the local Postfix relay.

### 3.2 Scheduled Weekly Health Report

A cron job runs every Monday at 8:00 AM:
```
0 8 * * 1 /usr/local/bin/ups-report.sh
```

`ups-report.sh` parses `upsc` output and emails a formatted health check containing:
- `battery.charge` — Current %
- `ups.load` — Current wattage draw
- `battery.runtime` — Estimated runtime in seconds
- `input.voltage` — Wall voltage

Both scripts route through the Postfix Gmail SMTP relay. See [Postfix Gmail SMTP Relay SOP](../08_SOP/Standard%20Operating%20Procedure%20-%20Postfix%20Gmail%20SMTP%20Relay.md).

---

## 4. NUT Slave (Bahamut)

See [Bahamut-Node.md](../01_Infrastructure/Bahamut-Node.md) for full hardware specs and NUT slave configuration details.

### 4.1 Summary: Slave Shutdown Logic

| Trigger | Threshold | Action |
|:---|:---|:---|
| Local battery % (WinNUT) | 70% | `shutdown.exe /s /t 0` |
| Master FSD broadcast | LB flag from Proxmox | Force shutdown (override) |
| Immediate stop action | Enabled | Required for local % thresholds to act |

### 4.2 Cross-Platform SHUTDOWNCMD Fix

Default NUT config ships with a Linux path:
```
SHUTDOWNCMD "/sbin/shutdown -h +0"   ← will fail on Windows
```

Corrected for Windows:
```
SHUTDOWNCMD "C:\\Windows\\System32\\shutdown.exe /s /t 0"
```

---

## 5. Power Restoration Cascade

| Step | Event | System |
|:---|:---|:---|
| 1 | UPS restores power to outlets | UPS Hardware |
| 2 | Proxmox boots automatically (BIOS AC Recovery → `Power On`) | Proxmox |
| 3 | All VMs/LXCs with Start at Boot enabled come online | Proxmox |
| 4 | After 45s, Proxmox cron fires WoL magic packet | Proxmox → Bahamut |
| 5 | Bahamut powers on, NUT Slave reconnects to Master | Bahamut |

---

## 6. UPS Status Reference

Key `upsc` status flags:

| Flag | Meaning |
|:---|:---|
| `OL` | On Line — wall power present |
| `OB` | On Battery — running on UPS battery |
| `LB` | Low Battery — below firmware threshold |
| `FSD` | Forced Shutdown — master has issued kill signal to all slaves |
| `RB` | Replace Battery — battery health degraded |
| `CHRG` | Charging |
| `DISCHRG` | Discharging |
