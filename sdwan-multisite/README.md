# SD-WAN Multi-Site Network Setup

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     SD-WAN Controller (Ryu)                     │
│                     OpenFlow 1.3 @ tcp:6633                     │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
              ┌─────▼───┐ ┌──▼────┐ ┌──▼────┐
              │  OVS-HQ │ │ OVS-S1│ │ OVS-S2│
              └─────┬───┘ └───┬───┘ └───┬───┘
                    │         │         │
            ┌───────┼─────────┼─────────┼───────┐
            │    GRE Tunnels (Overlay Network)  │
            │    192.168.100.0/24                │
            └───────────────────────────────────┘
                    │         │         │
              ┌─────▼───┐ ┌──▼────┐ ┌──▼────┐
              │   HQ    │ │ Site1 │ │ Site2 │
              │10.1.1.10│ │10.2.1.│ │10.3.1.│
              └─────────┘ └───────┘ └───────┘
```

## Features Implemented

✅ Multi-site SD-WAN (HQ + 2 sites)
✅ GRE tunnels (overlay network)
✅ SDN controller (Ryu with OpenFlow 1.3)
✅ Dynamic routing based on latency & packet loss
✅ QoS / Traffic prioritization (VoIP, critical apps)
✅ Real-time monitoring (latency, loss, bandwidth)
✅ Automatic failover on path degradation
✅ Anomaly detection
✅ Automated testing suite

## Quick Start

### 1. Start Controller
```bash
source ~/sdwan-venv/bin/activate
ryu-manager --verbose controller.py
```

### 2. Run Tests
```bash
chmod +x test_suite.sh
./test_suite.sh
```

### 3. Demo
```bash
./demo.sh
```

## Helper Scripts

- `quick_test.sh` - Quick connectivity verification
- `monitor.sh` - Show network status
- `generate_traffic.sh` - Bandwidth testing with iperf3
- `simulate_failover.sh` - Test automatic path switching
- `test_qos.sh` - Test traffic prioritization
- `demo.sh` - Full demonstration
- `cleanup.sh` - Clean up topology

## Testing Scenarios

### Scenario 1: Normal Operation
```bash
./quick_test.sh
```
Expected: All pings succeed with low latency (<10ms)

### Scenario 2: Traffic Generation
```bash
./generate_traffic.sh
```
Expected: Bandwidth measurements for both paths

### Scenario 3: High Priority Traffic
```bash
./test_qos.sh
```
Expected: Controller logs show "⭐ HIGH PRIORITY flow"

### Scenario 4: Path Degradation & Failover
```bash
./simulate_failover.sh
```
Expected: 
- Latency increases to ~150ms
- Controller detects degradation
- Automatic path consideration
- Recovery after latency removal

## Monitoring

Controller logs show:
- ✓ Green: OK
- ⚠️  Yellow: Warning (high latency/loss)
- ❌ Red: Critical (path down)
- ⭐ Star: High priority traffic
- 🚨 Alert: Anomaly detected

## Files Generated

- `/tmp/sdwan_events.log` - Event log
- `/tmp/sdwan_metrics.json` - Metrics data
- `/tmp/sdwan_test_results/` - Test results

## Troubleshooting

**Controller won't start:**
```bash
source ~/sdwan-venv/bin/activate
pip install git+https://github.com/faucetsdn/ryu.git
```

**Connectivity fails:**
```bash
./cleanup.sh
sudo ./setup.sh
```

**Check OVS status:**
```bash
./monitor.sh
```
