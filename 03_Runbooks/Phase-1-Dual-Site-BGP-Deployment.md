# 📋 Phase 1 Deployment Runbook: Dual-Site BGP & Observability Lab
**Created:** 2026-08-22  
**Version:** 1.0  
**Status:** Ready for Execution  
**Objective:** Deploy an isolated virtual dual-site network topology with automated fault detection and enriched alerting.

---

## 📊 Progress Tracking

Use this table to mark completion as you progress. Update the status column with one of:
- `⏳ Not Started`
- `🔄 In Progress`
- `✅ Complete`
- `❌ Blocked`

| Phase | Milestone | Status | Completed Date | Notes |
|:---|:---|:---|:---|:---|
| **0** | Inventory & Design Freeze | ⏳ Not Started | — | |
| **1** | Network Bridges & Isolation | ⏳ Not Started | — | |
| **2** | Router Provisioning | ⏳ Not Started | — | |
| **3** | BGP & BFD Transit | ⏳ Not Started | — | |
| **4** | Site LAN & Endpoints | ⏳ Not Started | — | |
| **5** | Telemetry & Monitoring | ⏳ Not Started | — | |
| **6** | Alert Routing | ⏳ Not Started | — | |
| **7** | Triage Worker | ⏳ Not Started | — | |
| **8** | Controlled Demo | ⏳ Not Started | — | |

---

## 🎯 Project Overview

This runbook deploys an **isolated virtual dual-site network** on the existing Proxmox hypervisor. The topology includes:

- **Site A (Headend):** `10.10.10.0/24` network with edge router, client traffic generators
- **Site B (Access):** `10.20.20.0/24` network with OLT-style router, simulated subscriber ONTs
- **Transit:** `172.16.1.0/30` point-to-point eBGP link with BFD
- **Observability:** Prometheus scraping FRR exporters, Alertmanager routing, Grafana visualization
- **Automation:** Python FastAPI triage worker performing SSH-based root cause verification

The demonstration proves that when a simulated outage occurs:
1. BFD detects the failure in under 1 second
2. BGP session drops
3. Prometheus evaluates the condition
4. Alertmanager fires a webhook
5. The triage worker verifies the cause directly against the router CLI
6. An enriched incident notification is delivered with evidence and classification

**Design Separation:**  
This expansion **does not modify** the existing management network (`10.0.10.0/24` VLAN 10) or the host network (`10.0.20.0/24` VLAN 20). The new simulated sites use distinct address ranges (`10.10.10.x`, `10.20.20.x`) on isolated bridges.

---

## 🔑 Canonical Address Plan (VERIFIED AGAINST LIVE STATE - 2026-08-22)

**Proxmox Node:** `pve` (4 CPUs, 31.1 GiB RAM)

### Current Infrastructure (DO NOT TOUCH)

| VMID | Hostname | Type | Status | eth0 Bridge | IP Configuration | VLAN | Purpose |
|:---|:---|:---|:---|:---|:---|:---|:---|
| **100** | `core-router` | LXC | ✅ Running | vmbr0 | `192.168.0.235/24` gw `192.168.0.1` | — | Lab gateway to physical network |
| **100** | `core-router` | LXC | ✅ Running | vmbr1 | `10.0.0.1/24` | — | Internal backbone |
| **101** | `sovereign-ops` | VM | ✅ Running | vmbr1 | VLAN 10 tag (no direct IP) | 10 | Management cockpit |
| **102** | `ghost-user-01` | LXC | ✅ Running | vmbr1 | `10.0.20.10/24` gw `10.0.20.1` | 20 | Sandbox host |
| **103** | `netdata-monitor` | LXC | ⏸️ Stopped | vmbr1 | `10.0.10.20/24` gw `10.0.10.1` | 10 | Telemetry (offline) |
| **104** | `dns.sovereign.lab` | LXC | ✅ Running | vmbr1 | `10.0.10.53/24` gw `10.0.10.1` | 10 | Authoritative DNS |

### Existing Subnets In Use

| Subnet | Gateway | VLAN | Purpose | Bridge | Status |
|:---|:---|:---|:---|:---|:---|
| `192.168.0.0/24` | `192.168.0.1` | — | Physical home network | vmbr0 | ✅ Active |
| `10.0.0.0/24` | `10.0.0.1` | — | Core-Router internal backbone | vmbr1 | ✅ Active |
| `10.0.10.0/24` | `10.0.10.1` | 10 | Management VLAN | vmbr1 | ✅ Active |
| `10.0.20.0/24` | `10.0.20.1` | 20 | Host VLAN | vmbr1 | ✅ Active |

### Existing Bridges

| Bridge | Physical Ports | Internal IPs | Purpose | Status |
|:---|:---|:---|:---|:---|
| **vmbr0** | — | `192.168.0.232/24` | Management bridge (home network) | ✅ In use |
| **vmbr1** | — | — | Internal lab backbone (VLAN-aware, carries VLAN 10, 20, and core-router spine) | ✅ In use, **SHARED** |
| **vmbr2** | — | — | Not created yet | ❌ Available |
| **vmbr3** | — | — | Not created yet | ❌ Available |

---

## 🔄 Phase 1 Deployment Address Plan (NEW ISOLATED BRIDGES)

| Function | Subnet | Proxmox Bridge | Purpose | Status |
|:---|:---|:---|:---|:---|
| **Simulated Site A LAN** | `10.10.10.0/24` | **vmbr2** (create) | Edge Router A, Client A1, etc. | ✅ New |
| **Simulated Site B LAN** | `10.20.20.0/24` | **vmbr3** (create) | Edge Router B, ONT B1, etc. | ✅ New |
| **Simulated Transit WAN** | `172.16.1.0/30` | **vmbr4** (create) | eBGP link between routers | ✅ New |
| **Router Loopbacks** | `10.255.255.0/24` | — | Router IDs for BGP and management | ✅ New |

### Phase 1 Router Loopback Details

| Component | Loopback IP | AS | Role | VMID | Bridge | LAN IP |
|:---|:---|:---|:---|:---|:---|:---|
| edge-rtr-a | `10.255.255.1/32` | `65001` | Site A headend router | 200 | vmbr2 | `10.10.10.1/24` |
| edge-rtr-b | `10.255.255.2/32` | `65002` | Site B access router | 201 | vmbr3 | `10.20.20.1/24` |

---

## ⚠️ CRITICAL: Why We Use New Bridges (vmbr2, vmbr3, vmbr4)

