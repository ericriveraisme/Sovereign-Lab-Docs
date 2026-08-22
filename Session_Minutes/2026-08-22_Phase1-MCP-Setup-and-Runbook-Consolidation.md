# Session Minutes: Phase 1 MCP Setup & Runbook Consolidation
**Date:** 2026-08-22  
**Duration:** ~2.5 hours  
**Attendees:** Eric (solo)  
**Outcome:** Phase 1 Dual-Site BGP deployment runbook ready for execution; infrastructure refresh SOP established; all prerequisites validated

---

## Objectives

1. Validate Proxmox MCP connection from work laptop tunnel
2. Consolidate conflicting Phase 1 planning documents into a single executable runbook
3. Identify and document infrastructure constraints before executing Phase 0
4. Establish operational discipline for infrastructure documentation refresh

## Work Completed

### ✅ 1. Infrastructure Discovery & Documentation Reconciliation

**Discovery:** Used MCP queries to inspect live Proxmox state
- Confirmed actual node name: `pve` (not `sovereign` as older docs suggested)
- Confirmed existing infrastructure: 5 containers (100–104) on vmbr0/vmbr1
- Discovered vmbr1 is shared production backbone carrying VLAN 10 & 20, plus core-router spine
- Confirmed vmbr2/3/4 are available for Phase 1 isolation

**Risk Identified:** Original Phase 1 design planned to use vmbr1 (shared with production)
- This would allow routing faults in Phase 1 to cascade to management/telemetry networks
- Could potentially poison default routes and disconnect Proxmox from ISP uplink
- **Resolution:** Shifted Phase 1 to use new isolated bridges (vmbr2, vmbr3, vmbr4)

**Outcome:** 
- Updated [Architecture_Overview_1.1.md](../01_Infrastructure/Architecture_Overview_1.1.md) with "Last Verified" timestamp
- Created [Infrastructure-State-Snapshot.md](../01_Infrastructure/Infrastructure-State-Snapshot.md) — auto-generated from live API, never hand-edit
- Documented the design decision and safety rationale in [Phase-1-Design-Decisions.md](../04_Change_Logs/Phase-1-Design-Decisions.md)

### ✅ 2. Infrastructure Documentation Refresh SOP

**Problem Identified:** MCP queries burned tokens unnecessarily because docs were stale and did not match reality

**Solution Implemented:**
- Created [refresh_infra_snapshot.py](../09_Scripts/refresh_infra_snapshot.py) — Python script that queries live Proxmox (read-only MCP token) and regenerates Infrastructure-State-Snapshot.md
- Written [Standard Operating Procedure - Infrastructure Documentation Refresh.md](../08_SOP/Standard%20Operating%20Procedure%20-%20Infrastructure%20Documentation%20Refresh.md)
  - Manual refresh workflow (before new projects start)
  - Automated monthly cron refresh (1st @ 06:00, mirrors router backup SOP pattern)
  - Reconciliation checklist (human reviews snapshot, updates narrative docs, bumps "Last Verified" line)
  - Staleness rule: if doc's "Last Verified" is >30 days old when starting new work, refresh first instead of ad-hoc API discovery

**Outcome:** Future projects can validate infrastructure state with one script run instead of multiple API queries. Establishes "docs as code" principle: live API validates docs, never replaces them.

### ✅ 3. Phase 1 Dual-Site BGP Runbook Consolidation

**Problem Identified:** Multiple conflicting draft plans (Leviathan migration notes, project review doc, ad-hoc session notes) all proposing Phase 1 structure with different bridge allocations and phasing

