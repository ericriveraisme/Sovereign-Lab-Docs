# 👻 Ghost User (Enterprise Sandbox VM)
**Last Updated:** 2026-03-13
**Role:** Simulated Enterprise Client Endpoint

## Node Specifications
* **Hypervisor:** Proxmox VE
* **Architecture:** Virtual Machine (Windows/Linux Desktop Environment)
* **Network Placement:** LAN / VLAN 10 (`10.0.10.0/24`)

## Purpose
The Ghost User acts as our "Crash Test Dummy." Instead of testing network lockdown policies, firewall rules, or DNS blacklists on `Bahamut` or `Tiamat` (and risking locking ourselves out of the management plane), all disruptive enterprise testing is executed against this node.

## Current Issues & Active Engineering
* **Enterprise Simulation Setup:** We are currently shaping this VM to mimic a restricted corporate user. 
* **Pending Configurations:** 1. Forcing all outbound web traffic through a specific gateway/proxy.
  2. Testing DNS sinkhole effectiveness (ensuring the user cannot bypass the internal DNS server).
  3. Validating that inter-VLAN routing drops traffic if this user attempts to access the `sovereign-ops` management IP (`100.122.30.25`).