**Current vmbr1 is SHARED and carries production traffic:**

The existing infrastructure uses vmbr1 as an internal backbone carrying:
- VLAN 10 (Management): DNS, Prometheus, Grafana, Netdata, etc.
- VLAN 20 (Hosts): User workloads and sandbox environments
- Core-Router spine traffic: `10.0.0.0/24`

**Risk of reusing vmbr1 for Phase 1:**

If we attach Phase 1 routers and simulated sites to the SAME vmbr1 bridge, then:
1. A routing misconfiguration could poison management VLAN routes
2. A broadcast storm in Phase 1 could saturate the management VLAN
3. A BGP redistribution accident could advertise internal `10.0.x.x` prefixes externally
4. Testing interface shutdown on "eth1" could cascade to vmbr1 and break existing services

**Safety by isolation:**

Using separate bridges (vmbr2, vmbr3, vmbr4) creates an air-gap:
- Phase 1 faults remain isolated to the simulation
- Management traffic never touches simulated routers
- Proxmox to physical network connectivity (`vmbr0 ↔ 192.168.0.232`) remains stable
- Testing BGP shutdown, BFD injection, and chaos faults is safe

---

## 0️⃣ PHASE 0: Inventory & Design Freeze

**Objective:** Confirm that Proxmox has available resources and that the planned design does not conflict with existing infrastructure.

### 0.1 Use MCP to Inspect Live Proxmox State

The Proxmox MCP server on `sovereign-ops` is configured and verified. Use it to gather live state without manual click-through.

**Expected State:**
- Proxmox API is reachable
- Cluster resources endpoint returns VM and LXC data
- Node storage and memory are available

**How to Check (from VS Code tunnel):**

```bash
# From the sovereign-ops terminal within the VS Code tunnel
curl -sk -H "Authorization: PVEAPIToken=${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}" \
  "${PROXMOX_HOST}/api2/json/cluster/resources" | jq '.data[] | select(.type=="node") | {node: .node, maxcpu: .maxcpu, maxmem: .maxmem, status: .status}'
```

**Expected Output:**
```json
{
  "node": "sovereign",
  "maxcpu": 12,
  "maxmem": 68719476736,
  "status": "online"
}
```

### 0.2 Confirm No Address Conflicts

Verify that the simulated site networks do not overlap with existing infrastructure.

| Check | Command | Expected |
|:---|:---|:---|
| Site A addresses are unused | `ping 10.10.10.1` → should timeout | No response |
| Site B addresses are unused | `ping 10.20.20.1` → should timeout | No response |
| Transit addresses are unused | `ping 172.16.1.1` → should timeout | No response |
| Existing management VLAN still works | `ping 10.0.10.1` → should reach Core-Router | Response from 10.0.10.1 |

### 0.3 Confirm Target Bridges Do Not Exist

Verify that Phase 1 can use `vmbr2`, `vmbr3`, and `vmbr4` without conflicts. The existing `vmbr0` and `vmbr1` are in production and must NOT be modified.

**Check from Proxmox host SSH:**
```bash
ip link show | grep -E 'vmbr[0-4]'
```

**Expected output:**
```
2: vmbr0: <...>  # Management bridge (existing, in use)
3: vmbr1: <...>  # Internal backbone (existing, in use)
No vmbr2, vmbr3, or vmbr4
```

**Do NOT modify vmbr0 or vmbr1.** They carry production traffic to `core-router`, DNS, monitoring, and management VMs.

### 0.4 Reserve VM/LXC IDs

Proxmox assigns numeric IDs to each VM and LXC. Reserve IDs for the Phase 1 components to avoid collisions.

| Component | Type | Reserved ID | Notes |
|:---|:---|:---|:---|
| edge-rtr-a | LXC | 200 | Site A router |
| edge-rtr-b | LXC | 201 | Site B router |
| client-a1 | LXC | 210 | Site A test client |
| ont-b1 | LXC | 220 | Site B test subscriber |
| triage-worker | LXC | 230 | Fault verification service |

Check for conflicts:
```bash
qm list   # Shows VMs
pct list  # Shows LXCs
```

### 0.5 Confirm Template Availability

Verify that Debian and Alpine templates are available for LXC creation.

```bash
pveam available | grep debian
pveam available | grep alpine
```

**Expected:** At least one Debian 12 template and one Alpine 3.x template.

### 0.6 Confirm Storage Headroom

Estimate storage for the new containers:

- Each LXC: ~500 MB base + runtime overhead
- Five containers = ~2.5 GB minimum
- FRR routers need ~100 MB each
- Client containers need ~50 MB each

```bash
pvesh get /storage/local --output-format json | jq '.[] | {storage: .storage, available: .avail, used: .used}'
```

**Expected:** At least 5 GB free.

### 0.7 Update Progress Tracking

Mark Phase 0 as complete in the progress table above once all checks pass.

---

## 1️⃣ PHASE 1: Network Bridges & Isolation

**Objective:** Create THREE NEW isolated software bridges (vmbr2, vmbr3, vmbr4) that will carry the simulated Site A, Site B, and transit traffic. These bridges must remain COMPLETELY ISOLATED from the existing management network (vmbr0, vmbr1) and the physical network.

### 1.1 Create vmbr2 (Site A LAN)

This bridge carries the `10.10.10.0/24` Site A traffic. It has NO physical ports and NO connection to vmbr0 or vmbr1.

**Via CLI (on Proxmox host `pve`):**
```bash
cat >> /etc/network/interfaces <<EOF

auto vmbr2
iface vmbr2 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
```

**Verification:**
```bash
ip link show vmbr2
ip route show | grep vmbr2  # Should show NO routes
```

**Expected:**
```
4: vmbr2: <BROADCAST,MULTICAST,UP,LOWER_UP>
    link/ether xx:xx:xx:xx:xx:xx brd ff:ff:ff:ff:ff:ff
```

### 1.2 Create vmbr3 (Site B LAN)

This bridge carries the `10.20.20.0/24` Site B access traffic. Completely isolated.

**Via CLI:**
```bash
cat >> /etc/network/interfaces <<EOF

auto vmbr3
iface vmbr3 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
```

**Verification:**
```bash
ip link show vmbr3
```

### 1.3 Create vmbr4 (Transit/eBGP Link)

This bridge carries the `172.16.1.0/30` point-to-point eBGP transit traffic. Completely isolated.

