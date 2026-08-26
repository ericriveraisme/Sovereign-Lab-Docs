# Phase 1 Design Decisions & Topology Analysis
**Date:** 2026-08-22  
**Context:** Dual-Site BGP Simulation on Sovereign Lab Proxmox

---

## Question: What Would vmbr1 Be in an ISP Deployment Simulation?

If Phase 1 is simulating an ISP network with autonomous systems, provider edges, and transit links, the question is: **what role should vmbr1 play?**

### Current vmbr1 State

**vmbr1 is the existing internal lab backbone**, carrying:
- VLAN 10 (Management): DNS, Prometheus, monitoring, management VMs
- VLAN 20 (Host): User workloads, sandbox environments
- Core-Router spine: `10.0.0.0/24` backbone routing

**Containers on vmbr1:**
- LXC 100: core-router (the active lab gateway)
- VM 101: sovereign-ops (management cockpit)
- LXC 102: ghost-user-01 (sandbox)
- LXC 103: netdata-monitor (telemetry)
- LXC 104: dns.sovereign.lab (authoritative DNS)

### ISP Topology Interpretation

In a real ISP deployment, there are distinct layer concepts:

```text
ISP BACKBONE (Layer 2/3 Carrier)
├── Aggregate traffic from multiple customer/provider sites
├── Carry VLAN-tagged traffic
├── Connect disparate autonomous systems
└── Provide service delivery to edge routers

CUSTOMER/PROVIDER EDGE (Layer 1-2)
├── Site-specific routers (AS 65001, AS 65002, etc.)
├── Connect to the backbone via transit links
├── Maintain local LAN segments
└── Peer with other edges via the backbone
```

**In this model, vmbr1 could theoretically be:**
- **The provider backbone** carrying VLAN-tagged traffic between sites
- vmbr2, vmbr3 could be customer/provider edges (local LANs)
- A single point of connectivity between simulated sites

### Why We Did NOT Use vmbr1 for Phase 1

Even though vmbr1 *could* represent the backbone in an ISP model, **we chose isolation** for three critical reasons:

#### 1. **Production Risk: Network Storm Cascade**

If Phase 1 runs on the same vmbr1 as production:

```text
Phase 1 BGP Misconfiguration
    ↓
Announces invalid routes on vmbr1
    ↓
Core-router receives routes
    ↓
Routes poison VLAN 10/20 traffic
    ↓
DNS, Prometheus, monitoring goes dark
    ↓
Proxmox to Bahamut UPS connection fails
    ↓
No coordinated shutdown during power event
```

**Result:** Testing a chaos condition could disable the production lab's ability to handle real power events.

#### 2. **Internet Connectivity Risk: vmbr0 → vmbr1 Cascade**

The most dangerous scenario:

```text
Network Topology:
┌──────────────────────────┐
│  Proxmox Host (pve)      │
│  192.168.0.232/24        │
│                          │
│  ┌──────────────────┐    │
│  │ vmbr0 (physical) │ ───┼─→ Home network (192.168.0.0/24)
│  │ 192.168.0.232    │    │   ↑ Connected to ISP
│  └────────┬─────────┘    │   ↑ Critical for Proxmox mgmt
│           │              │
│           ↓              │
│  ┌──────────────────┐    │
│  │ vmbr1 (backbone) │    │
│  │ Production VLANs │    │
│  │ (10, 20, spine)  │    │
│  └────────┬─────────┘    │
│           │              │
│           ↓              │
│  [LXC 100-104 in use]    │
│           │              │
└───────────┼──────────────┘
            │
        [If Phase 1 were here]
```

**The Risk Chain:**

1. Phase 1 router on vmbr1 receives a malformed routing update
2. Router advertises a default route `0.0.0.0/0` back onto vmbr1
3. Core-router sees this route and installs it
4. Traffic destined for the Proxmox host is redirected into Phase 1 simulation
5. Proxmox loses connectivity to the physical network
6. Proxmox cannot reach ISP gateway (`192.168.0.1`)
7. Proxmox cannot reach Bahamut via NUT (which goes through the physical network first)
8. UPS coordination fails during power event
9. Uncontrolled shutdown cascade

**Example attack vector (naive BGP misconfiguration):**
```bash
# If edge-rtr-a is on vmbr1, this would be catastrophic:
router bgp 65001
  redistribute connected  # Accidentally redistributes vmbr1 networks
  redistribute static
  default-information originate  # Announces fake default route
```

### Why Isolation (vmbr2, vmbr3, vmbr99) Is Safer

**Physical Isolation = Network Isolation:**

