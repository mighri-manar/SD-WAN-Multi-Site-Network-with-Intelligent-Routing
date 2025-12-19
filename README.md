# 🌐 SD-WAN Multi-Site Network with Intelligent Routing

<div align="center">

![SD-WAN Banner](docs/images/banner.png)

**A Software-Defined Wide Area Network implementation with dynamic path selection, QoS, and automatic failover**

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.11+-green.svg)](https://www.python.org/)
[![Ryu](https://img.shields.io/badge/Ryu-4.34-orange.svg)](https://github.com/faucetsdn/ryu)
[![OpenFlow](https://img.shields.io/badge/OpenFlow-1.3-red.svg)](https://www.opennetworking.org/)

[Features](#-features) • [Demo](#-demo) • [Installation](#-installation) • [Usage](#-usage) • [Architecture](#-architecture) • [Testing](#-testing)

</div>

---

## 📸 Screenshots

<div align="center">

### Controller in Action
![Controller Running](docs/images/controller-running.png)
*Real-time monitoring with path quality metrics and anomaly detection*

### Network Topology
![Network Topology](docs/images/topology.png)
*HQ + 2 Branch Sites connected via GRE tunnels*

### Automated Testing
![Test Results](docs/images/test-results.png)
*Comprehensive automated test suite with 9+ test scenarios*

### Failover Demonstration
![Failover Demo](docs/images/failover-demo.png)
*Automatic path switching when link degradation is detected*

</div>

---

## 🎯 Project Overview

This project implements a **production-grade SD-WAN (Software-Defined Wide Area Network)** solution that enables intelligent traffic routing across multiple sites. Unlike traditional WANs with rigid routing, our SD-WAN controller dynamically selects the best path based on real-time network conditions.

### The Problem We Solve

Traditional multi-site networks suffer from:
- ❌ Static routing that can't adapt to network conditions
- ❌ No automatic failover when links degrade
- ❌ Lack of traffic prioritization (VoIP, critical apps)
- ❌ Manual configuration and maintenance overhead

### Our Solution

✅ **Dynamic Path Selection** - Routes automatically switch based on latency, packet loss, and bandwidth  
✅ **Automatic Failover** - Instant rerouting when links fail  
✅ **Quality of Service (QoS)** - Priority traffic gets preferred treatment  
✅ **Real-time Monitoring** - Continuous health checks with anomaly detection  
✅ **Complete Automation** - One-command deployment and testing  

---

## ✨ Features

### 🚀 Core Functionality

| Feature | Description | Status |
|---------|-------------|--------|
| **Dynamic Routing** | Path selection based on latency (<50ms), packet loss (<5%), and bandwidth | ✅ Implemented |
| **QoS/Traffic Prioritization** | VoIP (DSCP 46) gets priority 200, critical apps priority 150 | ✅ Implemented |
| **Automatic Failover** | Detects link degradation and triggers rerouting within 10-30 seconds | ✅ Implemented |
| **GRE Tunneling** | Automatic tunnel creation for overlay network | ✅ Implemented |
| **Real-time Monitoring** | Latency, packet loss, bandwidth measurement every 10 seconds | ✅ Implemented |
| **Anomaly Detection** | Historical analysis to detect unusual network behavior | ✅ Implemented |
| **Event Logging** | Complete audit trail of all network events | ✅ Implemented |

### 🎛️ Advanced Features

- **Path Quality Scoring**: Weighted algorithm (60% latency + 40% packet loss) for optimal path selection
- **Cooldown Periods**: Prevents route flapping with 30-second failover cooldown
- **Multi-Criteria Decision Making**: Considers multiple metrics before path switching
- **Flow Priority Management**: OpenFlow rules installed with traffic-dependent priorities
- **Comprehensive Statistics**: Flow stats, port stats, bandwidth measurements

### 🧪 Testing & Automation

- **9 Automated Test Scenarios**: Connectivity, latency, packet loss, bandwidth, QoS, tunnels, failover
- **5 Failover Test Cases**: Latency degradation, interface shutdown, packet loss, tunnel resilience, complete site isolation
- **One-Command Deployment**: `./setup.sh` - Full topology ready in 15 seconds
- **Helper Scripts**: Quick tests, monitoring, traffic generation, demos

---

## 🎬 Demo

### Video Walkthrough

[![SD-WAN Demo Video](docs/images/video-thumbnail.png)](docs/videos/demo.mp4)

*Click to watch: Complete demonstration of deployment, connectivity testing, QoS, and failover*

### Quick Demo GIFs

<div align="center">

#### Automatic Deployment
![Deployment](docs/gifs/deployment.gif)

#### Failover in Action
![Failover](docs/gifs/failover.gif)

#### QoS Traffic Prioritization
![QoS](docs/gifs/qos.gif)

</div>

---

## 🏗️ Architecture

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                  SD-WAN Controller (Ryu)                    │
│                  ┌──────────────────────┐                   │
│                  │  Control Plane       │                   │
│                  │  - Path Selection    │                   │
│                  │  - QoS Management    │                   │
│                  │  - Monitoring        │                   │
│                  │  - Failover Logic    │                   │
│                  └──────────────────────┘                   │
│                           │                                 │
│                    OpenFlow 1.3                             │
│                           │                                 │
└───────────────────────────┼─────────────────────────────────┘
                            │
              ┌─────────────┼─────────────┐
              │             │             │
        ┌─────▼────┐  ┌─────▼────┐  ┌────▼─────┐
        │  OVS-HQ  │  │ OVS-Site1│  │ OVS-Site2│
        │ (Switch) │  │ (Switch) │  │ (Switch) │
        └─────┬────┘  └─────┬────┘  └────┬─────┘
              │             │             │
      ┌───────┼─────────────┼─────────────┼───────┐
      │       │    GRE Tunnels (Overlay)  │       │
      │       │    192.168.100.0/24        │       │
      └───────┼─────────────┼─────────────┼───────┘
              │             │             │
        ┌─────▼────┐  ┌─────▼────┐  ┌────▼─────┐
        │    HQ    │  │  Site 1  │  │  Site 2  │
        │10.1.1.10 │  │10.2.1.10 │  │10.3.1.10 │
        └──────────┘  └──────────┘  └──────────┘
```

### Technology Stack

#### Control Plane
- **SDN Controller**: Ryu Framework (Python)
- **Protocol**: OpenFlow 1.3
- **Architecture**: Event-driven, modular

#### Data Plane
- **Switches**: Open vSwitch (OVS)
- **Tunneling**: GRE (Generic Routing Encapsulation)
- **Virtual Sites**: Linux Network Namespaces

#### Monitoring & Testing
- **Metrics**: ping (latency/loss), iperf3 (bandwidth)
- **Logging**: JSON metrics, text event logs
- **Automation**: Bash scripts

### Network Design

#### Overlay Network (Application Traffic)
- **HQ LAN**: 10.1.1.0/24
- **Site1 LAN**: 10.2.1.0/24
- **Site2 LAN**: 10.3.1.0/24

#### Underlay Network (Tunnel Endpoints)
- **HQ Tunnel IP**: 192.168.100.1/24
- **Site1 Tunnel IP**: 192.168.100.2/24
- **Site2 Tunnel IP**: 192.168.100.3/24

---

## 📦 Installation

### Prerequisites

#### System Requirements
- **OS**: Linux (Arch Linux recommended, Ubuntu also works)
- **RAM**: 2GB minimum, 4GB recommended
- **Disk**: 1GB free space
- **CPU**: 2 cores minimum

#### Required Software
- Python 3.11+
- Open vSwitch
- iproute2
- iperf3
- git

### Step 1: Install System Dependencies

#### For Arch Linux:
```bash
sudo pacman -Syu
sudo pacman -S python python-pip openvswitch iproute2 iputils iperf3 bc git
```

#### For Ubuntu/Debian:
```bash
sudo apt update
sudo apt install python3 python3-pip python3-venv openvswitch-switch \
                 iproute2 iputils-ping iperf3 bc git
```

### Step 2: Start Open vSwitch

```bash
sudo systemctl start openvswitch
sudo systemctl enable openvswitch

# Verify OVS is running
sudo ovs-vsctl show
```

### Step 3: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/sdwan-multisite.git
cd sdwan-multisite
```

### Step 4: Set Up Python Environment

```bash
# Create virtual environment
python3 -m venv ~/sdwan-venv
source ~/sdwan-venv/bin/activate

# Download and patch Ryu
wget https://github.com/faucetsdn/ryu/archive/refs/tags/v4.34.tar.gz
tar xzf v4.34.tar.gz

# Fix compatibility issues
sed -i 's|from eventlet.wsgi import ALREADY_HANDLED|ALREADY_HANDLED = object()|g' \
    ryu-4.34/ryu/app/wsgi.py

# Install dependencies
pip install tinyrpc msgpack 'eventlet<0.36.0' webob routes oslo.config netaddr

# Create wrapper script
cat > ryu-manager << 'EOF'
#!/bin/bash
export PYTHONPATH="$HOME/sdwan-multisite/ryu-4.34:$PYTHONPATH"
python3 -m ryu.cmd.manager "$@"
EOF

chmod +x ryu-manager

# Verify installation
./ryu-manager --version
```

### Step 5: Deploy Network Topology

```bash
# Make scripts executable
chmod +x setup.sh test_suite.sh fix_routing.sh

# Deploy topology
sudo ./setup.sh

# Fix routing
sudo ./fix_routing.sh
```

You should see:
```
✓ Cleanup complete
✓ Namespaces created: hq, site1, site2
✓ OVS bridges created
✓ Virtual interfaces created
✓ IP addresses configured
✓ GRE tunnels created
✓ Bridges connected to controller
✓ SETUP COMPLETE!
```

---

## 🚀 Usage

### Quick Start (3 Steps)

#### 1. Start the Controller (Terminal 1)

```bash
cd ~/sdwan-multisite
source ~/sdwan-venv/bin/activate
./ryu-manager --verbose controller.py
```

Wait for:
```
======================================================================
    ENHANCED SD-WAN CONTROLLER STARTED
    Features: QoS, Dynamic Routing, Failover, Monitoring
======================================================================
✓ Switch connected: DPID=...
✓ Switch connected: DPID=...
✓ Switch connected: DPID=...
🔄 Enhanced monitoring thread started
```

#### 2. Run Tests (Terminal 2)

```bash
cd ~/sdwan-multisite
./test_suite.sh
```

#### 3. Watch Real-time Monitoring (Terminal 3)

```bash
cd ~/sdwan-multisite
./monitor.sh
# Or watch live logs
tail -f /tmp/sdwan_events.log
```

### Available Scripts

| Script | Description | Usage |
|--------|-------------|-------|
| `setup.sh` | Deploy complete network topology | `sudo ./setup.sh` |
| `cleanup.sh` | Remove topology and cleanup | `sudo ./cleanup.sh` |
| `fix_routing.sh` | Fix inter-site routing | `sudo ./fix_routing.sh` |
| `test_suite.sh` | Run all 9 automated tests | `./test_suite.sh` |
| `test_failover.sh` | Enhanced failover testing | `./test_failover.sh` |
| `quick_test.sh` | Quick connectivity check | `./quick_test.sh` |
| `test_qos.sh` | Test traffic prioritization | `./test_qos.sh` |
| `monitor.sh` | Show network status | `./monitor.sh` |
| `generate_traffic.sh` | Run iperf3 bandwidth tests | `./generate_traffic.sh` |
| `simulate_failover.sh` | Simulate link degradation | `./simulate_failover.sh` |
| `demo.sh` | Complete guided demonstration | `./demo.sh` |

### Manual Testing Commands

#### Test Basic Connectivity
```bash
# HQ to Site1
sudo ip netns exec hq ping -c 5 10.2.1.10

# HQ to Site2
sudo ip netns exec hq ping -c 5 10.3.1.10

# Site1 to Site2
sudo ip netns exec site1 ping -c 5 10.3.1.10
```

#### Test QoS (High Priority Traffic)
```bash
# Send VoIP-marked packets (DSCP=46, ToS=184)
sudo ip netns exec hq ping -Q 184 -c 5 10.2.1.10

# Check controller logs for "⭐ HIGH PRIORITY flow"
```

#### Bandwidth Testing
```bash
# Start iperf3 server on Site1
sudo ip netns exec site1 iperf3 -s &

# Test from HQ
sudo ip netns exec hq iperf3 -c 10.2.1.10 -t 10

# Stop server
sudo pkill iperf3
```

#### Simulate Link Failure
```bash
# Shutdown Site1 interface
sudo ip netns exec site1 ip link set veth-s1 down

# Verify Site2 still works
sudo ip netns exec hq ping -c 3 10.3.1.10

# Restore interface
sudo ip netns exec site1 ip link set veth-s1 up
```

---

## 🧪 Testing

### Automated Test Suite

Our comprehensive test suite includes **9 different test scenarios**:

#### Test Coverage

| Test # | Test Name | What It Tests | Pass Criteria |
|--------|-----------|---------------|---------------|
| 1 | Connectivity | Basic reachability between all sites | All pings successful |
| 2 | Latency | Round-trip time measurements | <10ms baseline |
| 3 | Packet Loss | Loss rate on all paths | <1% loss |
| 4 | Bandwidth | Throughput using iperf3 | >100 Mbps |
| 5 | QoS | Traffic prioritization | High-priority flows get priority 200 |
| 6 | Tunnels | GRE tunnel verification | All tunnels operational |
| 7 | Controller | OpenFlow connections | All switches connected |
| 8 | Failover | Link degradation response | Automatic detection & logging |
| 9 | Monitoring | Data collection | Logs and metrics generated |

### Running Tests

#### Full Test Suite
```bash
./test_suite.sh
```

**Output Example:**
```
╔════════════════════════════════════════════════════════════════╗
║           SD-WAN AUTOMATED TEST SUITE                          ║
╚════════════════════════════════════════════════════════════════╝

[✓] TEST 1: CONNECTIVITY - All sites reachable
[✓] TEST 2: LATENCY - Average 0.5ms
[✓] TEST 3: PACKET LOSS - 0% on all paths
[✓] TEST 4: BANDWIDTH - 5.2 Gbps HQ→Site1
[✓] TEST 5: QoS - Priority traffic detected
[✓] TEST 6: TUNNELS - All GRE tunnels up
[✓] TEST 7: CONTROLLER - 3 switches connected
[✓] TEST 8: FAILOVER - Degradation detected
[✓] TEST 9: MONITORING - Data collected

All tests completed successfully!
Results: /tmp/sdwan_test_results/
```

#### Enhanced Failover Tests
```bash
./test_failover.sh
```

This runs **5 critical failover scenarios**:
1. **Latency-based failover** - 150ms artificial delay
2. **Interface shutdown** - Complete link failure
3. **Packet loss simulation** - 30% loss
4. **Tunnel resilience** - GRE tunnel verification
5. **Complete site isolation** - Full site failure

### Test Results

All test results are saved to `/tmp/sdwan_test_results/`:
- `test_report_TIMESTAMP.txt` - Full test report
- `latency_TIMESTAMP.txt` - Latency measurements
- `packet_loss_TIMESTAMP.txt` - Loss statistics
- `bandwidth_TIMESTAMP.txt` - Throughput results
- `SUMMARY.txt` - Test summary

---

## 📊 Monitoring & Metrics

### Real-Time Monitoring

The controller provides continuous monitoring with updates every 10 seconds:

```
======================================================================
📊 MONITORING CYCLE #1 - 04:17:36
======================================================================

--- Path Metrics & Quality ---
✓ OK HQ-to-Site1: 0.52ms, 0.0% loss
   Latency: 0.52ms | Loss: 0.0% | Quality: [██████████] 100/100

✓ OK HQ-to-Site2: 0.48ms, 0.0% loss
   Latency: 0.48ms | Loss: 0.0% | Quality: [██████████] 100/100

--- Network Status Summary ---
Connected Switches: 3
  DPID 217947464662091: 5 MACs, 12 flows, ~2.34 Mbps
  DPID 130592118632776: 3 MACs, 8 flows, ~1.82 Mbps
  DPID 275805290386244: 4 MACs, 10 flows, ~2.15 Mbps
======================================================================
```

### Status Indicators

| Symbol | Meaning | Threshold |
|--------|---------|-----------|
| ✓ OK | Path healthy | Latency <50ms, Loss <5% |
| ⚠️ HIGH | Degraded performance | Latency 50-100ms |
| 🔴 CRITICAL | Severe degradation | Latency >100ms |
| ❌ DOWN | Path unavailable | Loss 100% |
| ⭐ | High priority traffic | Priority ≥100 |
| 🚨 | Anomaly detected | Spike >2x average |

### Collected Metrics

#### Event Log (`/tmp/sdwan_events.log`)
```
[2025-12-19 04:17:25] SYSTEM: SD-WAN Controller Initialized
[2025-12-19 04:17:26] SWITCH: Switch 217947464662091 connected
[2025-12-19 04:17:36] QOS: High priority flow installed: 10.1.1.10->10.2.1.10
[2025-12-19 04:18:15] ANOMALY: HQ-to-Site1 latency spike: 152.3ms
[2025-12-19 04:18:15] FAILOVER: HQ-to-Site1 critical latency: 152.30ms
```

#### Metrics JSON (`/tmp/sdwan_metrics.json`)
```json
{
  "timestamp": "2025-12-19T04:20:30",
  "paths": {
    "HQ-to-Site1": {
      "latency": 0.52,
      "loss": 0.0,
      "quality": 99.7,
      "available": true
    },
    "HQ-to-Site2": {
      "latency": 0.48,
      "loss": 0.0,
      "quality": 99.8,
      "available": true
    }
  },
  "anomalies": {
    "HQ-to-Site1": 2
  },
  "bandwidth": {
    "217947464662091": {
      "bandwidth": 2.34
    }
  }
}
```

---

## 🎓 How It Works

### Path Selection Algorithm

The controller uses a weighted scoring system to determine the best path:

```python
def calculate_quality_score(latency, loss):
    if loss == 100:
        return 0  # Path down
    
    # Score components (0-100)
    latency_score = max(0, 100 - (latency / 2))  # 0ms=100, 200ms=0
    loss_score = 100 - (loss * 10)                # 0%=100, 10%=0
    
    # Weighted average: latency 60%, loss 40%
    quality = (latency_score * 0.6) + (loss_score * 0.4)
    
    return quality
```

**Example:**
- Path A: 10ms, 0% loss → Score: 97
- Path B: 50ms, 2% loss → Score: 74
- **Path A selected** (higher score)

### QoS Implementation

Traffic is classified and prioritized based on DSCP/ToS fields:

| Traffic Type | DSCP | ToS | OpenFlow Priority | Use Case |
|--------------|------|-----|-------------------|----------|
| VoIP | 46 (EF) | 184 | 200 | Voice calls |
| Critical Apps | - | >0 | 150 | SSH, HTTPS |
| Streaming | 34 (AF41) | 136 | 100 | Video |
| Best Effort | 0 | 0 | 1 | Normal traffic |

### Failover Process

1. **Detection** (10 seconds): Monitoring detects latency >50ms or loss >5%
2. **Evaluation** (1 second): Calculate quality scores for all paths
3. **Decision** (1 second): Select best alternative path
4. **Execution** (5 seconds): Install new OpenFlow rules
5. **Cooldown** (30 seconds): Prevent route flapping

Total failover time: **~15-20 seconds**

### Anomaly Detection

Historical analysis identifies unusual patterns:

```python
# Collect last 5 measurements
history = [0.5, 0.6, 0.5, 0.7, 152.3]  # ms

# Calculate average
avg = 0.58ms

# Detect spike
current = 152.3ms
if current > avg * 2 and current > 50:
    trigger_anomaly_alert()
```

---

## 🔧 Configuration

### Controller Configuration

Edit `controller.py` to adjust thresholds:

```python
# Path selection thresholds
self.LATENCY_THRESHOLD = 50      # ms - triggers warning
self.LOSS_THRESHOLD = 5          # % - triggers warning
self.LATENCY_CRITICAL = 100      # ms - triggers failover

# QoS configuration
self.VOIP_PORTS = [5060, 5061]   # SIP ports
self.HIGH_PRIORITY_PORTS = [22, 443]  # SSH, HTTPS

# Monitoring interval
monitoring_interval = 10  # seconds

# Failover cooldown
failover_cooldown = 30  # seconds
```

### Network Configuration

Edit `setup.sh` to change network parameters:

```bash
# Site IP addresses
HQ_IP="10.1.1.10/24"
SITE1_IP="10.2.1.10/24"
SITE2_IP="10.3.1.10/24"

# Tunnel endpoints
HQ_TUNNEL="192.168.100.1/24"
SITE1_TUNNEL="192.168.100.2/24"
SITE2_TUNNEL="192.168.100.3/24"

# Controller address
CONTROLLER="tcp:127.0.0.1:6633"
```

---

## 🐛 Troubleshooting

### Common Issues

#### Issue: Connectivity tests fail
```bash
# Check if namespaces exist
sudo ip netns list

# Check if interfaces are up
sudo ip netns exec hq ip link show
sudo ip netns exec site1 ip link show
sudo ip netns exec site2 ip link show

# Fix routing
sudo ./fix_routing.sh
```

#### Issue: Controller can't connect to switches
```bash
# Check if OVS is running
sudo systemctl status openvswitch

# Verify controller connections
sudo ovs-vsctl get-controller ovs-hq
sudo ovs-vsctl get-controller ovs-site1
sudo ovs-vsctl get-controller ovs-site2

# Reconnect
sudo ovs-vsctl set-controller ovs-hq tcp:127.0.0.1:6633
sudo ovs-vsctl set-controller ovs-site1 tcp:127.0.0.1:6633
sudo ovs-vsctl set-controller ovs-site2 tcp:127.0.0.1:6633
```

#### Issue: Ryu manager fails to start
```bash
# Check Python environment
source ~/sdwan-venv/bin/activate
which python3

# Verify Ryu installation
./ryu-manager --version

# Check for port conflicts
sudo netstat -tlnp | grep 6633
```

#### Issue: Tests show all paths DOWN
```bash
# This usually means routing is missing
sudo ./fix_routing.sh

# Verify routes
sudo ip netns exec hq ip route
sudo ip netns exec site1 ip route
sudo ip netns exec site2 ip route
```

### Debug Commands

```bash
# Show OVS bridge configuration
sudo ovs-vsctl show

# Show OpenFlow flows
sudo ovs-ofctl dump-flows ovs-hq -O OpenFlow13

# Show port statistics
sudo ovs-ofctl dump-ports ovs-hq -O OpenFlow13

# Check namespace connectivity
sudo ip netns exec hq ip addr
sudo ip netns exec hq ip route

# Monitor controller logs
tail -f /tmp/sdwan_events.log

# Check metrics
cat /tmp/sdwan_metrics.json | jq '.'
```

### Getting Help

- **Check Logs**: `/tmp/sdwan_events.log` for events, controller terminal for verbose output
- **Run Diagnostics**: `./monitor.sh` shows complete network status
- **Test Step-by-Step**: Use `quick_test.sh` for rapid connectivity verification
- **Clean Restart**: `sudo ./cleanup.sh && sudo ./setup.sh && sudo ./fix_routing.sh`

---

## 📚 Project Structure

```
sdwan-multisite/
├── controller.py              # Enhanced SD-WAN controller
├── setup.sh                   # Network topology deployment
├── cleanup.sh                 # Topology removal
├── fix_routing.sh             # Inter-site routing fix
├── test_suite.sh              # Automated test suite (9 tests)
├── test_failover.sh           # Enhanced failover tests (5 scenarios)
├── quick_test.sh              # Quick connectivity test
├── test_qos.sh                # QoS testing
├── monitor.sh                 # Network status monitoring
├── generate_traffic.sh        # iperf3 traffic generation
├── simulate_failover.sh       # Failover simulation
├── demo.sh                    # Complete demonstration
├── ryu-manager                # Ryu wrapper script
├── ryu-4.34/                  # Ryu framework source
├── README.md                  # This file
├── LICENSE                    # MIT License
└── docs/
    ├── images/                # Screenshots
    │   ├── banner.png
    │   ├── controller-running.png
    │   ├── topology.png
    │   ├── test-results.png
    │   └── failover-demo.png
    ├── videos/                # Demo videos
    │   └── demo.mp4
    └── gifs/                  # Animated demonstrations
        ├── deployment.gif
        ├── failover.gif
        └── qos.gif
```

---

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

### Reporting Issues

Found a bug? [Open an issue](https://github.com/YOUR_USERNAME/sdwan-multisite/issues) with:
- Description of the problem
- Steps to reproduce
- Expected vs actual behavior
- System information (OS, Python version)
- Relevant logs

### Suggesting Features

Have an idea? [Open a feature request](https://github.com/YOUR_USERNAME/sdwan-multisite/issues) describing:
- The feature and its use case
- How it would improve the project
- Any implementation ideas

### Pull Requests

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Test thoroughly
5. Commit with clear messages (`git commit -m 'Add amazing feature'`)
6. Push to your fork (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Development Guidelines

- Follow PEP 8 for Python code
- Add tests for new features
- Update documentation
- Keep commits atomic and well-described

---

## 📖 Documentation

### Additional Resources

- [OpenFlow 1.3 Specification](https://www.opennetworking.org/wp-content/uploads/2014/10/openflow-spec-v1.3.0.pdf)
- [Ryu SDN Framework](https://ryu-sdn.org/)
- [Open vSwitch Documentation](https://docs.openvswitch.org/)
- [SD-WAN Concepts](https://www.cisco.com/c/en/us/solutions/enterprise-networks/sd-wan/what-is-sd-wan.html)

### Academic References

This project implements concepts from:
- Software-Defined Networking (SDN)
- Wide Area Network (WAN) optimization
- Traffic Engineering
- Quality of Service (QoS)
- Network Function Virtualization (NFV)

### Related Papers

- [B4: Experience with a Globally-Deployed Software Defined WAN](https://cseweb.ucsd.edu/~vahdat/papers/b4-sigcomm13.pdf) - Google's SD-WAN
- [OpenFlow: Enabling Innovation in Campus Networks](https://www.opennetworking.org/wp-content/uploads/2011/09/openflow-wp-latest.pdf)

---

## 🎓 Learning Outcomes

By working with this project, you will learn:

### Technical Skills
- ✅ SDN controller programming with Ryu
- ✅ OpenFlow protocol and flow management
- ✅ Network virtualization with Linux namespaces
- ✅ GRE tunneling and overlay networks
- ✅ Traffic engineering and QoS
- ✅ Python network programming
- ✅ Bash scripting and automation

### Concepts Mastered
- ✅ Software-Defined Networking architecture
- ✅ Control plane vs data plane separation
- ✅ Dynamic routing algorithms
- ✅ Path selection and optimization
- ✅ Network monitoring and telemetry
- ✅ Failover and resilience mechanisms

---

## 🏆 Achievements

- ✅ **Complete SD-WAN Implementation**:
- ✅ Production-Grade Features: QoS, failover, monitoring, anomaly detection
- ✅ Comprehensive Testing: 14+ automated test scenarios
- ✅ Full Automation: One-command deployment and testing
- ✅ Professional Documentation: Complete guides and examples
- ✅ Open Source: MIT licensed, freely available

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

<div align="center">

**⭐ Star this repo if you found it helpful!**

**🔀 Fork it to build your own SD-WAN!**

Made with ❤️ and ☕ by Manar

</div>







