**Core Subnet:** `10.0.10.0/24` (VLAN 10)

- **Gateway:** `10.0.10.1` (Core-Router LXC 100)
    
- **Usable Range:** `10.0.10.2` - `10.0.10.254`
    
- **Math Check:** $2^h - 2 = 2^8 - 2 = 254$ usable hosts.
- **VLANS:**  10 (Management), 20 (Hosts)