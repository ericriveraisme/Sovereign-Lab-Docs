# 🧭 Phase 1 eBGP Rollout Playbook
**Created:** 2026-08-26  
**Status:** Planned / Manual-First Execution  
**Related Runbook:** [Phase-1-Dual-Site-BGP-Deployment.md](Phase-1-Dual-Site-BGP-Deployment.md)

This playbook is the operational sequence for the Phase 1 eBGP rollout. It is intentionally shorter and more execution-focused than the full runbook, and it makes the build order explicit before any later automation or OSPF design is introduced.

---

## 1. Objective
Build a stable, isolated dual-site BGP lab using two edge routers, an isolated transit backbone, and a minimal customer traffic test path. This is the baseline foundation for later expansion into NetBox/IPAM, Terraform, Ansible, and OSPFv3.

### Phase 1 boundary
- **Do not touch** `vmbr0` or `vmbr1`
- Use isolated bridges only:
  - `vmbr2` = Site A LAN
  - `vmbr3` = Site B LAN
  - `vmbr99` = transit backbone / eBGP link
- Keep all routing behavior inside the lab; do not let Phase 1 traffic reach production infrastructure

---

## 2. Design Summary

### ASNs and sites
- **Site A:** AS `65001`
- **Site B:** AS `65002`

### Address plan
| Role | Subnet / IP |
|:---|:---|
| Site A LAN | `10.10.10.0/24` |
| Site B LAN | `10.20.20.0/24` |
| Transit / backbone | `172.16.1.0/30` |
| Site A router loopback | `10.255.255.1/32` |
| Site B router loopback | `10.255.255.2/32` |
| Site A router LAN IP | `10.10.10.1/24` |
| Site B router LAN IP | `10.20.20.1/24` |
| Site A transit IP | `172.16.1.1/30` |
| Site B transit IP | `172.16.1.2/30` |

### Core naming
- `edge-rtr-a` = VMID `200`, AS `65001`
- `edge-rtr-b` = VMID `201`, AS `65002`
- `client-a1` = VMID `210`, Site A test host
- `ont-b1` = VMID `220`, Site B test subscriber
- `prometheus-mon` = VMID `230` (multi-homed bastion)
- `triage-worker` = VMID `240` (multi-homed bastion)

---

## 3. Execution Order (Manual-First)

### Phase 0: Preflight checks
Goal: confirm the lab is clean and ready for the new topology.

1. Verify Proxmox health and live state.
   ```bash
   python3 /home/eric/Sovereign-Lab-Docs/09_Scripts/refresh_infra_snapshot.py
   cat /home/eric/Sovereign-Lab-Docs/01_Infrastructure/Infrastructure-State-Snapshot.md
   ```
2. Confirm unused address space.
   ```bash
   ping 10.10.10.1
   ping 10.20.20.1
   ping 172.16.1.1
   ping 10.0.10.1
   ```
   Expected: the new ranges do not respond; management VLAN still works.
3. Confirm `vmbr2`, `vmbr3`, and `vmbr99` do not exist yet.
   ```bash
   ip link show | grep -E 'vmbr[0-9]'
   ```
4. Reserve VM/LXC IDs.
   ```bash
   pct list
   qm list
   ```
5. Check templates are available.
   ```bash
   pveam available | grep debian
   pveam available | grep alpine
   ```

### Phase 1: Create isolated bridges
Goal: build the carrier simulation without touching `vmbr1`.

#### Create `vmbr2` (Site A LAN)
```bash
cat >> /etc/network/interfaces <<'EOF'

auto vmbr2
iface vmbr2 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
``` 

#### Create `vmbr3` (Site B LAN)
```bash
cat >> /etc/network/interfaces <<'EOF'

auto vmbr3
iface vmbr3 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
```

#### Create `vmbr99` (Transit backbone)
```bash
cat >> /etc/network/interfaces <<'EOF'

auto vmbr99
iface vmbr99 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
EOF

systemctl restart networking
```

#### Validate isolation
```bash
ip link show vmbr2
ip link show vmbr3
ip link show vmbr99
ip route show | grep -E 'vmbr(2|3|99)'
ping 192.168.0.1
ping 10.0.10.1
```
Expected:
- bridges exist and are UP
- no routes are installed on them
- no access to home or management networks
- management network still works

---

## 4. Router Provisioning

### Create `edge-rtr-a` (AS 65001)
```bash
pct create 200 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  -hostname edge-rtr-a \
  -storage Sovereign_VMs \
  -cores 2 \
  -memory 512 \
  -swap 256 \
  -net0 name=eth0,bridge=vmbr2,ip=dhcp \
  -net1 name=eth1,bridge=vmbr99,ip=dhcp

pct start 200
pct exec 200 bash
```

### Configure `edge-rtr-a`
Inside the container:
```bash
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

auto lo:1
iface lo:1 inet static
    address 10.255.255.1/32
EOF

systemctl restart networking
sysctl -w net.ipv4.ip_forward=1
```

### Install FRR
```bash
apt update
apt install -y frr frr-pythontools
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sed -i 's/^bfdd=no/bfdd=yes/' /etc/frr/daemons
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable frr
systemctl restart frr
vtysh -c "show version"
```

### Create `edge-rtr-b` (AS 65002)
```bash
pct create 201 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  -hostname edge-rtr-b \
  -storage Sovereign_VMs \
  -cores 2 \
  -memory 512 \
  -swap 256 \
  -net0 name=eth0,bridge=vmbr3,ip=dhcp \
  -net1 name=eth1,bridge=vmbr99,ip=dhcp

pct start 201
pct exec 201 bash
```