**Via CLI:**
```bash
cat >> /etc/network/interfaces <<EOF

auto vmbr4
iface vmbr4 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
```

**Verification:**
```bash
ip link show vmbr4
```

### 1.4 Confirm Complete Isolation

Verify that the new bridges (vmbr2, vmbr3, vmbr4) are **not attached to physical network interfaces** and cannot route to the home network. They should be isolated software bridges only.

**Test isolation:**
```bash
# Verify no physical ports attached
ip link show vmbr2 | grep "LOWER_UP"
ip link show vmbr3 | grep "LOWER_UP"
ip link show vmbr4 | grep "LOWER_UP"

# Verify they have NO routes to external networks
ip route show | grep -E 'vmbr[234]'
# Expected: no output

# Verify they cannot reach home network
ping 192.168.0.1  # Should timeout or fail
ping 10.0.10.1    # Should timeout (no routes)

# Verify management network still works
ping 10.0.10.53   # Should reach DNS
```

**Expected behavior:**
- All three new bridges are UP but have NO routes
- They have NO physical ports
- They cannot reach `192.168.0.0/24` (home network)
- They cannot reach `10.0.10.0/24` or `10.0.20.0/24` (existing VLANs)
- Existing management connectivity (`10.0.10.53`, `10.0.20.10`) still works

### 1.5 Document Bridge Configuration

Record the final bridge configuration in the repository for future reference:

```bash
cat /etc/network/interfaces | grep -A 5 "vmbr1\|vmbr2\|vmbr3" > /tmp/bridges.conf
# Store this in a change-log file or runbook for reference
```

### 1.6 Update Progress

Mark Phase 1 complete when all three bridges are created and isolation is confirmed.

---

## 2️⃣ PHASE 2: Router Provisioning

**Objective:** Deploy two Debian LXCs (`edge-rtr-a` and `edge-rtr-b`) configured with FRRouting and ready to establish the BGP peering.

### 2.1 Provision edge-rtr-a (Site A Router)

**Via Proxmox GUI:**

1. Create LXC
   - Node: `pve`
   - VMID: `200`
   - Hostname: `edge-rtr-a`
   - Resource: Debian 12 template
   - Storage: `local` (LVM-Thin)
   - Disk: 5 GB
   - CPU: 2 cores
   - Memory: 512 MB
   - Swap: 256 MB

2. Add Network Interfaces
   - **eth0:** Attached to `vmbr2` (Site A LAN - isolated)
   - **eth1:** Attached to `vmbr4` (Transit/eBGP - isolated)
   - Comment each interface clearly

3. Start the container

**Via CLI:**

```bash
pct create 200 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -hostname edge-rtr-a \
  -cores 2 \
  -memory 512 \
  -swap 256 \
  -net0 name=eth0,bridge=vmbr2,ip=dhcp \
  -net1 name=eth1,bridge=vmbr4,ip=dhcp

pct start 200
pct exec 200 bash  # Enter container shell
```

### 2.2 Configure edge-rtr-a Interfaces

Once inside the container, assign static IP addresses and enable IP forwarding.

**Inside the container (pct exec 200 bash):**

```bash
# Verify interfaces exist
ip link show

# Create /etc/network/interfaces configuration
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback
    address 127.0.0.1/8

auto eth0
iface eth0 inet static
    address 10.10.10.1/24

auto eth1
iface eth1 inet static
    address 172.16.1.1/30

# Loopback for BGP
auto lo:1
iface lo:1 inet static
    address 10.255.255.1/32
EOF

# Restart networking
systemctl restart networking

# Verify
ip addr show
```

**Enable IP Forwarding:**

```bash
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -p
```

**Verify Connectivity:**

```bash
ping 172.16.1.2  # Should timeout (not yet configured on remote)
ping -I eth0 10.10.10.254  # Should reach broadcast address
ip route show    # Should show connected routes
```

### 2.3 Install and Enable FRRouting on edge-rtr-a

**Inside the container:**

```bash
# Update package cache
apt update

# Install FRRouting
apt install -y frr frr-pythontools

# Enable BGP and BFD daemons
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sed -i 's/^bfdd=no/bfdd=yes/' /etc/frr/daemons
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons

# Verify daemons file
cat /etc/frr/daemons | grep -E "^(bgpd|bfdd|ospfd)"

# Restart FRR
systemctl enable frr
systemctl restart frr

# Verify FRR is running
systemctl status frr
vtysh -c "show version"
```

**Expected:**
```
FRRouting 8.x.x or later
bgpd running
bfdd running
ospfd running
```

### 2.4 Provision edge-rtr-b (Site B Router)

Repeat steps 2.1 through 2.3 for Site B, using:

- VMID: `201`
- Hostname: `edge-rtr-b`
- **eth0 attached to `vmbr3`** → `10.20.20.1/24`
- **eth1 attached to `vmbr4`** → `172.16.1.2/30`
- Loopback: `10.255.255.2/32`

**Via CLI:**

```bash
pct create 201 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -hostname edge-rtr-b \
  -cores 2 \
  -memory 512 \
  -swap 256 \
  -net0 name=eth0,bridge=vmbr3,ip=dhcp \
  -net1 name=eth1,bridge=vmbr4,ip=dhcp

pct start 201
pct exec 201 bash
```

### 2.5 Verify Router Isolation and Connectivity

**From edge-rtr-a:**
```bash
ping 10.10.10.254   # Local broadcast (should respond)
ping 172.16.1.2     # Transit peer (should fail — not yet routable)
traceroute 10.20.20.254  # Should show 172.16.1.2 as next hop once BGP is up
```

**From edge-rtr-b:**
```bash
ping 10.20.20.254   # Local broadcast (should respond)
ping 172.16.1.1     # Transit peer (should fail — not yet routable)
```

### 2.6 Backup Initial Configuration

Inside each router, save the baseline interface and FRR config:

```bash
# edge-rtr-a
cp /etc/network/interfaces /root/interfaces.backup-phase2
cp /etc/frr/frr.conf /root/frr.conf.backup-phase2
```

Repeat for edge-rtr-b.

### 2.7 Update Progress

Mark Phase 2 complete when both routers boot, interfaces are assigned, IP forwarding is enabled, and FRR services are running.

---

## 3️⃣ PHASE 3: BGP & BFD Transit

**Objective:** Establish the point-to-point eBGP session between `edge-rtr-a` and `edge-rtr-b` with BFD for sub-second failure detection.