**Solution Implemented:**
- Consolidated all plans into a single unified 8-phase runbook: [Phase-1-Dual-Site-BGP-Deployment.md](../03_Runbooks/Phase-1-Dual-Site-BGP-Deployment.md)
- Phases 0–8 cover:
  - **Phase 0:** Inventory & design freeze (verify Proxmox state, no conflicts)
  - **Phase 1:** Create vmbr2, vmbr3, vmbr4 bridges (isolated, no physical ports)
  - **Phase 2:** Provision edge-rtr-a (AS 65001) and edge-rtr-b (AS 65002) with FRR
  - **Phase 3:** BGP peering, BFD, loopback routes
  - **Phase 4:** Test clients (client-a1, ont-b1) for traffic generation
  - **Phase 5:** Prometheus + exporters for observability
  - **Phase 6:** Alertmanager alert routing
  - **Phase 7:** Python FastAPI triage-worker for automated root-cause collection
  - **Phase 8:** Controlled failure injection demo

**Key Fixes Applied:**
- Corrected all bridge allocations from original vmbr1/2/3 to vmbr2/3/4 (production-safe isolation)
- Fixed LXC template versions to match actual available images (Debian 12.12, Alpine 3.22)
- Added explicit `-storage Sovereign_VMs` to all `pct create` commands (ensures disks go to dedicated LVM-thin pool, not default local-lvm)
- Added multi-homed NICs to prometheus-mon (230) and triage-worker (240):
  - eth0 on vmbr1 (VLAN 10 management, for alerting)
  - eth1 on vmbr2/3 (to reach Site A/B routers for scraping/SSH)
  - Documented `net.ipv4.ip_forward=0` safeguard (not routers, cannot bridge networks)
- Documented why vmbr1 is unsafe (ISP cascade risk, would poison default routes)

**Outcome:** Single source-of-truth 8-phase runbook with corrected design, validated against actual infrastructure state, ready to execute starting Phase 0.

### ✅ 4. Execution Infrastructure Setup

**SSH Trust Establishment:**
- Established passwordless key-based SSH from `sovereign-ops` to `pve` (Tailscale path `100.94.80.7`)
- Verified with `BatchMode=yes` test (no password prompt required)

**Shell Aliases (on sovereign-ops):**
- Added `proxmox='ssh root@100.94.80.7'` to `~/.bashrc`
- Mirrors existing `lab` alias for sovereign-ops access
- Documented in runbook prerequisites section (no explicit IPs/credentials in version control)

**LXC Template Pre-staging:**
- Downloaded Debian 12.12 template to `/var/lib/vz/template/cache/` (local storage, boot drive)
- Downloaded Alpine 3.22 template to same location
- Confirmed templates registered in `pveam list local`
- Verified storage architecture (templates on `local`, container disks on `Sovereign_VMs` LVM-thin pool)

**Outcome:** All prerequisites for Phase 0/1/2 execution are in place. Can proceed with `proxmox "pct create ..."` commands from any terminal on sovereign-ops.

### ✅ 5. Repository Documentation Updates

**Updated/Created:**
- [Architecture_Overview_1.1.md](../01_Infrastructure/Architecture_Overview_1.1.md) — added "Last Verified Against Live State" header
- [Network-Architecture.md](../01_Infrastructure/Network-Architecture.md) — added "Last Verified" header, linked to refresh SOP
- [Phase-1-Design-Decisions.md](../04_Change_Logs/Phase-1-Design-Decisions.md) — new file explaining vmbr1 ISP cascade risk, why isolation is chosen, multi-homed bastion exception
- [Infrastructure-State-Snapshot.md](../01_Infrastructure/Infrastructure-State-Snapshot.md) — auto-generated from live API, timestamped 2026-08-22 15:51 UTC
- Session memory files:
  - `/memories/repo/infra-doc-refresh.md` — SOP and naming conventions for future sessions
  - `/memories/session/Phase-1-Deployment-Progress.md` — phase checklists and quick reference

## Key Decisions

1. **Isolation over convenience:** Phase 1 uses separate bridges (vmbr2/3/4) instead of sharing vmbr1
   - Safety: Production faults in Phase 1 BGP config are completely contained
   - Internet connectivity remains stable (vmbr0 untouched)
   - UPS coordination (NUT) never at risk

