# 🧭 Baseline Audit: Live Proxmox State vs. Documented Architecture

**Date:** 2026-08-15
**Context:** Captured immediately after standing up local, read-only AI (MCP) access to Proxmox, prior to the multi-site vWAN / BGP expansion work.
**Purpose:** Establish a verified "before" snapshot so drift from this expansion can be measured honestly once the new bridges and BGP peering go in.

---

## 🔎 Method

State was pulled directly from the Proxmox REST API using a read-only (`PVEAuditor`) token, via a local, gitignored MCP bridge. No data below is from memory or documentation — it is a live query result.

---

## ✅ Confirmed Matches (Docs Align With Reality)

| Item | Documented | Live State | Status |
|---|---|---|---|
| Core Router | LXC 100, FRR gateway | `lxc/100 core-router` — running | ✅ Match |
| Management Workstation | VM 101, sovereign-ops | `qemu/101 sovereign-ops` — running | ✅ Match |
| DNS | LXC 104, dns-primary / Technitium | `lxc/104 dns.sovereign.lab` — running | ✅ Match |
| Storage Tiers | Local SSD / Vault_Backups / Bahamut_P_Drive | `local-lvm`, `Sovereign_VMs`, `Vault_Backups`, `Bahamut_P_Drive` all present | ✅ Match |

## ⚠️ Drift Identified

| Item | Documented Expectation | Live Reality | Notes |
|---|---|---|---|
| Netdata Telemetry (LXC 103) | Described as an active monitoring service | Status: **stopped** | Needs a decision: intentionally down, or needs a restart before expansion work begins |
| Hypervisor Node Name | README table lists node as `sovereign` | Live API reports node as `pve` | Cosmetic/documentation drift — worth reconciling so future audits aren't confusing |
| Ghost-User (LXC 102) | Documented in [01_Infrastructure/Ghost-User-VM102.md](../01_Infrastructure/Ghost-User-VM102.md) | Present and running (`lxc/102 ghost-user-01`) | Not listed in the README summary table — doc coverage gap, not an operational issue |
| Resource Pools | Not explicitly documented either way | Empty (`pools: []`) | Not a problem, just noting the cluster has no logical pool groupings defined |

---

## 🧱 Pre-Expansion Snapshot (for later comparison)

- Node: `pve` — online, 4 vCPU, ~33GB RAM
- Running workloads: LXC 100, VM 101, LXC 102, LXC 104
- Stopped workloads: LXC 103
- Storage backends: `local`, `local-lvm`, `Sovereign_VMs`, `Vault_Backups`, `Bahamut_P_Drive`
- No cluster-level pools or unresolved cluster log alerts at time of capture

This snapshot should be treated as the pre-change baseline for the vmbr1/vmbr2/vmbr99 and BGP peering work described in the [Leviathan_Node_Migration_Project.md](Leviathan_Node_Migration_Project.md) change series. Once the expansion lands, re-run the same read-only queries and diff against this table.

---

## 📌 Follow-Up Actions

- [ ] Decide whether LXC 103 (Netdata) should be restarted before or after the network expansion
- [ ] Reconcile the `sovereign` vs `pve` node naming between docs and reality
- [ ] Add LXC 102 to the README summary table for documentation completeness