### 3.1 Configure BGP on edge-rtr-a

Enter FRR configuration shell and apply the BGP peer configuration.

**Inside edge-rtr-a container:**

```bash
vtysh
```

**Inside vtysh (FRR shell):**

```vtysh
configure terminal

! BGP configuration for Site A router
router bgp 65001
 bgp router-id 10.255.255.1
 neighbor 172.16.1.2 remote-as 65002
 neighbor 172.16.1.2 timers 3 9
 
 address-family ipv4 unicast
  neighbor 172.16.1.2 activate
  network 10.10.10.0/24
 exit-address-family

end
write memory
exit
```

**Explanation:**
- `router bgp 65001`: Site A uses private ASN 65001
- `bgp router-id 10.255.255.1`: Uses the loopback address as BGP router ID
- `neighbor 172.16.1.2 remote-as 65002`: Defines the peer as Site B (AS 65002)
- `neighbor 172.16.1.2 timers 3 9`: Keepalive 3s, hold-time 9s (aggressive for lab)
- `network 10.10.10.0/24`: Explicitly advertise Site A's local network

**Verify:**
```bash
vtysh -c "show bgp summary"
# Expected: neighbor 172.16.1.2 shows state (Idle, Connect, or Established)
```

### 3.2 Configure BGP on edge-rtr-b

Repeat the BGP configuration on Site B using AS 65002 and Site B's loopback.

**Inside edge-rtr-b container, via vtysh:**

```vtysh
configure terminal

router bgp 65002
 bgp router-id 10.255.255.2
 neighbor 172.16.1.1 remote-as 65001
 neighbor 172.16.1.1 timers 3 9
 
 address-family ipv4 unicast
  neighbor 172.16.1.1 activate
  network 10.20.20.0/24
 exit-address-family

end
write memory
exit
```

### 3.3 Verify BGP Peering

From either router, check whether the BGP session reaches `Established`.

```bash
vtysh -c "show bgp summary"
```

**Expected Output:**
```
Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ  Up/Down State/PfxRcvd
172.16.1.2     4 65002      15      15        0    0    0 00:00:05            1
```

The state should be `1` (or a number indicating active) within a few seconds. If it stays at `Idle` or `Active`:

- Check interface connectivity: `ping 172.16.1.2` from edge-rtr-a
- Check firewall or ACLs (unlikely in lab, but possible in FRR policy)
- Verify the neighbor IP is correct
- Check FRR logs: `journalctl -u frr -n 50`

### 3.4 Configure BFD on edge-rtr-a

BFD accelerates failure detection below the BGP hold-time. When BFD detects a link failure, it immediately notifies BGP.

**Inside edge-rtr-a container, via vtysh:**

```vtysh
configure terminal

bfd
 peer 172.16.1.2
  detect-multiplier 3
  receive-interval 300
  transmit-interval 300
  echo-interval 0
 exit
end
write memory
exit
```

**Explanation:**
- `detect-multiplier 3`: Failure confirmed after 3 missed packets
- `receive-interval 300`: Expect a BFD packet every 300 ms
- `transmit-interval 300`: Send BFD packets every 300 ms
- `echo-interval 0`: Disable echo mode (simpler for lab)

**Result:** If all 3 packets are missed (900 ms max), BFD declares the link down.

### 3.5 Configure BFD on edge-rtr-b

Repeat the BFD configuration on Site B.

```vtysh
configure terminal

bfd
 peer 172.16.1.1
  detect-multiplier 3
  receive-interval 300
  transmit-interval 300
  echo-interval 0
 exit
end
write memory
exit
```

### 3.6 Link BFD to BGP (Optional but Recommended)

Add BFD awareness to the BGP neighbor definition so that BGP immediately reacts to BFD failure.

**On edge-rtr-a:**

```vtysh
configure terminal
router bgp 65001
 neighbor 172.16.1.2 bfd
end
write memory
exit
```

**On edge-rtr-b:**

```vtysh
configure terminal
router bgp 65002
 neighbor 172.16.1.1 bfd
end
write memory
exit
```

### 3.7 Verify BFD Status

```bash
vtysh -c "show bfd peers"
```

**Expected:**
```
BfdPeers:
  peer 172.16.1.2, local 172.16.1.1
    status: up
    remote status: up
    uptime: 120 seconds
```

### 3.8 Test BGP Route Redistribution

Verify that each router learns the opposite site's prefix.

**From edge-rtr-a:**
```bash
vtysh -c "show ip bgp neighbors 172.16.1.2 advertised-routes"
# Should show 10.10.10.0/24

vtysh -c "show ip bgp neighbors 172.16.1.2 received-routes"
# Should show 10.20.20.0/24
```

**From edge-rtr-b:**
```bash
vtysh -c "show ip bgp neighbors 172.16.1.1 advertised-routes"
# Should show 10.20.20.0/24

vtysh -c "show ip bgp neighbors 172.16.1.1 received-routes"
# Should show 10.10.10.0/24
```

### 3.9 Verify Routing Table Updates

Each router should now have a route to the opposite site's network.

**From edge-rtr-a:**
```bash
ip route show
# Expected: 10.20.20.0/24 via 172.16.1.2
```

**From edge-rtr-b:**
```bash
ip route show
# Expected: 10.10.10.0/24 via 172.16.1.1
```

### 3.10 Backup BGP Configuration

```bash
# On each router
cp /etc/frr/frr.conf /root/frr.conf.backup-phase3
```

### 3.11 Update Progress

Mark Phase 3 complete when:
- BGP sessions are Established
- BFD peers show status: up
- Each router has learned the opposite site's prefix
- Routing tables show cross-site reachability

---

## 4️⃣ PHASE 4: Site LAN & Test Endpoints

**Objective:** Add one client endpoint to each site to verify end-to-end routing and traffic flow.

### 4.1 Provision client-a1 (Site A Test Host)

Create a minimal Debian LXC on Site A that will generate test traffic.

```bash
pct create 210 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -hostname client-a1 \
  -cores 1 \
  -memory 128 \
  -net0 name=eth0,bridge=vmbr1,ip=dhcp

pct start 210
pct exec 210 bash
```

**Inside client-a1:**

