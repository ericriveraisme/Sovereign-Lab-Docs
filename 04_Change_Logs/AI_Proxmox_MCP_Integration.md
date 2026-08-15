# AI-Assisted Proxmox Integration (Local-Only)

## Purpose

This change introduces a local AI access pattern for the Sovereign Lab that allows a coding assistant to inspect Proxmox state, review infrastructure context, and help with planning and validation without committing live secrets to the public repository.

## Scope

- Target system: local workstation running the editor and AI tools
- Target environment: Proxmox host at the lab site
- Access model: read-only by default, human-approved execution
- Repository role: documentation and architecture context only

## Separation of Concerns

The public repository remains the system-of-record for:
- architecture overview
- lab topology and documentation
- routing and infrastructure design
- change tracking and runbook history

The local MCP workspace remains the runtime layer for:
- Proxmox token configuration
- MCP server details
- editor integration
- machine-specific secrets and settings

This folder is intentionally gitignored and should never be pushed to GitHub.

## Security Posture

- The Proxmox API token is never stored in a committed repository file.
- Access is limited to the minimum viable permission level.
- Preferred starting role: PVEAuditor
- Any future write-capable token should be scoped narrowly and reviewed by the operator.

## Operational Model

1. The AI reads the repo for lab context and architecture.
2. The local MCP connection provides live state from Proxmox.
3. The operator reviews suggested actions before execution.
4. The AI can validate changes or provide troubleshooting context after execution.

## Current Expansion Context

This pattern supports the active lab expansion work involving:
- Proxmox host networking changes
- vmbr additions and VLAN-aware interfaces
- FRR and BGP planning
- transit link validation
- rollout assistance while minimizing manual copy/paste overhead

## Documentation Rule

If a change requires a real operational secret, keep that secret local. Only document:
- the purpose of the integration
- the access model
- the operational safety rules
- the change tracking and validation process

Never document the actual token value, username password, or live connection strings in a tracked file.
