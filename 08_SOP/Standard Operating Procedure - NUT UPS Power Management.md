# Standard Operating Procedure — NUT UPS Power Management

**Version:** 1.0
**Last Updated:** 2026-05-13
**Author:** Eric Rivera
**Applies To:** Proxmox Host (NUT Master) + Bahamut (NUT Slave)
**Related Runbook:** [Sovereign-Lab-DR-Power-Management-Runbook.md](../03_Runbooks/Sovereign-Lab-DR-Power-Management-Runbook.md)
**Related Service Doc:** [NUT-Power-Management.md](../02_Services/NUT-Power-Management.md)

---

## Purpose

This SOP defines the standard procedures for deploying, verifying, and recovering the Network UPS Tools (NUT) power management stack across the Sovereign Lab. It serves as the authoritative reference for both initial setup and ongoing maintenance.

---

## 1. Initial Deployment: NUT Master (Proxmox)

### 1.1 Install NUT

```bash
apt update && apt install nut nut-client -y
```

### 1.2 Configure NUT Mode

`/etc/nut/nut.conf`:
```ini
MODE=netserver
```

### 1.3 Bind the UPS Driver

`/etc/nut/ups.conf`:
```ini
[amazon-ups]
  driver = usbhid-ups
  port = auto
  desc = "Amazon Basics 1500VA UPS"
```