```bash
# Configure static IP
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.10.10.11/24
    gateway 10.10.10.1
EOF

systemctl restart networking

# Verify
ip addr show
ip route show

# Test connectivity
ping 10.10.10.1  # Router should respond
ping 10.10.10.254  # Broadcast should respond
ping 172.16.1.1  # Should fail (not directly reachable)
ping 10.20.20.11  # Will be tested once ont-b1 exists
```

### 4.2 Provision ont-b1 (Site B Test Subscriber)

Create a minimal Alpine LXC on Site B to represent a subscriber access device.

```bash
pct create 220 local:vztmpl/alpine-3.19-default_20240207_amd64.tar.zst \
  -hostname ont-b1 \
  -cores 1 \
  -memory 128 \
  -net0 name=eth0,bridge=vmbr2,ip=dhcp

pct start 220
pct exec 220 sh  # Alpine uses sh, not bash
```

**Inside ont-b1:**

```bash
# Alpine: create network config
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.20.20.11/24
    gateway 10.20.20.1
EOF

# Restart networking (Alpine uses different method)
rc-service networking restart

# Verify
ip addr show
ip route show
ping 10.20.20.1  # Router should respond
```

### 4.3 End-to-End Connectivity Test

**From client-a1 to ont-b1:**

```bash
# Inside client-a1
ping -c 3 10.20.20.11
```

**Expected:**
```
PING 10.20.20.11 (10.20.20.11) 56(84) bytes of data.
64 bytes from 10.20.20.11: icmp_seq=1 ttl=62 time=1.234 ms
64 bytes from 10.20.20.11: icmp_seq=2 ttl=62 time=1.123 ms
64 bytes from 10.20.20.11: icmp_seq=3 ttl=62 time=1.045 ms
```

**TTL should be 62:** starting at 64, decremented by edge-rtr-a (−1) and edge-rtr-b (−1).

**From ont-b1 to client-a1:**

```bash
# Inside ont-b1
ping -c 3 10.10.10.11
```

**Expected:** Same as above, with reverse path.

### 4.4 Verify Route Symmetry

**From edge-rtr-a:**
```bash
traceroute 10.20.20.11
# Expected: route through 172.16.1.2
```

**From edge-rtr-b:**
```bash
traceroute 10.10.10.11
# Expected: route through 172.16.1.1
```

### 4.5 Test Traffic Load (Optional)

Install `iperf3` to measure throughput:

```bash
# On both client-a1 and ont-b1
apt install -y iperf3  # Debian
apk add iperf3         # Alpine

# Server on ont-b1
iperf3 -s &

# Client on client-a1
iperf3 -c 10.20.20.11 -t 10
```

**Expected:** ~1-10 Mbps throughput (sufficient for lab purposes).

### 4.6 Update Progress

Mark Phase 4 complete when:
- client-a1 and ont-b1 boot successfully
- Both have static IPs and can reach their gateway
- End-to-end ping works with correct TTL
- Routes are symmetric and stable

---

## 5️⃣ PHASE 5: Telemetry & Monitoring

**Objective:** Install Prometheus, FRR exporters, and Grafana to visualize BGP, BFD, and interface state in real-time.

### 5.1 Install FRR Exporters on Both Routers

Each router will run an HTTP exporter that publishes FRR metrics.

**On edge-rtr-a (inside container):**

```bash
# Install Go (required to build frr_exporter)
apt install -y golang-go git

# Clone frr_exporter repository
git clone https://github.com/openbsd/frr-exporter.git /opt/frr_exporter
cd /opt/frr_exporter

# Build
go build -o frr_exporter .

# Create systemd service
cat > /etc/systemd/system/frr_exporter.service <<'EOF'
[Unit]
Description=FRR Exporter
After=network.target

[Service]
Type=simple
ExecStart=/opt/frr_exporter/frr_exporter -listen-address=:9342
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable frr_exporter
systemctl start frr_exporter

# Verify
curl http://localhost:9342/metrics | head -20
```

**Repeat on edge-rtr-b.**

### 5.2 Install Node Exporter (System Metrics)

Each router will also expose OS-level metrics.

**On both routers:**

```bash
# Download and install node_exporter
wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
tar xzf node_exporter-1.7.0.linux-amd64.tar.gz
cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/

# Create systemd service
cat > /etc/systemd/system/node_exporter.service <<'EOF'
[Unit]
Description=Node Exporter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter --collector.filesystem.fs-types-exclude=^(autofs|binfmt_misc|bpf|cgroup2?|configfs|debugfs|devpts|devtmpfs|fusectl|hugetlbfs|iso9660|mqueue|nsfs|overlay|proc|procfs|pstore|rpc_pipefs|securityfs|selinuxfs|squashfs|sysfs|tracefs)$
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl enable node_exporter
systemctl start node_exporter

# Verify
curl http://localhost:9100/metrics | head -20
```

### 5.3 Provision Prometheus Container

Create an LXC to run Prometheus, which will scrape the exporters.

```bash
pct create 230 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -hostname prometheus-mon \
  -cores 2 \
  -memory 1024 \
  -net0 name=eth0,bridge=vmbr0,ip=dhcp

pct start 230
pct exec 230 bash
```

**Inside prometheus-mon:**

```bash
# Add Prometheus user and group
useradd --no-create-home --shell /bin/false prometheus

# Download Prometheus
cd /tmp
wget https://github.com/prometheus/prometheus/releases/download/v2.47.0/prometheus-2.47.0.linux-amd64.tar.gz
tar xzf prometheus-2.47.0.linux-amd64.tar.gz
cp prometheus-2.47.0.linux-amd64/prometheus /usr/local/bin/
cp prometheus-2.47.0.linux-amd64/promtool /usr/local/bin/

# Create configuration directory
mkdir -p /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

# Create prometheus.yml
cat > /etc/prometheus/prometheus.yml <<'EOF'
global:
  scrape_interval: 5s
  evaluation_interval: 5s

alerting:
  alertmanagers:
  - static_configs:
    - targets:
      - localhost:9093

rule_files:
  - "/etc/prometheus/alert_rules.yml"

scrape_configs:
  - job_name: 'edge-rtr-a'
    static_configs:
      - targets: ['10.10.10.1:9342', '10.10.10.1:9100']
  
  - job_name: 'edge-rtr-b'
    static_configs:
      - targets: ['10.20.20.1:9342', '10.20.20.1:9100']
EOF

chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Create systemd service
cat > /etc/systemd/system/prometheus.service <<'EOF'
[Unit]
Description=Prometheus
After=network.target

[Service]
Type=simple
User=prometheus
ExecStart=/usr/local/bin/prometheus \
  --config.file=/etc/prometheus/prometheus.yml \
  --storage.tsdb.path=/var/lib/prometheus \
  --web.console.templates=/usr/share/prometheus/consoles \
  --web.console.libraries=/usr/share/prometheus/console_libraries
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable prometheus
systemctl start prometheus

# Verify
curl http://localhost:9090/api/v1/query?query=up
```

