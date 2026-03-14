# 🗺️ Technitium DNS: Service Configuration

## ⚙️ Core Settings

- **IP Address:** `10.0.10.53`
    
- **Management UI:** `http://10.0.10.53:5380`
    
- **VLAN Tag:** `10` (Enforced in Proxmox GUI)
    

## 📡 Listener Bindings

To ensure visibility across the Management VLAN, the DNS server is configured to listen on all interfaces (`0.0.0.0:53`).

**Troubleshooting Note:** If `nslookup` fails despite a valid ping, verify service binding using `ss -tulpn | grep :53`. If the service is only bound to `127.0.0.1`, internal network queries will time out.

## 📝 Zone Records (Authoritative)

- **Zone:** `sovereign.lab`
    
- **A-Record:** `dns.sovereign.lab` -> `10.0.10.53`
    
- **A-Record:** `router.sovereign.lab` -> `10.0.10.1`