If the driver throws `Driver not connected` after initial config (common when USB permissions haven't been reloaded):

```bash
udevadm control --reload-rules
udevadm trigger
upsdrvctl stop && upsdrvctl start
```

> **Note:** This avoids requiring a physical USB replug when configuring remotely.

### 1.4 Configure upsd (Network Listener)

`/etc/nut/upsd.conf`:
```ini
LISTEN 0.0.0.0 3493
```

Open TCP port `3493` in Proxmox Datacenter firewall (inbound).

### 1.5 Configure User Access Profiles

`/etc/nut/upsd.users`:
```ini
[proxmox-admin]
  password = <STRONG_PASSWORD>
  actions = SET
  instcmds = ALL
  upsmon master

[bahamut-client]
  password = <STRONG_PASSWORD>
  upsmon slave
```

> Retrieve `bahamut-client` credentials from this file when configuring the Windows slave.

### 1.6 Configure upsmon (Master Monitor)

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
NOTIFYCMD /usr/local/bin/nut-alert.sh
NOTIFYFLAG ONBATT +EXEC+SYSLOG
NOTIFYFLAG LOWBATT +EXEC+SYSLOG
NOTIFYFLAG FSD +EXEC+SYSLOG
```

### 1.7 Enable and Start Services

```bash
systemctl enable nut-server nut-monitor
systemctl start nut-server nut-monitor
```

### 1.8 Verify

```bash
upsc amazon-ups@localhost
```

Expected output should include `ups.status: OL` (On Line).

---

## 2. Initial Deployment: NUT Slave (Bahamut — Windows)

### 2.1 Install NUT for Windows

Download the `gawindx` fork of WinNUT-Client or the official NUT Windows binary package. Extract to `C:\NUT\`.

### 2.2 Configure upsmon.conf

`C:\NUT\etc\upsmon.conf`:
```
MONITOR ups@192.168.0.232 1 bahamut-client <PASSWORD> slave
SHUTDOWNCMD "C:\\Windows\\System32\\shutdown.exe /s /t 0"
MINSUPPLIES 1
POLLFREQ 5
POLLFREQALERT 5
```

> **Critical:** Use the Windows absolute path for `SHUTDOWNCMD`. The default Linux path (`/sbin/shutdown`) will silently fail on Windows.

### 2.3 Verify Handshake (Foreground Test)

```cmd
C:\NUT\bin\nut.exe -N
```

Confirm the slave connects and shows live UPS status.

### 2.4 Register as a Windows Service

If `nut.exe` lacks the `-i` installation flag:

```cmd
sc.exe create "NUT" binPath= "C:\NUT\bin\nut.exe" start= auto DisplayName= "Network UPS Tools"
```

Start the service:
```cmd
sc.exe start NUT
```

### 2.5 Apply Windows OS Overrides

**Force AutoEndTasks** (allows WinNUT to close apps without dialogs):
```
Registry: HKEY_CURRENT_USER\Control Panel\Desktop
Value: AutoEndTasks = 1 (String)
```

**Disable Windows Fast Startup** (required for true S5 state + WoL compatibility):
- Control Panel → Hardware and Sound → Power Options → Choose what the power buttons do → Uncheck "Turn on fast startup"

### 2.6 Configure WinNUT GUI (if using GUI client)

- **"Immediate stop action"** → **Checked** (required for % thresholds to trigger shutdown, not just warn)
- **"Shutdown if battery below"** → `70%`
- **"Shutdown if runtime lower than"** → If using runtime mode, remember this is *remaining* runtime — not elapsed time on battery.

---

## 3. Alerting Pipeline Setup

### 3.1 nut-alert.sh (Event-Driven)

Create `/usr/local/bin/nut-alert.sh`:
```bash
#!/bin/bash
echo "SOVEREIGN LAB ALERT: UPS event detected. Status: $(upsc amazon-ups@localhost ups.status)" \
  | mail -s "UPS ALERT: Power Event Detected" admin@example.com
```

```bash
chmod +x /usr/local/bin/nut-alert.sh
```

### 3.2 ups-report.sh (Scheduled Weekly Health Check)

Create `/usr/local/bin/ups-report.sh`:
```bash
#!/bin/bash
STATUS=$(upsc amazon-ups@localhost)
echo "$STATUS" | mail -s "Sovereign Lab: Weekly UPS Health Report" admin@example.com
```

```bash
chmod +x /usr/local/bin/ups-report.sh
```

Add to crontab:
```bash
crontab -e
# Add:
0 8 * * 1 /usr/local/bin/ups-report.sh
```

Both scripts require Postfix to be configured and relay-ready. See [Standard Operating Procedure - Postfix Gmail SMTP Relay.md](Standard%20Operating%20Procedure%20-%20Postfix%20Gmail%20SMTP%20Relay.md).

---

## 4. Wake-on-LAN Configuration (Bahamut Auto-Recovery)

### 4.1 Bahamut BIOS

Enable: `Wake on LAN / Resume by PCIe` → **Enabled**

> This setting is wiped on every CMOS clear. Must be re-enabled after any CMOS clear event.

### 4.2 Bahamut Windows — Ethernet Adapter

Device Manager → Network Adapters → Primary Ethernet → Properties → Power Management:
- ✅ Allow this device to wake the computer
- ✅ Only allow a magic packet to wake the computer

### 4.3 Proxmox — WoL Cron Job

```bash
crontab -e
# Add:
@reboot sleep 45 && /usr/sbin/etherwake <BAHAMUT_MAC_ADDRESS>
```

Verify `etherwake` is installed:
```bash
apt install etherwake -y
```

---

## 5. Verification Checklist

Run after any deployment or post-maintenance restart:

```bash
# Master health
upsc amazon-ups@localhost                    # Should show OL status
systemctl status nut-server nut-monitor      # Both should be active/running
ss -tlnp | grep 3493                         # upsd must be listening

# Alert pipeline
echo "test" | mail -s "NUT test" admin@example.com   # Postfix relay test

# WoL cron
crontab -l | grep etherwake                  # Confirm cron is registered
```

On Bahamut (Windows):
```cmd
C:\NUT\bin\upsc.exe amazon-ups@192.168.0.232    # Should show OL status
sc.exe query NUT                                 # Service should be RUNNING
```

---

## 6. Maintenance Notes

| Event | Action Required |
|:---|:---|
| CMOS clear on Proxmox | Re-apply: `Restore on AC Power Loss` → Always On, `Halt On` → Disabled |
| CMOS clear on Bahamut | Re-enable WoL in BIOS. Verify `AutoEndTasks` and Fast Startup settings survived. |
| CR2032 CMOS battery replacement | Re-enter all BIOS settings after first POST. Verify AC recovery and WoL before next Chaos Test. |
| Bahamut PSU safety breaker tripped | 60-second flea power drain (unplug + hold power button). Then reconnect. |
| NUT driver fails to bind after host reboot | Run `udevadm control --reload-rules && udevadm trigger` before restarting `upsdrvctl`. |