### 5.4 Test Metric Scraping

Wait 30 seconds for Prometheus to scrape the first batch of metrics, then verify they are available.

```bash
# Query BGP peer state
curl 'http://localhost:9090/api/v1/query?query=frr_bgp_neighbor_state' | jq .

# Query interface stats
curl 'http://localhost:9090/api/v1/query?query=node_network_receive_bytes' | jq .

# Query BFD state (if exporter exposes it)
curl 'http://localhost:9090/api/v1/query?query=frr_bfd_peer_state' | jq .
```

### 5.5 Install and Configure Grafana (Optional for Phase 5)

Grafana is useful for visualization but not required for fault detection. You can skip to Phase 6 if time is limited.

```bash
# Inside prometheus-mon or new Grafana container
apt install -y grafana-server

systemctl enable grafana-server
systemctl start grafana-server

# Access at http://localhost:3000 (admin/admin)
# Add Prometheus data source pointing to http://localhost:9090
```

### 5.6 Create Alert Rules

Before adding Alertmanager, create the alert rule that will fire when BGP state changes.

```bash
cat > /etc/prometheus/alert_rules.yml <<'EOF'
groups:
  - name: phase1_network_alerts
    rules:
      - alert: BGPPeerStateChange
        expr: changes(frr_bgp_neighbor_state[1m]) > 0
        for: 0s
        labels:
          severity: warning
          action: auto_triage
        annotations:
          summary: "BGP peer state changed on {{ $labels.instance }}"
          description: "BGP neighbor {{ $labels.peer }} state: {{ $value }}"
EOF

chown prometheus:prometheus /etc/prometheus/alert_rules.yml
systemctl restart prometheus
```

### 5.7 Update Progress

Mark Phase 5 complete when:
- FRR exporters run on both routers
- Node exporters run on both routers
- Prometheus scrapes metrics successfully
- Alerts are configured and loaded

---

## 6️⃣ PHASE 6: Alert Routing (Alertmanager)

**Objective:** Deploy Alertmanager to route alerts from Prometheus to the triage worker webhook.

### 6.1 Install Alertmanager

**Inside prometheus-mon (or dedicated container):**

```bash
# Create alertmanager user
useradd --no-create-home --shell /bin/false alertmanager

# Download Alertmanager
cd /tmp
wget https://github.com/prometheus/alertmanager/releases/download/v0.25.0/alertmanager-0.25.0.linux-amd64.tar.gz
tar xzf alertmanager-0.25.0.linux-amd64.tar.gz
cp alertmanager-0.25.0.linux-amd64/alertmanager /usr/local/bin/
cp alertmanager-0.25.0.linux-amd64/amtool /usr/local/bin/

# Create directories
mkdir -p /etc/alertmanager /var/lib/alertmanager
chown alertmanager:alertmanager /etc/alertmanager /var/lib/alertmanager

# Create alertmanager.yml
cat > /etc/alertmanager/alertmanager.yml <<'EOF'
global:
  resolve_timeout: 5m

route:
  receiver: 'triage-webhook'
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

receivers:
  - name: 'triage-webhook'
    webhook_configs:
      - url: 'http://localhost:8000/webhook'
        send_resolved: false
EOF

chown alertmanager:alertmanager /etc/alertmanager/alertmanager.yml

# Create systemd service
cat > /etc/systemd/system/alertmanager.service <<'EOF'
[Unit]
Description=Alertmanager
After=network.target

[Service]
Type=simple
User=alertmanager
ExecStart=/usr/local/bin/alertmanager \
  --config.file=/etc/alertmanager/alertmanager.yml \
  --storage.path=/var/lib/alertmanager \
  --web.external-url=http://localhost:9093/
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable alertmanager
systemctl start alertmanager

# Verify
curl http://localhost:9093/api/v1/alerts
```

### 6.2 Verify Prometheus Sends Alerts to Alertmanager

In Prometheus config, ensure alertmanager endpoint is set (done in Phase 5).

**Test:**
```bash
# Force a test alert by reloading Prometheus
systemctl restart prometheus

# Check Alertmanager
curl http://localhost:9093/api/v1/alerts | jq .
```

### 6.3 Update Progress

Mark Phase 6 complete when:
- Alertmanager listens on port 9093
- Alert configuration is loaded
- Prometheus routes alerts to Alertmanager

---

## 7️⃣ PHASE 7: Triage Worker

**Objective:** Deploy the automated SSH-based fault verification service that receives webhook alerts and enriches them with CLI evidence.

### 7.1 Create Restricted SSH User on Routers

Both routers need a restricted user that the triage worker can SSH into without exposing full root access.

**On edge-rtr-a:**

```bash
# Create restricted user
useradd -m -s /bin/bash triage
usermod -aG frrvty triage  # Allow access to FRR

# Set a password or SSH key (for lab: use password)
echo "triage:TriagePassword123" | chpasswd

# Create sudoers entry (optional, for specific commands only)
echo "triage ALL=(ALL) NOPASSWD:/usr/bin/vtysh" >> /etc/sudoers.d/triage
```

**Repeat on edge-rtr-b.**

### 7.2 Provision triage-worker Container

Create a dedicated LXC for the Python FastAPI service.

```bash
pct create 240 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  -hostname triage-worker \
  -cores 1 \
  -memory 512 \
  -net0 name=eth0,bridge=vmbr0,ip=static,ip=10.0.10.30/24,gw=10.0.10.1

pct start 240
pct exec 240 bash
```

**Inside triage-worker:**

