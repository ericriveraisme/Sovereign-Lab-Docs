# 🧟 Runbook: Proxmox Full Disaster Recovery Playbook

**Last Updated:** 2026-04-07
**Target:** Proxmox Host (Bare Metal)
**Trigger:** Hypervisor OS drive failure, ungraceful power loss, or any event requiring a full Proxmox reinstall.
**Estimated Recovery Time:** 2–4 hours (assumes Tier 2 backups are current)

---

## Prerequisites

Before starting, confirm you have:

- [ ] A bootable **Proxmox VE ISO** on USB (keep one in a known physical location at all times)
- [ ] A bootable **Ubuntu Live USB** (for Layer 1 diagnostics if needed)
- [ ] Physical access to the Proxmox host
- [ ] A replacement drive for the OS (any 2.5" SATA SSD or HDD, minimum ~120GB)
- [ ] The **Vault_Backups** physical HDD is installed in the host (Tier 2 local backups)
- [ ] The **Sovereign_VMs** data SSD (`sdb`) is physically intact and installed

---

## Phase 0: Layer 1 Triage — Confirm the Failure

**Goal:** Determine whether this is a software (GRUB/filesystem) issue or a physical hardware failure before wiping anything.

### Step 0.1: Identify the Symptom

If the host drops to a GRUB rescue prompt on boot:

```
error: unknown filesystem.
grub rescue>
```

**Do not** attempt GRUB recovery commands yet. This may be a dead drive, not a corrupted bootloader.

### Step 0.2: Boot from Ubuntu Live USB

1. Insert the Ubuntu Live USB.
2. Boot from USB (adjust BIOS boot order if power loss reset it — check this first).
3. Select **"Try Ubuntu"** (do not install).

### Step 0.3: Check Kernel Logs for I/O Errors

```bash
dmesg | grep -i "error\|i/o\|buffer"
```

**What you're looking for:**

```
Buffer I/O error on dev dm-0, logical block 0, async page read
```

- If you see `Buffer I/O error` on the OS drive → the drive is **physically dead**. Proceed to Phase 1.
- If `dmesg` is clean → this may be a recoverable GRUB/filesystem issue. Attempt `fsck` or GRUB reinstall before doing a full DR.

### Step 0.4: Do NOT Trust Windows Diskpart

If you cross-check the drive in Windows, Diskpart may report it as `Healthy` because the FAT32 EFI boot partition can still be read. **This is misleading.** The LVM root partition may be destroyed while the EFI partition survives. `dmesg` is the only source of truth for block-level integrity.

### Step 0.5: Verify the VM Data Drive

Before proceeding, confirm the `Sovereign_VMs` data drive (`sdb`) is intact:

```bash
lsblk
blkid /dev/sdb1
```

If the data drive shows valid partitions and UUIDs, your VM payload is safe. Proceed with confidence.

---

## Phase 1: Hardware Swap — Replace the Dead OS Drive

**Goal:** Install a replacement drive and get a fresh Proxmox instance running.

### Step 1.1: Physical Drive Swap

1. Power off the host completely.
2. Remove the failed OS drive.
3. Install the replacement drive in the same SATA bay (or any available bay — Proxmox will detect it).
4. Verify BIOS recognizes the new drive before booting the installer.

### Step 1.2: Install Proxmox VE

1. Boot from the **Proxmox VE ISO** USB.
2. Install to the **new replacement drive only**. Do **NOT** select the `Sovereign_VMs` data drive or `Vault_Backups` drive.
3. Set the management IP to: `192.168.0.232/24` (or your known host IP).
4. Set the gateway to your home network gateway (e.g., `192.168.0.1`).
5. Set DNS to `1.1.1.1` temporarily (internal DNS is not yet available).
6. Complete the installation and reboot into the fresh Proxmox host.

### Step 1.3: Verify Web UI Access

From an external workstation on the same physical LAN:

```
https://192.168.0.232:8006
```

Login with the `root` credentials set during installation.

---

## Phase 2: Day 1 Hardening — Prepare the Fresh Host

**Goal:** Get the host into a usable state before restoring any VMs.

### Step 2.1: Disable Enterprise Repository

```bash
# Comment out or remove the enterprise source
sed -i 's/^deb/#deb/' /etc/apt/sources.list.d/pve-enterprise.list
```

### Step 2.2: Add No-Subscription Community Repository

```bash
echo "deb http://download.proxmox.com/debian/pve $(grep -oP 'VERSION_CODENAME=\K\w+' /etc/os-release) pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list
```

### Step 2.3: Update the Host

```bash
apt update && apt dist-upgrade -y
```

### Step 2.4: Silence the Subscription Nag Screen

```bash
sed -i.bak "s/data.status !== 'Active'/false/g" \
  /usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js && \
  systemctl restart pveproxy.service
```

> **Note:** This must be re-applied after Proxmox package upgrades that overwrite `proxmoxlib.js`.

---

## Phase 3: Mount Backup Storage — Break the Chicken-and-Egg Paradox

**Goal:** Access VM backup files without depending on the network (which is down because the Core-Router is not yet restored).

### Step 3.1: Identify the Vault_Backups Drive

```bash
lsblk
blkid
```

Look for the `Vault_Backups` partition (typically `/dev/sdc1`, ext4). Confirm by UUID.

### Step 3.2: Mount Locally

```bash
mkdir -p /mnt/Vault_Backups
mount /dev/sdc1 /mnt/Vault_Backups
```

### Step 3.3: Verify Backup Files Are Present

```bash
ls -lh /mnt/Vault_Backups/dump/
```

You should see `.tar.gz`, `.tar.zst`, or `.vma.zst` backup files for your containers and VMs. Confirm the Core-Router backup exists before continuing.

### Step 3.4: Register as Proxmox Storage

In the Proxmox Web UI:

1. Navigate to **Datacenter → Storage → Add → Directory**.
2. **ID:** `Vault_Backups`
3. **Directory:** `/mnt/Vault_Backups`
4. **Content:** Select `VZDump backup file`, `Container template`, `ISO image`.
5. Click **Add**.

Alternatively, via CLI:

```bash
pvesm add dir Vault_Backups --path /mnt/Vault_Backups --content backup,iso,vztmpl
```

> **Critical Reminder:** Tier 3 NAS backups (Bahamut) are inaccessible at this point because the internal network depends on the Core-Router. Do NOT waste time attempting SMB mounts. Use the physical Tier 2 drive.

---

## Phase 4: Rebuild Host Network Fabric — The Step Everyone Forgets

**Goal:** Recreate the host-level virtual bridges that guest containers depend on. Proxmox restores *guest configs*, not *host networking*.

### Step 4.1: Recreate vmbr1 (Internal VLAN Bridge)

In the Proxmox Web UI: **Host → Network → Create → Linux Bridge**

| Setting       | Value              |
|---------------|--------------------|
| **Name**      | `vmbr1`            |
| **IPv4/CIDR** | *(leave blank)*    |
| **Bridge ports** | *(leave blank)* |
| **Comment**   | Internal VLAN bridge — Core-Router LAN side |

Or via `/etc/network/interfaces`:

```
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
# Internal VLAN bridge for lab traffic (10.0.10.0/24, 10.0.20.0/24)
```

### Step 4.2: Restore the Static Route for Host → Lab Communication

Add the `post-up` route to `vmbr0` in `/etc/network/interfaces`:

```
auto vmbr0
iface vmbr0 inet static
    address 192.168.0.232/24
    gateway 192.168.0.1
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    post-up ip route add 10.0.10.0/24 via 192.168.0.235
```

### Step 4.3: Apply the Network Configuration

```bash
ifreload -a
```

Or reboot the host if `ifreload` is not available:

```bash
systemctl restart networking
```

### Step 4.4: Verification

```bash
ip link show vmbr1
# Should show state UP or UNKNOWN (normal for an empty bridge)

ip route | grep 10.0.10
# Should show: 10.0.10.0/24 via 192.168.0.235 dev vmbr0
```

---

## Phase 5: Restore the Core-Router First

**Goal:** Bring the network gateway online before restoring anything else. The Core-Router is the keystone — everything depends on it.

### Step 5.1: Restore Core-Router LXC (Container 100)

Via the Proxmox Web UI:

1. Navigate to **Vault_Backups** storage → **Backups** tab.
2. Locate the most recent Core-Router backup (CT 100).
3. Click **Restore** → set **CT ID** to `100` → set **Storage** to `Sovereign_VMs` (or local-lvm).
4. Start the restore.

Or via CLI:

```bash
# List available backups
ls /mnt/Vault_Backups/dump/ | grep "100"

# Restore (adjust filename to match your latest backup)
pct restore 100 /mnt/Vault_Backups/dump/vzdump-lxc-100-YYYY_MM_DD-HH_MM_SS.tar.zst \
  --storage local-lvm
```

### Step 5.2: Verify Container Network Config

```bash
pct config 100
```

Confirm:
- `net0` is attached to `vmbr0` (WAN side — `192.168.0.235`)
- `net1` is attached to `vmbr1` (LAN side — `10.0.10.1`)

If the bridge names don't match what you created in Phase 4, edit:

```bash
pct set 100 -net0 name=eth0,bridge=vmbr0,ip=192.168.0.235/24,gw=192.168.0.1
pct set 100 -net1 name=eth1,bridge=vmbr1,ip=10.0.10.1/24
```

### Step 5.3: Start the Core-Router

```bash
pct start 100
```

### Step 5.4: Verify FRRouting and Connectivity

```bash
pct enter 100

# Inside the container:
vtysh -c "show ip route"
# Confirm routes for 10.0.10.0/24 and 10.0.20.0/24 are present

ping -c 3 8.8.8.8
# Confirm outbound NAT is working

exit
```

### Step 5.5: Verify from the Host

```bash
# From the Proxmox host shell:
ping -c 3 10.0.10.1
# Should succeed — host can reach router LAN interface via the static route

ping -c 3 10.0.10.53
# Will fail until Technitium is restored — that's expected
```

---

## Phase 6: Restore the Remaining Fleet

**Goal:** Bring up all other containers and VMs now that the network is functional.

### Restore Order (recommended)

| Priority | Node               | Type | ID  | Why This Order                                   |
|----------|--------------------|------|-----|--------------------------------------------------|
| 1        | Core-Router        | LXC  | 100 | ✅ Already done (Phase 5)                        |
| 2        | Sovereign-Ops      | VM   | 101 | Management node, SSH jump box, backup scripts    |
| 3        | Technitium DNS     | LXC  | —   | Internal DNS resolution for `.sovereign.lab`     |
| 4        | Netdata            | LXC  | —   | Telemetry and monitoring                         |
| 5        | User containers    | LXC  | —   | Non-critical workloads last                      |

### Restore Commands (repeat per node)

```bash
# For LXC containers:
pct restore <ID> /mnt/Vault_Backups/dump/vzdump-lxc-<ID>-<TIMESTAMP>.tar.zst \
  --storage local-lvm

# For QEMU VMs:
qmrestore /mnt/Vault_Backups/dump/vzdump-qemu-<ID>-<TIMESTAMP>.vma.zst <ID> \
  --storage local-lvm
```

---

## Phase 7: Post-Restore Fixes — Known Papercuts

**Goal:** Address the two recurring issues that appear after every bare-metal restore.

### Fix 7.1: The Ghost in the CD Tray

**Symptom:** A restored VM refuses to start with:

```
content-type 'iso' is not available on storage 'local'
```

**Cause:** The VM still has a virtual CD-ROM pointing to an installation ISO from the old host.

**Fix:**

1. Proxmox Web UI → select the VM → **Hardware** tab.
2. Find the **CD/DVD Drive** entry.
3. Click **Edit** → select **Do not use any media** → **OK**.

Or via CLI:

```bash
qm set <VM_ID> --ide2 none,media=cdrom
```

### Fix 7.2: Proxmox DNS Override on LXC Containers

**Symptom:** The Technitium DNS container resolves external queries for the network, but internally queries `1.1.1.1` instead of itself (`127.0.0.1`).

**Cause:** Proxmox overwrites `/etc/resolv.conf` inside LXC containers on every boot with the host's DNS settings.

**Fix (run inside the affected container):**

```bash
# Enter the container
pct enter <CONTAINER_ID>

# Create the Proxmox ignore flag
touch /etc/.pve-ignore.resolv.conf

# Set the correct resolver
echo "nameserver 127.0.0.1" > /etc/resolv.conf

# Verify
nslookup google.com 127.0.0.1
# Should resolve through the local Technitium instance

exit
```

> **Important:** This flag must exist inside any LXC container that runs its own DNS resolver. If Proxmox is upgraded or the container is re-created, verify the flag still exists.

---

## Phase 8: Persistence & Chaos Test — Validate the Recovery

**Goal:** Ensure every service and mount survives a hard reboot with zero manual intervention.

### Step 8.1: Persist the Vault_Backups Mount

Get the drive UUID:

```bash
blkid /dev/sdc1
```

Add to `/etc/fstab`:

```
UUID=<DRIVE_UUID> /mnt/Vault_Backups ext4 defaults 0 2
```

Test without rebooting:

```bash
umount /mnt/Vault_Backups
mount -a
ls /mnt/Vault_Backups/dump/
# Files should appear — if not, fix the fstab entry BEFORE rebooting
```

### Step 8.2: Enable Auto-Start on All VMs/Containers

For each container and VM:

```bash
# LXC containers:
pct set <ID> --onboot 1

# QEMU VMs:
qm set <ID> --onboot 1
```

Or set via the Proxmox Web UI: **VM/CT → Options → Start at boot → Yes**.

Set boot order and startup delays if needed:

```bash
# Core-Router starts first (order 1), waits 30s before next
pct set 100 --startup order=1,up=30

# Technitium DNS starts second
pct set <DNS_ID> --startup order=2,up=15

# Everything else
pct set <ID> --startup order=3
```

### Step 8.3: The Hard Reboot Test

**This is non-negotiable.** A DR operation is incomplete until validated by a full power cycle.

1. Confirm nobody else depends on the lab right now.
2. From the Proxmox host shell:

```bash
reboot
```

3. Wait for the host to come back up (2–4 minutes).
4. Log into the Web UI and verify **all** containers/VMs are running.

### Step 8.4: Connectivity Verification Checklist

Run these checks from the **Proxmox host shell**:

```bash
# 1. Host → Core-Router (LAN gateway)
ping -c 3 10.0.10.1

# 2. Host → Technitium DNS
ping -c 3 10.0.10.53

# 3. DNS resolution (internal zone)
nslookup dns.sovereign.lab 10.0.10.53

# 4. DNS resolution (external, via Technitium upstream)
nslookup google.com 10.0.10.53

# 5. Core-Router outbound NAT
pct enter 100
ping -c 3 8.8.8.8
exit

# 6. User VLAN outbound (from a VLAN 20 container)
pct enter <USER_CT_ID>
ping -c 3 8.8.8.8
exit
```

### Step 8.5: Validate the NAT Boundary (Expected Asymmetric Behavior)

From an external workstation on `192.168.0.x`, attempt:

```bash
ping 10.0.20.x
```

**Expected result: NO REPLY.** This is correct. The Core-Router's stateful NAT drops unsolicited inbound traffic to private VLANs. If this ping *succeeds*, your firewall posture is broken — investigate immediately.

---

## Phase 9: Day 2 Hardening — Prevent Recurrence

**Goal:** Ensure the next failure requires a fraction of the effort.

### Step 9.1: Restore Postfix Email Relay

Reconfigure Postfix on the management VM (`sovereign-ops`) to relay through Gmail SMTP. Refer to:

> **SOP:** `08_SOP/Standard Operating Procedure - Postfix Gmail SMTP Relay.md`

### Step 9.2: Restore NAS Backup Mount (Tier 3)

Once the Core-Router and Tailscale mesh are functional, re-establish the SMB mount to Bahamut:

```bash
# Test mount
mount -t cifs //bahamut/backups /mnt/bahamut -o credentials=/etc/smbcredentials,vers=3.0

# Add to /etc/fstab for persistence
//bahamut/backups /mnt/bahamut cifs credentials=/etc/smbcredentials,vers=3.0,_netdev 0 0
```

> The `_netdev` option tells systemd to wait for the network before attempting the mount.

### Step 9.3: Deploy Host Configuration Backup Script

Place on the **Proxmox host**:

```bash
cat > /usr/local/bin/pve-host-backup.sh << 'EOF'
#!/bin/bash
# Automated Proxmox host configuration backup

DESTINATION="/mnt/Vault_Backups/pve-host-config-$(date +%F).tar.gz"
EMAIL="ericriveraisme@gmail.com"
HOSTNAME=$(hostname)

if tar -czvf "$DESTINATION" \
  /etc/pve \
  /etc/network/interfaces \
  /etc/fstab \
  /etc/postfix \
  /etc/vzdump.conf > /dev/null 2>&1; then
    echo "[$HOSTNAME] Host config backup SUCCESS: $DESTINATION" | \
      mail -s "Sovereign Lab: Backup SUCCESS on $HOSTNAME" "$EMAIL"
else
    echo "[$HOSTNAME] Host config backup FAILED" | \
      mail -s "Sovereign Lab: Backup FAILED on $HOSTNAME" "$EMAIL"
fi
EOF

chmod 700 /usr/local/bin/pve-host-backup.sh
```

### Step 9.4: Schedule via Cron

```bash
crontab -e
```

Add:

```
0 3 * * * /usr/local/bin/pve-host-backup.sh
```

### Step 9.5: Verify the Router Backup Pipeline

Confirm the automated Git-based router backup on `sovereign-ops` is functional:

```bash
ssh ops
# On sovereign-ops:
crontab -l | grep backup
ls -lh ~/scripts/backup_router.sh
```

Refer to: **SOP:** `08_SOP/Standard Operating Procedure - Automated Git-Based Router Backups.md`

---

## Phase 10: Final Verification Checklist

Run through this checklist before declaring the DR operation complete:

| # | Check | Command / Method | Expected Result |
|---|-------|-----------------|-----------------|
| 1 | All VMs/CTs running | Proxmox Web UI dashboard | All nodes show green "running" |
| 2 | Core-Router routing | `pct enter 100` → `vtysh -c "show ip route"` | Routes for 10.0.10.0/24 and 10.0.20.0/24 present |
| 3 | Outbound NAT | `ping 8.8.8.8` from any internal container | Success |
| 4 | Internal DNS | `nslookup dns.sovereign.lab 10.0.10.53` | Resolves to `10.0.10.53` |
| 5 | External DNS | `nslookup google.com 10.0.10.53` | Resolves via Cloudflare upstream |
| 6 | Vault_Backups persistent | `mount | grep Vault` | Mounted, listed in fstab |
| 7 | VMs start on boot | Reboot host → all services auto-start | All nodes running after cold boot |
| 8 | NAT boundary intact | Ping internal IP from external workstation | **No reply** (expected) |
| 9 | Host backup cron | `crontab -l | grep pve-host-backup` | Entry present, runs at 03:00 |
| 10 | Email alerting | Trigger a manual backup run → check inbox | Email received |
| 11 | Technitium self-resolves | `pct enter <DNS_ID>` → `nslookup google.com 127.0.0.1` | Resolves locally, not via 1.1.1.1 |
| 12 | Ghost IP eviction | `pct enter 100` → `ip addr show eth0` | Only `192.168.0.235` present |

---

## Quick Reference: Critical Files & Paths

| Item | Path |
|------|------|
| Proxmox network config | `/etc/network/interfaces` |
| Proxmox cluster config | `/etc/pve/` |
| VM/CT config files | `/etc/pve/lxc/<ID>.conf`, `/etc/pve/qemu-server/<ID>.conf` |
| FRRouting config | `/etc/frr/frr.conf` (inside CT 100) |
| Host backup script | `/usr/local/bin/pve-host-backup.sh` |
| Router backup script | `sovereign-ops:~/scripts/backup_router.sh` |
| Vault_Backups mount | `/mnt/Vault_Backups` |
| Proxmox DNS ignore flag | `/etc/.pve-ignore.resolv.conf` (inside LXC) |
| Subscription nag target | `/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js` |

---

## Related Documentation

- **Architecture:** `01_Infrastructure/Architecture_Overview_1.1.md`
- **Core-Router:** `01_Infrastructure/Core-Router-LXC100.md`
- **Network Architecture:** `01_Infrastructure/Network-Architecture.md`
- **Ghost IP Eviction:** `03_Runbooks/Evict-Ghost-IP.md`
- **VLAN Troubleshooting:** `03_Runbooks/VLAN-Connectivity-Troubleshooting.md`
- **Postfix Hang Fix:** `03_Runbooks/Postfix-Hang-Resolution.md`
- **Router Backup SOP:** `08_SOP/Standard Operating Procedure - Automated Git-Based Router Backups.md`
- **Postfix Relay SOP:** `08_SOP/Standard Operating Procedure - Postfix Gmail SMTP Relay.md`
- **DR Article:** `05_Articles/Sovereign_Lab_DR_Chronicle_Draft.md`
