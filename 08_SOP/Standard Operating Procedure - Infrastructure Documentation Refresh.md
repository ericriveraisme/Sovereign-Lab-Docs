## 1. Overview

This SOP defines how the Sovereign Lab keeps its infrastructure documentation synchronized with the live Proxmox environment. It exists because hand-maintained docs (`Architecture_Overview_1.1.md`, `Network-Architecture.md`) drift out of date, forcing expensive live-API discovery (and MCP token spend) every time a new project needs to validate assumptions against reality.

The fix: a read-only script queries Proxmox on a schedule and regenerates a machine-generated **source of truth** snapshot. Human-authored docs reference that snapshot instead of re-deriving it from memory.

### Key Principle

> **Live API validates docs. It does not replace them.**
> The API is the ground truth. The auto-generated snapshot is the fast, cheap mirror of that truth. Hand-written docs (architecture rationale, diagrams, decisions) are reconciled against the snapshot on a schedule — not re-discovered from scratch on every task.

## 2. What Gets Generated

| File | Type | Update Method |
|:---|:---|:---|
| [Infrastructure-State-Snapshot.md](../01_Infrastructure/Infrastructure-State-Snapshot.md) | Auto-generated | `09_Scripts/refresh_infra_snapshot.py` (never hand-edit) |
| [Architecture_Overview_1.1.md](../01_Infrastructure/Architecture_Overview_1.1.md) | Hand-authored | Reconciled monthly against the snapshot |
| [Network-Architecture.md](../01_Infrastructure/Network-Architecture.md) | Hand-authored | Reconciled monthly against the snapshot |

The snapshot lists, per node: status, CPU/memory, all network bridges (address, active state, physical ports), and every VM/LXC with its status and attached bridges. It is intentionally flat and factual — no narrative, no rationale, just what the API returned.

## 3. Prerequisites

- **Credentials**: `.vscode/mcp.json` must exist locally with a valid `PROXMOX_TOKEN_ID` / `PROXMOX_TOKEN_SECRET` for a **read-only** API token (`PVE_READONLY=true`). This file is gitignored (`.git/info/exclude`) and must never be committed.
- **Network reachability**: The machine running the script must be able to reach `PROXMOX_HOST` (currently over Tailscale, `100.94.80.7:8006`).
- **Python 3**: No third-party dependencies — uses only the standard library (`urllib`, `ssl`, `json`).

## 4. Running the Refresh

### Manual (on-demand, e.g. before starting a new deployment project)

```bash
cd /home/eric/Sovereign-Lab-Docs
python3 09_Scripts/refresh_infra_snapshot.py
git add 01_Infrastructure/Infrastructure-State-Snapshot.md
git commit -m "docs: refresh infrastructure snapshot"
```

Run this **before** planning any change that depends on current bridge/VM/IP state — it costs one script execution instead of several ad-hoc MCP queries and token spend re-discovering the same facts.

### Scheduled (monthly cron)

Add to the crontab on whichever host has both the repo checked out and Tailscale reachability to Proxmox (e.g. `sovereign-ops`):

```
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
HOME=/home/eric

# Refresh the infrastructure snapshot on the 1st of every month at 06:00
0 6 1 * * cd /home/eric/Sovereign-Lab-Docs && /usr/bin/python3 09_Scripts/refresh_infra_snapshot.py && git add 01_Infrastructure/Infrastructure-State-Snapshot.md && git commit -m "docs: monthly infrastructure snapshot refresh" && git push >> /home/eric/scripts/infra_refresh.log 2>&1
```

This mirrors the existing pattern used by the [router backup SOP](Standard%20Operating%20Procedure%20-%20Automated%20Git-Based%20Router%20Backups.md): idempotent, logs output, and commits only when something changes (git will simply produce a no-op commit if content is identical — acceptable at monthly cadence, unlike the daily router backup).

## 5. Monthly Reconciliation Checklist

After the snapshot regenerates (automatically or manually), a human reviews it against the hand-authored docs and updates a **"Last Verified"** line at the top of each:

1. Open [Infrastructure-State-Snapshot.md](../01_Infrastructure/Infrastructure-State-Snapshot.md) and diff it mentally (or with `git diff`) against the previous version.
2. If bridges, VM/LXC inventory, or node resources changed, update the narrative sections of `Architecture_Overview_1.1.md` and `Network-Architecture.md` accordingly.
3. Bump the `**Last Verified:**` line in both docs to the snapshot's timestamp.
4. Commit both the snapshot and any hand-authored doc updates together.

**Staleness rule:** if `Last Verified` on a hand-authored doc is more than 30 days old when a new project starts, run the refresh script before doing any planning work.

## 6. Troubleshooting

- **`FileNotFoundError: .vscode/mcp.json`**: The script must be run from a machine with the local MCP config present. Copy `.vscode/mcp.json` (never commit it) or set the same env vars directly and adjust `load_credentials()`.
- **`HTTPError 401`**: The API token has been revoked or rotated. Regenerate the token in Proxmox (Datacenter → Permissions → API Tokens) and update `.vscode/mcp.json`.
- **`URLError`/timeout**: Confirm Tailscale connectivity to `100.94.80.7` from the machine running the script (`tailscale ping <host>`).
- **Snapshot shows unexpected bridges/VMs**: This is the system working as intended — it means the hand-authored docs are stale. Do not edit the snapshot; update the narrative docs instead.