```bash
# Update and install dependencies
apt update
apt install -y python3-pip python3-venv git openssh-client

# Create virtual environment
python3 -m venv /opt/triage-worker
source /opt/triage-worker/bin/activate

# Install Python packages
pip install fastapi uvicorn netmiko pydantic

# Create triage worker application
cat > /opt/triage-worker/app.py <<'PYEOF'
#!/usr/bin/env python3
import asyncio
import json
import logging
import os
import re
import sys
from datetime import datetime
from fastapi import FastAPI, Request, HTTPException
from netmiko import ConnectHandler
from pydantic import BaseModel
import requests

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Configuration
RTR_A_CREDS = {
    "device_type": "linux",
    "host": "10.10.10.1",
    "username": os.getenv("RTR_A_USER", "triage"),
    "password": os.getenv("RTR_A_PASS", "TriagePassword123"),
    "timeout": 10
}

RTR_B_CREDS = {
    "device_type": "linux",
    "host": "10.20.20.1",
    "username": os.getenv("RTR_B_USER", "triage"),
    "password": os.getenv("RTR_B_PASS", "TriagePassword123"),
    "timeout": 10
}

DISCORD_WEBHOOK = os.getenv("DISCORD_WEBHOOK", "https://discord.com/api/webhooks/YOUR_WEBHOOK")

class AlertPayload(BaseModel):
    status: str
    alerts: list = []

def classify_failure(bgp_summary, bfd_peers):
    """Classify the type of failure based on CLI evidence."""
    
    if "Established" not in bgp_summary:
        if "Down" in bfd_peers or "admin" in bfd_peers.lower():
            return "ADMINISTRATIVE_SHUTDOWN", "Interface or session administratively down"
        elif "Idle" in bgp_summary:
            return "NO_CONNECTIVITY", "BGP peer unreachable"
        else:
            return "UNKNOWN_BGP_FAILURE", f"BGP session down. Summary: {bgp_summary[:200]}"
    else:
        return "HEALTHY", "BGP session is established"

@app.post("/webhook")
async def handle_alert(request: Request):
    """Receive alert from Alertmanager and perform triage."""
    
    try:
        payload = await request.json()
        alerts = payload.get("alerts", [])
        
        if not alerts:
            return {"status": "no_alerts"}
        
        for alert in alerts:
            alert_status = alert.get("status", "unknown")
            
            if alert_status != "firing":
                continue
            
            labels = alert.get("labels", {})
            instance = labels.get("instance", "unknown")
            
            logger.info(f"Alert firing: {instance}")
            
            # Determine which router to query
            if "10.10.10" in instance:
                creds = RTR_A_CREDS
            elif "10.20.20" in instance:
                creds = RTR_B_CREDS
            else:
                logger.error(f"Cannot determine router for instance: {instance}")
                continue
            
            # Connect and verify
            try:
                net_connect = ConnectHandler(**creds)
                
                # Get BGP summary
                bgp_output = net_connect.send_command("vtysh -c 'show bgp summary'")
                
                # Get BFD status
                bfd_output = net_connect.send_command("vtysh -c 'show bfd peers'")
                
                net_connect.disconnect()
                
                failure_type, description = classify_failure(bgp_output, bfd_output)
                
                # Send Discord notification
                embed = {
                    "embeds": [{
                        "title": f"🚨 Triage Report: {failure_type}",
                        "color": 15158332 if failure_type != "HEALTHY" else 3066993,
                        "fields": [
                            {"name": "Target", "value": instance, "inline": True},
                            {"name": "Classification", "value": failure_type, "inline": True},
                            {"name": "Description", "value": description},
                            {"name": "BGP Summary", "value": f"```{bgp_output[:500]}```"},
                            {"name": "BFD Status", "value": f"```{bfd_output[:500]}```"},
                            {"name": "Timestamp", "value": datetime.utcnow().isoformat()}
                        ]
                    }]
                }
                
                if DISCORD_WEBHOOK and DISCORD_WEBHOOK != "https://discord.com/api/webhooks/YOUR_WEBHOOK":
                    requests.post(DISCORD_WEBHOOK, json=embed)
                    logger.info(f"Sent Discord notification for {instance}")
                
            except Exception as e:
                logger.error(f"Failed to triage {instance}: {str(e)}")
                
        return {"status": "processed"}
    
    except Exception as e:
        logger.error(f"Error processing webhook: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
PYEOF

chmod +x /opt/triage-worker/app.py

# Create systemd service
cat > /etc/systemd/system/triage-worker.service <<'EOF'
[Unit]
Description=Triage Worker
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/triage-worker
ExecStart=/opt/triage-worker/bin/python /opt/triage-worker/app.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable triage-worker
systemctl start triage-worker

# Verify
sleep 2
curl http://localhost:8000/docs  # FastAPI auto-generated docs
```

### 7.3 Test Webhook Delivery

Send a test alert from Alertmanager to the triage worker.

```bash
# From alertmanager container or another host
curl -X POST http://10.0.10.30:8000/webhook \
  -H "Content-Type: application/json" \
  -d '{
    "status": "firing",
    "alerts": [
      {
        "status": "firing",
        "labels": {"instance": "10.10.10.1:9342"},
        "annotations": {"summary": "Test alert"}
      }
    ]
  }'
```

**Expected Response:**
```json
{"status": "processed"}
```

### 7.4 Update Progress

Mark Phase 7 complete when:
- Triage worker container is running
- FastAPI service is listening on port 8000
- Webhook endpoint accepts POST requests
- SSH credentials allow access to both routers

---

## 8️⃣ PHASE 8: Controlled Demo & Validation

**Objective:** Execute the complete failure-detection workflow and verify that the end-to-end system works as designed.

### 8.1 Establish Baseline

Before injecting faults, capture a healthy baseline state.

**From Prometheus:**
```bash
curl 'http://localhost:9090/api/v1/query?query=frr_bgp_neighbor_state'
# Expected: state = 6 (Established)

curl 'http://localhost:9090/api/v1/query?query=frr_bfd_peer_state'
# Expected: state = up or 1
```

**From Grafana (if deployed):**
- BGP state: green
- BFD state: up
- Interface status: up
- Traffic flowing between sites

**End-to-end test:**
```bash
pct exec 210 ping -c 3 10.20.20.11
# Expected: 3 replies with TTL 62
```

### 8.2 Establish Synthetic Traffic (Optional)

Generate continuous background traffic to make the failure more visible.

```bash
# On client-a1
pct exec 210 bash -c 'while true; do ping 10.20.20.11 -c 1 -w 1; sleep 0.5; done' &

# On ont-b1
pct exec 220 sh -c 'while true; do ping 10.10.10.11 -c 1 -w 1; sleep 0.5; done' &
```

### 8.3 Inject the Fault

Simulate an interface failure by bringing down the transit link on one router.

```bash
# Inside edge-rtr-a
pct exec 200 bash -c 'ip link set dev eth1 down'
```

