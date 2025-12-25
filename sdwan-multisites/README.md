# SD-WAN Multi-Site Network Setup

## Architecture (HQ + 3 Sites)

```
┌─────────────────────────────────────────────────────────────────┐
│                     SD-WAN Controller (Ryu)                     │
│                     OpenFlow 1.3 @ tcp:6633                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┼─────────┬─────────┐
                    │         │         │         │
              ┌─────▼───┐ ┌──▼────┐ ┌──▼────┐ ┌──▼────┐
              │  OVS-HQ │ │ OVS-S1│ │ OVS-S2│ │ OVS-S3│
              └─────┬───┘ └───┬───┘ └───┬───┘ └───┬───┘
                    │         │         │         │
            ┌───────┼─────────┼─────────┼─────────┼───────┐
            │       GRE Tunnels (Overlay Network)         │
            │       192.168.100.0/24                       │
            └─────────────────────────────────────────────┘
                    │         │         │         │
              ┌─────▼───┐ ┌──▼────┐ ┌──▼────┐ ┌──▼────┐
              │   HQ    │ │ Site1 │ │ Site2 │ │ Site3 │
              │10.1.1.10│ │10.2.1.│ │10.3.1.│ │10.4.1.│
              └─────────┘ └───────┘ └───────┘ └───────┘
```

## Quick Start

### 1. Start Controller
```bash
source ~/sdwan-venv/bin/activate
./ryu-manager --verbose controller.py
```

### 2. Test Connectivity
```bash
./quick_test.sh
```

## Network Information

- **HQ**: 10.1.1.10/24 (Tunnel: 192.168.100.1)
- **Site1**: 10.2.1.10/24 (Tunnel: 192.168.100.2)
- **Site2**: 10.3.1.10/24 (Tunnel: 192.168.100.3)
- **Site3**: 10.4.1.10/24 (Tunnel: 192.168.100.4)

## Available Scripts

- `setup.sh` - Deploy topology
- `cleanup.sh` - Remove topology
- `fix_routing.sh` - Fix routing
- `quick_test.sh` - Test connectivity
- `monitor.sh` - Show status
- `generate_traffic.sh` - Generate traffic
- `test_qos.sh` - Test QoS