```text
┌────────────────────────────────────────────────────┐
│ Proxmox Host (pve)                                 │
│                                                    │
│ ┌─ PRODUCTION ─────────────────────────────────┐  │
│ │ vmbr0: 192.168.0.232/24 → ISP (CRITICAL)    │  │
│ │  ↓                                            │  │
│ │ vmbr1: internal backbone (VLAN 10, 20)       │  │
│ │  ├─ LXC 100: core-router (gateway)           │  │
│ │  ├─ VM 101: sovereign-ops (management)       │  │
│ │  ├─ LXC 103: netdata (telemetry)             │  │
│ │  └─ LXC 104: dns.sovereign.lab               │  │
│ └─────────────────────────────────────────────┘  │
│                                                    │
│ ┌─ PHASE 1 (ISOLATED) ──────────────────────────┐ │
│ │ vmbr2: 10.10.10.0/24 (Site A LAN) [ISOLATED] │ │
│ │  ├─ LXC 200: edge-rtr-a (AS 65001)           │ │
│ │  └─ LXC 210: client-a1 (test traffic)        │ │
│ │                                                │ │
│ │ vmbr3: 10.20.20.0/24 (Site B LAN) [ISOLATED] │ │
│ │  ├─ LXC 201: edge-rtr-b (AS 65002)           │ │
│ │  └─ LXC 220: ont-b1 (test subscriber)        │ │
│ │                                                │ │
│ │ vmbr99: 172.16.1.0/30 (Transit Backbone) [ISOLATED] │ │
│ │  ├─ LXC 200 eth1: 172.16.1.1/30              │ │
│ │  └─ LXC 201 eth1: 172.16.1.2/30              │ │
│ └────────────────────────────────────────────────┘ │
│                                                    │
│ ISOLATION GUARANTEE:                              │
│ ✓ Phase 1 routers cannot reach vmbr0 or vmbr1    │
│ ✓ Phase 1 traffic stays on vmbr2/3/4              │
│ ✓ BGP/BFD faults are contained                    │
│ ✓ Management network is unreachable               │
│ ✓ Internet connection (vmbr0) is never touched    │
│ ✓ UPS coordination works even during Phase 1 faults│
│                                                    │
└────────────────────────────────────────────────────┘
```

**Result:**
- Testing can be aggressive and chaotic
- Faults cannot cascade to production
- Internet connectivity is guaranteed to remain stable
- Proxmox can always communicate with Bahamut over NUT

---

## Could Phase 1 Use vmbr1 Eventually?

**Yes, but only after:**

1. **Strict network policies** are defined and tested
   - BGP route filtering on core-router
   - VLAN tagging with administrative isolation
   - Static routes instead of dynamic redistribution

2. **Circuit breakers** are deployed
   - Prefix limits (no more than X routes from Phase 1)
   - Community filtering
   - Route dampening

3. **Monitoring and alerting** are in place
   - Alert if Phase 1 announces default route
   - Alert if Phase 1 announces Proxmox's own subnets
   - Alert if BGP withdrawal storms occur

4. **Failover procedures** are documented and tested
   - How to quickly isolate Phase 1 if it goes rogue
   - Manual BGP session shutdown commands
   - Restart procedures

5. **A separate test window** is established
   - Phase 1 runs only during scheduled test windows
   - Never during production operations
   - Clear handoff between "safe testing" and "lab operations"

**Until then: Keep them separate.**

---

## ISP Topology Interpretation: What We're Actually Building

The choice of isolated bridges (vmbr2, vmbr3, vmbr99) **does not diminish** the ISP simulation value. Instead, it represents a more realistic enterprise networking scenario:

```text
ISP BACKBONE (would be vmbr1 with circuit-breaker policies)

    ┌─────────────────────────────────────────────┐
    │         Provider Backbone Network           │
    │     (would require firewalls/policies)      │
    │         [Concept: not yet deployed]         │
    └─────────────┬───────────────────────────────┘
                  │
      ┌───────────┴────────────┐
      │                        │
   [AS 65001]              [AS 65002]
   (Edge RTR A)            (Edge RTR B)
   10.10.10.0/24           10.20.20.0/24
   172.16.1.1/30           172.16.1.2/30
   [ISOLATED]              [ISOLATED]
      │ Test Clients          │ Test Subscribers
      └─────→ BGP Peering ←───┘
         (172.16.1.0/30 eBGP)
```

**What we're proving:**
1. Two independent ASNs can peer over a transit link ✓
2. BGP session failure detection (BFD) works ✓
3. Automated verification of routing state works ✓
4. Incident alerting and triage is automated ✓

**What we're NOT attempting yet:**
- Multi-VLAN carrier backbone
- Dynamic policy-based routing
- Upstream transit provider peering
- Redundant edge routers

**Future expansion:**
- Once Phase 1 is solid, we can build Phase 2 with:
  - A shared backbone (vmbr1 with policies)
  - Multiple provider edges
  - Real-world WAN latency simulation
  - Provider failover scenarios

---

## Summary: The Design Decision

| Aspect | Current Design (vmbr2/3/4) | Theoretical Design (shared vmbr1) |
|:---|:---|:---|
| **Production Safety** | Isolated, no cascade risk | High risk of cascade |
| **Internet Stability** | Guaranteed safe | Could poison default routes |
| **Testing Freedom** | Aggressive testing allowed | Restricted to safe operations |
| **ISP Realism** | Simulates customer edges + transit | Simulates full backbone (future) |
| **Operational Complexity** | Low (ship immediately) | High (requires policies/monitoring) |

**Conclusion:** Isolation is the right choice for Phase 1. ISP simulation value is not diminished. The architecture is realistic and staged for future expansion.

---

**Next Steps:**
1. Proceed with Phase 1 using vmbr2, vmbr3, vmbr99
2. Document Phase 1 results and lessons learned
3. Plan Phase 2 with proper circuit breakers for vmbr1 integration
4. Establish policy framework for shared backbone scenarios