### Configure `edge-rtr-b`
```bash
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback
    address 127.0.0.1/8

auto eth0
iface eth0 inet static
    address 10.20.20.1/24

auto eth1
iface eth1 inet static
    address 172.16.1.2/30

auto lo:1
iface lo:1 inet static
    address 10.255.255.2/32
EOF

systemctl restart networking
sysctl -w net.ipv4.ip_forward=1
```

### Install FRR on Site B
```bash
apt update
apt install -y frr frr-pythontools
sed -i 's/^bgpd=no/bgpd=yes/' /etc/frr/daemons
sed -i 's/^bfdd=no/bfdd=yes/' /etc/frr/daemons
sed -i 's/^ospfd=no/ospfd=yes/' /etc/frr/daemons
systemctl enable frr
systemctl restart frr
```

---

## 5. BGP + BFD Setup

### Router A BGP config
```bash
vtysh
configure terminal
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

### Router B BGP config
```bash
vtysh
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

### BFD config on both peers
```bash
vtysh
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

On Site B:
```bash
vtysh
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

### Attach BFD to BGP neighbors (recommended)
```bash
vtysh
configure terminal
router bgp 65001
 neighbor 172.16.1.2 bfd
end
write memory
exit
```

```bash
vtysh
configure terminal
router bgp 65002
 neighbor 172.16.1.1 bfd
end
write memory
exit
```

---

## 6. Validation Gate
This is the hard stop before scaling further.

### Confirm peering and route learning
From either router:
```bash
vtysh -c "show bgp summary"
vtysh -c "show bfd peers"
vtysh -c "show ip bgp neighbors 172.16.1.2 received-routes"
```

Expected:
- BGP state is established
- BFD peers show `up`
- each router learns the opposite site prefix
- `ip route show` includes remote LAN route via transit peer

### Confirm end-to-end ping
Create the two endpoint hosts and verify they can reach each other.

```bash
# On client-a1
ping -c 3 10.20.20.11

# On ont-b1
ping -c 3 10.10.10.11
```
Expected: successful replies with TTL ~62.

---

## 7. Add Test Hosts

### Site A host
```bash
pct create 210 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  -hostname client-a1 \
  -storage Sovereign_VMs \
  -cores 1 \
  -memory 128 \
  -net0 name=eth0,bridge=vmbr2,ip=dhcp

pct start 210
pct exec 210 bash
```
Inside the container:
```bash
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.10.10.11/24
    gateway 10.10.10.1
EOF

systemctl restart networking
ip addr show
ping 10.10.10.1
```

### Site B host
```bash
pct create 220 local:vztmpl/alpine-3.22-default_20250617_amd64.tar.xz \
  -hostname ont-b1 \
  -storage Sovereign_VMs \
  -cores 1 \
  -memory 128 \
  -net0 name=eth0,bridge=vmbr3,ip=dhcp

pct start 220
pct exec 220 sh
```
Inside the container:
```bash
cat > /etc/network/interfaces <<'EOF'
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
    address 10.20.20.11/24
    gateway 10.20.20.1
EOF

rc-service networking restart
ip addr show
ping 10.20.20.1
```

---

## 8. Observability and Triage
After the base eBGP path is validated, deploy the alerting stack:
- FRR exporters on both routers
- Node exporters on both routers
- Prometheus on `prometheus-mon`
- Alertmanager on `prometheus-mon`
- FastAPI triage worker on `triage-worker`

This is part of the same Phase 1 proof, but it should occur only after the BGP/BFD domain is stable.

---

## 9. Controlled Failure Demo
This is the final proof that the system works as expected.

### Inject a fault
```bash
pct exec 200 bash -c 'ip link set dev eth1 down'
```

### Expected timeline
- BFD detects failure within ~300–900 ms
- BGP session drops
- Prometheus sees route state change
- Alertmanager sends alert to triage worker
- triage worker SSHes into the router and captures CLI evidence

### Restore the link
```bash
pct exec 200 bash -c 'ip link set dev eth1 up'
```

---

## 10. Exit Criteria for Phase 1
The Phase 1 rollout is complete only when all of the following are true:

- [ ] `vmbr2`, `vmbr3`, and `vmbr99` exist and are isolated
- [ ] `vmbr0` and `vmbr1` remain untouched and healthy
- [ ] `edge-rtr-a` and `edge-rtr-b` are provisioned and FRR is running
- [ ] BGP is established between AS `65001` and `65002`
- [ ] BFD peers are `up`
- [ ] each router learns the opposite site's route
- [ ] test hosts can reach across the simulated WAN
- [ ] alerting and triage path is functioning
- [ ] the failure/recovery cycle is repeatable

---

## 11. Rollback
If a phase goes bad:

```bash
pct destroy 200
pct destroy 201
pct destroy 210
pct destroy 220
pct destroy 230
pct destroy 240
```

Then remove the bridges from `/etc/network/interfaces` and restart networking.

---

## 12. Planning Rule for What Comes Next
Once this phase is stable, the next step is not a broader, more complicated Layer 3 design. The next step is automation:

- NetBox for IPAM / source of truth
- Terraform for Proxmox provisioning
- Ansible for FRR template deployment
- OSPFv3 for internal AS growth after the eBGP backbone is proven

This keeps the design clean: first prove the carrier backbone, then automate the network expansion.