**What should happen (timeline):**
- **t=0ms:** Interface goes down
- **t=300ms-900ms:** BFD detects the failure (3 missed packets × 300ms interval)
- **t=<1s:** BGP session tears down
- **t=<5s:** Prometheus scrapes and evaluates the condition
- **t=5-15s:** Alertmanager fires the webhook
- **t=15-20s:** Triage worker connects via SSH and collects evidence
- **t=20s:** Discord notification is posted

### 8.4 Verify Detection Timing

Monitor the detection path in real-time.

**Terminal 1 (watch Prometheus):**
```bash
watch -n 1 "curl -s 'http://localhost:9090/api/v1/query?query=frr_bgp_neighbor_state' | jq -r '.data.result[].value[1]'"
```

**Terminal 2 (watch Alertmanager):**
```bash
watch -n 1 "curl -s http://localhost:9093/api/v1/alerts | jq '.[] | select(.status==\"firing\")'"
```

**Terminal 3 (watch triage worker logs):**
```bash
pct exec 240 tail -f /var/log/triage-worker.log  # if logging is configured
```

### 8.5 Verify Evidence Collection

Check that the triage worker successfully retrieved CLI output from the affected router.

**From triage-worker logs or Discord notification:**
- BGP summary should show session state other than "Established"
- BFD peers should show status other than "up"
- SSH connection was successful
- Command output is present in the notification

### 8.6 Restore the Interface

Bring the interface back up and verify convergence.

```bash
# Inside edge-rtr-a
pct exec 200 bash -c 'ip link set dev eth1 up'
```

**Expected timeline:**
- **t=0s:** Interface comes up
- **t=<1s:** BFD re-establishes
- **t=<5s:** BGP re-establishes
- **t=<10s:** Routes are learned again
- **t=10-15s:** Prometheus reports healthy
- **t=15-20s:** (Optional) "resolved" notification

### 8.7 Repeat the Test

Perform the injection and recovery at least 3 times to ensure consistent behavior.

Each iteration should show:
- Consistent detection timing
- Correct classification
- No stale state between tests
- Alert deduplication working

### 8.8 Scale to Multiple Failure Scenarios (Optional)

Test additional scenarios:

**Administrative Shutdown:**
```bash
pct exec 200 bash -c 'vtysh -c "configure terminal" -c "interface eth1" -c "shutdown" -c "end" -c "write memory"'
```

**BFD-only Failure:**
```bash
# Inject packet loss without fully disabling the interface
pct exec 200 bash -c 'tc qdisc add dev eth1 root netem loss 100%'
# Later: tc qdisc del dev eth1 root
```

**BGP Session Restart:**
```bash
pct exec 200 bash -c 'vtysh -c "clear bgp *"'
```

### 8.9 Document Results

Capture a final summary of the demonstration:

- Total detection latency (from fault to notification)
- BGP convergence time
- BFD detection sensitivity
- Triage worker SSH latency
- Notification delivery time
- Alert deduplication behavior
- Recovery time

### 8.10 Update Progress

Mark Phase 8 complete when:
- Baseline state is documented
- Fault injection succeeds
- Detection path is verified
- Evidence collection works
- Notification is delivered
- Recovery is confirmed
- Multiple test cycles succeed

---

## ✅ Completion Checklist

Use this section to verify that all phases are complete:

- [ ] Phase 0: Inventory & Design Freeze
- [ ] Phase 1: Network Bridges Created & Isolated
- [ ] Phase 2: Routers Provisioned & FRR Enabled
- [ ] Phase 3: BGP & BFD Peering Established
- [ ] Phase 4: Site Endpoints Created & Tested
- [ ] Phase 5: Prometheus & Exporters Deployed
- [ ] Phase 6: Alertmanager Configured
- [ ] Phase 7: Triage Worker Deployed & Tested
- [ ] Phase 8: Controlled Demo Completed

---

## 🔄 Rollback & Recovery

If any phase fails or needs to be rewound:

### Remove a Single Container

```bash
pct destroy 200  # Removes edge-rtr-a
pct destroy 201  # Removes edge-rtr-b
pct destroy 210  # Removes client-a1
pct destroy 220  # Removes ont-b1
pct destroy 230  # Removes triage-worker
```

### Remove Bridges

```bash
# Edit /etc/network/interfaces and remove vmbr1, vmbr2, vmbr3
# Then reload:
systemctl restart networking
```

### Preserve Configuration Files

Before removing containers, back up their configurations:

```bash
# On Proxmox host
tar czf /root/phase1-backup-$(date +%s).tar.gz \
  /etc/network/interfaces \
  $(find /var/lib/lxc/20* -name '*.conf' 2>/dev/null | head -5)
```

---

## 📚 Reference & Troubleshooting

### BGP Peering Won't Establish

1. **Check interface connectivity:**
   ```bash
   pct exec 200 ping 172.16.1.2
   ```

2. **Check FRR logging:**
   ```bash
   pct exec 200 journalctl -u frr -n 50
   ```

3. **Verify FRR is running:**
   ```bash
   pct exec 200 vtysh -c "show version"
   ```

4. **Check BGP configuration:**
   ```bash
   pct exec 200 vtysh -c "show running-config | include bgp"
   ```

### Prometheus Won't Scrape Metrics

1. **Check target reachability:**
   ```bash
   curl -v http://10.10.10.1:9342/metrics
   ```

2. **Check Prometheus logs:**
   ```bash
   pct exec 230 journalctl -u prometheus -n 50
   ```

3. **Verify exporters are running:**
   ```bash
   pct exec 200 curl http://localhost:9342/metrics | head -5
   ```

### Triage Worker Can't SSH to Routers

1. **Verify SSH connectivity:**
   ```bash
   pct exec 240 ssh -v triage@10.10.10.1 "vtysh -c 'show version'"
   ```

2. **Check SSH keys or password:**
   ```bash
   pct exec 200 cat /etc/passwd | grep triage
   ```

3. **Verify triage user is in frrvty group:**
   ```bash
   pct exec 200 groups triage
   ```

---

## 📝 Final Notes

- This runbook is designed to be sequential. Do not skip phases.
- Each phase includes validation steps. Do not proceed to the next phase until validation passes.
- Keep detailed notes of any deviations or issues encountered.
- Back up configurations after each successful phase.
- Use the progress tracking table at the top to mark your position.

**Good luck with the deployment!**