2. **Documentation refresh as first-class SOP:** Live state queries should be scheduled and deduplicated, not ad-hoc
   - Reduces token spend (one monthly refresh vs per-task discovery)
   - Establishes ground truth (snapshot) that human docs reconcile against
   - Operational discipline (stale docs = blocker, not a surprise)

3. **Multi-homed monitoring containers are safe bastions:** prometheus-mon and triage-worker touch both production and isolated networks
   - Only possible because `net.ipv4.ip_forward=0` (Debian default, never enabled)
   - Allows observability without breaking isolation
   - Documented safeguard: runbook will explicitly verify `sysctl net.ipv4.ip_forward` = 0

## Blockers Encountered & Resolved

| Blocker | Root Cause | Resolution |
|:---|:---|:---|
| Wrong node name in commands | Docs assumed node was `sovereign`, actually `pve` | Updated all references; verified with live API query |
| vmbr1 conflict | Original plan used vmbr1 (shared production), risked cascade failures | Shifted to vmbr2/3/4; documented safety rationale in Phase-1-Design-Decisions.md |
| LXC template versions stale | Runbook referenced debian-12-standard_12.2-1, only 12.12-1 available | Updated template versions in all pct create commands; downloaded both templates |
| Prometheus/triage-worker couldn't reach routers | Placed on vmbr1 only; isolated networks unreachable | Added eth1/eth2 NICs on vmbr2/vmbr3 for direct access; documented bastion safeguard |
| JSON syntax error in multi_replace | Tool call with malformed array structure | Switched to sequential replace_string_in_file for simpler execution |

## Next Steps (For Continuation)

1. **Phase 0 Execution:** Run `proxmox "ip link show | grep -E 'vmbr[0-4]'"` to confirm bridge state
2. **Phase 1 Execution:** Create vmbr2/3/4 via `proxmox "cat >> /etc/network/interfaces << ... "`
3. **Phase 2 Execution:** Provision edge-rtr-a (LXC 200) and edge-rtr-b (LXC 201) with FRR
4. **Ongoing:** Monthly infrastructure snapshot refresh (configured in cron, no manual effort)

## Artifacts Created This Session

- [03_Runbooks/Phase-1-Dual-Site-BGP-Deployment.md](../03_Runbooks/Phase-1-Dual-Site-BGP-Deployment.md) — 8-phase executable runbook
- [04_Change_Logs/Phase-1-Design-Decisions.md](../04_Change_Logs/Phase-1-Design-Decisions.md) — topology rationale and risk analysis
- [08_SOP/Standard Operating Procedure - Infrastructure Documentation Refresh.md](../08_SOP/Standard%20Operating%20Procedure%20-%20Infrastructure%20Documentation%20Refresh.md) — refresh workflow and cron setup
- [09_Scripts/refresh_infra_snapshot.py](../09_Scripts/refresh_infra_snapshot.py) — automated snapshot generator
- [01_Infrastructure/Infrastructure-State-Snapshot.md](../01_Infrastructure/Infrastructure-State-Snapshot.md) — machine-generated live state (2026-08-22 15:51 UTC)
- Session memory: `/memories/repo/infra-doc-refresh.md` and `/memories/session/Phase-1-Deployment-Progress.md`

## Lessons Learned

1. **Query API early with correct parameters:** Wrong node name assumption caused multiple retries and token waste. Validate assumptions against live state in Phase 0, before planning.
2. **Stale docs are more expensive than fresh queries:** If a doc hasn't been verified in 30+ days, one automated refresh script run is cheaper than ad-hoc API discovery during active work.
3. **Isolation is safety in simulation labs:** When testing routing config and faults, air-gap from production is non-negotiable. Accept the extra containers/bridges as the cost of safe chaos testing.
4. **Bridges aren't routers:** Multi-homed LXCs with `ip_forward=0` can touch multiple networks without becoming transparent bridges. This enables monitoring/bastions without risking cascade.

---

**Session Status:** ✅ Complete. Runbook ready for Phase 0 execution. Operator can proceed at own pace.
