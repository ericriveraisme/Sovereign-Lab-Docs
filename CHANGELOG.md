# CHANGELOG

All notable changes to the Sovereign Lab project are documented here. This log tracks infrastructure updates, documentation changes, runbook development, and operational milestones.

## [2026-08-22] — Phase 1 MCP Setup & Runbook Consolidation

### Added
- **Phase-1-Dual-Site-BGP-Deployment.md** — Complete 8-phase executable runbook for dual-site ISP simulation with BGP, BFD, and automated triage
- **Infrastructure-State-Snapshot.md** — Auto-generated current state (node resources, bridges, VM/LXC inventory, VLAN assignments)
- **refresh_infra_snapshot.py** — Python script to query live Proxmox API and regenerate state snapshot (read-only MCP token)
- **SOP: Infrastructure Documentation Refresh** — Scheduled snapshot refresh (monthly cron) and reconciliation workflow
- **Phase-1-Design-Decisions.md** — Design rationale explaining why Phase 1 uses isolated bridges (vmbr2/3/99) instead of production vmbr1, with ISP cascade risk analysis
- **Session_Minutes/** folder — New directory for session notes and operational logs
- **2026-08-22 Session Minutes** — Complete documentation of infrastructure discovery, runbook consolidation, and execution setup
- MCP connection established from VS Code tunnel to sovereign-ops, with read-only API token for state queries
- SSH key trust and shell aliases (`proxmox` alias for pve access) configured on sovereign-ops
- LXC templates staged (Debian 12.12, Alpine 3.22) on Proxmox local storage

### Changed
- **Architecture_Overview_1.1.md** — Added "Last Verified Against Live State" header with timestamp and link to refresh SOP
- **Network-Architecture.md** — Added "Last Verified" header, linking to auto-generated snapshot
- **Lab-Backlog.md** — Marked "Proxmox MCP integration" and "Infrastructure documentation refresh" as completed; marked "Phase 1" and "Prometheus/Grafana" as in-progress
- **README.md** — Added dedicated "Current Phase" section documenting Phase 1 objectives, timeline, and design principles; clarified project direction
- Corrected all Phase 1 runbook `pct create` commands:
  - Updated LXC template versions to actual available images
  - Added explicit `-storage Sovereign_VMs` to all container provisioning (ensures disks go to correct LVM-thin pool)
  - Fixed bridge allocations (vmbr1/2/3 → vmbr2/3/99 for isolation)
  - Explicitly named the dedicated transit backbone as `vmbr99` to make the WAN layer obvious at a glance
  - Fixed Alertmanager webhook target (10.0.10.31:8000 for triage-worker container)
  - Added multi-homed NICs to monitoring containers (prometheus-mon, triage-worker) for reachability to isolated networks

### Fixed
- **Node name mismatch:** Corrected references from `sovereign` (incorrect) to `pve` (actual)
- **vmbr1 shared risk:** Identified that Phase 1 routers on vmbr1 could poison management VLAN and ISP routes; shifted design to isolated bridges with detailed risk analysis documented
- **Storage target confusion:** Clarified that LXC templates download to `local` (`/var/lib/vz/template/cache/` on boot drive), while container disks are provisioned on `Sovereign_VMs` LVM-thin pool (separate physical drives)
- **Template version staleness:** Updated runbook to reference only templates actually available on Proxmox (debian-12-standard_12.12-1, alpine-3.22-default_20250617)

### Infrastructure Verified
- Proxmox node `pve`: 4 CPUs, 31.1 GiB RAM, online
- Existing infrastructure: 5 containers (core-router 100, sovereign-ops 101, ghost-user-01 102, netdata-monitor 103, dns.sovereign.lab 104)
- Existing bridges: vmbr0 (physical 192.168.0.232), vmbr1 (internal VLAN-aware backbone)
- Available bridges: vmbr2, vmbr3, vmbr99 (free for Phase 1 transit backbone)
- Address space: 10.10.10.x, 10.20.20.x, 172.16.1.x confirmed unused
- Container IDs 200–240 confirmed free for Phase 1 provisioning
- Storage: `Sovereign_VMs` LVM-thin pool has 380GB available; `local` boot storage has 35GB available

### Documentation Principles Established
- **"Docs as code":** Live Proxmox API validates docs, never replaces them
- **Staleness rule:** If infrastructure doc's "Last Verified" timestamp is >30 days old when starting new work, run refresh script before planning (cheaper than ad-hoc API queries)
- **Single source of truth:** Infrastructure-State-Snapshot.md is auto-generated and machine-read, never hand-edited; human narrative docs (Architecture_Overview, Network-Architecture) are reconciled against it
- **Isolation for safety:** Monitoring/triage containers can touch multiple networks only if `net.ipv4.ip_forward=0` (plain LXCs are bastions, not routers)

### Next Steps (Phase 0 Ready)
- Execute Phase 0: Verify current state matches snapshot
- Execute Phase 1: Create isolated bridges (vmbr2, vmbr3, vmbr99) and validate the transit backbone before expanding the AS
- Execute Phase 2: Provision edge routers (VMID 200, 201) with FRR
- Ongoing: Monthly infrastructure snapshot refresh (configured in cron)

---

## [2026-05-13] — Architecture_Overview_1.1.md Last Reviewed

Previous stable documentation captured infrastructure as of mid-May 2026. Infrastructure state has been re-verified and updated for Phase 1 deployment planning (see 2026-08-22 entry above).

---

## Earlier Milestones

- [2026-03-15] — Router backup automation with Git and Cron
- [2026-03-13] — Proxmox Baseline Audit and NUT master/slave verification
- [2026-01-XX] — Leviathan node migration and system hardening work
- [2025-XX-XX] — Core infrastructure deployment: Proxmox, FRR core-router, Technitium DNS, Netdata telemetry, Tailscale overlay networking
