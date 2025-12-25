#!/bin/bash

set -e

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     ENHANCED SD-WAN MULTI-SITE SETUP                           ║"
echo "║     HQ + 3 Branch Sites with GRE Tunnels                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# =============================================================================
# CLEANUP OLD CONFIGURATION
# =============================================================================

echo "[1/10] Cleaning up old configuration..."
sudo ip netns del hq 2>/dev/null || true
sudo ip netns del site1 2>/dev/null || true
sudo ip netns del site2 2>/dev/null || true
sudo ip netns del site3 2>/dev/null || true
sudo ovs-vsctl --if-exists del-br ovs-hq
sudo ovs-vsctl --if-exists del-br ovs-site1
sudo ovs-vsctl --if-exists del-br ovs-site2
sudo ovs-vsctl --if-exists del-br ovs-site3
sudo ip link del hq-local 2>/dev/null || true
sudo ip link del s1-local 2>/dev/null || true
sudo ip link del s2-local 2>/dev/null || true
sudo ip link del s3-local 2>/dev/null || true
pkill -f ryu-manager 2>/dev/null || true
pkill -f iperf3 2>/dev/null || true
echo "✓ Cleanup complete"

# =============================================================================
# CREATE NETWORK NAMESPACES (VIRTUAL SITES)
# =============================================================================

echo "[2/10] Creating network namespaces (virtual sites)..."
sudo ip netns add hq
sudo ip netns add site1
sudo ip netns add site2
sudo ip netns add site3
echo "✓ Namespaces created: hq, site1, site2, site3"

# =============================================================================
# CREATE OVS BRIDGES
# =============================================================================

echo "[3/10] Creating OVS bridges..."
sudo ovs-vsctl add-br ovs-hq
sudo ovs-vsctl add-br ovs-site1
sudo ovs-vsctl add-br ovs-site2
sudo ovs-vsctl add-br ovs-site3

# Configure OpenFlow 1.3
sudo ovs-vsctl set bridge ovs-hq protocols=OpenFlow13
sudo ovs-vsctl set bridge ovs-site1 protocols=OpenFlow13
sudo ovs-vsctl set bridge ovs-site2 protocols=OpenFlow13
sudo ovs-vsctl set bridge ovs-site3 protocols=OpenFlow13

# Set fail mode to secure (only controller can manage)
sudo ovs-vsctl set-fail-mode ovs-hq secure
sudo ovs-vsctl set-fail-mode ovs-site1 secure
sudo ovs-vsctl set-fail-mode ovs-site2 secure
sudo ovs-vsctl set-fail-mode ovs-site3 secure

echo "✓ OVS bridges created with OpenFlow 1.3"

# =============================================================================
# CREATE VETH PAIRS (VIRTUAL NETWORK INTERFACES)
# =============================================================================

echo "[4/10] Creating virtual network interfaces..."

# HQ
sudo ip link add veth-hq type veth peer name veth-hq-br
sudo ip link set veth-hq netns hq
sudo ip link set veth-hq-br up
sudo ovs-vsctl add-port ovs-hq veth-hq-br

# Site1
sudo ip link add veth-s1 type veth peer name veth-s1-br
sudo ip link set veth-s1 netns site1
sudo ip link set veth-s1-br up
sudo ovs-vsctl add-port ovs-site1 veth-s1-br

# Site2
sudo ip link add veth-s2 type veth peer name veth-s2-br
sudo ip link set veth-s2 netns site2
sudo ip link set veth-s2-br up
sudo ovs-vsctl add-port ovs-site2 veth-s2-br

# Site3
sudo ip link add veth-s3 type veth peer name veth-s3-br
sudo ip link set veth-s3 netns site3
sudo ip link set veth-s3-br up
sudo ovs-vsctl add-port ovs-site3 veth-s3-br

echo "✓ Virtual interfaces created"

# =============================================================================
# CONFIGURE IP ADDRESSES
# =============================================================================

echo "[5/10] Configuring IP addresses..."

# HQ: 10.1.1.10/24
sudo ip netns exec hq ip addr add 10.1.1.10/24 dev veth-hq
sudo ip netns exec hq ip link set veth-hq up
sudo ip netns exec hq ip link set lo up

# Site1: 10.2.1.10/24
sudo ip netns exec site1 ip addr add 10.2.1.10/24 dev veth-s1
sudo ip netns exec site1 ip link set veth-s1 up
sudo ip netns exec site1 ip link set lo up

# Site2: 10.3.1.10/24
sudo ip netns exec site2 ip addr add 10.3.1.10/24 dev veth-s2
sudo ip netns exec site2 ip link set veth-s2 up
sudo ip netns exec site2 ip link set lo up

# Site3: 10.4.1.10/24
sudo ip netns exec site3 ip addr add 10.4.1.10/24 dev veth-s3
sudo ip netns exec site3 ip link set veth-s3 up
sudo ip netns exec site3 ip link set lo up

echo "✓ IP addresses configured"

# =============================================================================
# CREATE GRE TUNNELS (OVERLAY NETWORK)
# =============================================================================

echo "[6/10] Creating GRE tunnels (overlay network)..."

# Create internal interfaces for tunnel endpoints
sudo ovs-vsctl add-port ovs-hq hq-local -- set interface hq-local type=internal
sudo ovs-vsctl add-port ovs-site1 s1-local -- set interface s1-local type=internal
sudo ovs-vsctl add-port ovs-site2 s2-local -- set interface s2-local type=internal
sudo ovs-vsctl add-port ovs-site3 s3-local -- set interface s3-local type=internal

# Configure tunnel endpoint IPs (underlay network)
sudo ip addr add 192.168.100.1/24 dev hq-local
sudo ip link set hq-local up

sudo ip addr add 192.168.100.2/24 dev s1-local
sudo ip link set s1-local up

sudo ip addr add 192.168.100.3/24 dev s2-local
sudo ip link set s2-local up

sudo ip addr add 192.168.100.4/24 dev s3-local
sudo ip link set s3-local up

# Create GRE tunnels
# HQ to Site1
sudo ovs-vsctl add-port ovs-hq gre-hq-s1 -- set interface gre-hq-s1 \
    type=gre options:remote_ip=192.168.100.2 options:local_ip=192.168.100.1

# HQ to Site2
sudo ovs-vsctl add-port ovs-hq gre-hq-s2 -- set interface gre-hq-s2 \
    type=gre options:remote_ip=192.168.100.3 options:local_ip=192.168.100.1

# HQ to Site3
sudo ovs-vsctl add-port ovs-hq gre-hq-s3 -- set interface gre-hq-s3 \
    type=gre options:remote_ip=192.168.100.4 options:local_ip=192.168.100.1

# Site1 to HQ
sudo ovs-vsctl add-port ovs-site1 gre-s1-hq -- set interface gre-s1-hq \
    type=gre options:remote_ip=192.168.100.1 options:local_ip=192.168.100.2

# Site2 to HQ
sudo ovs-vsctl add-port ovs-site2 gre-s2-hq -- set interface gre-s2-hq \
    type=gre options:remote_ip=192.168.100.1 options:local_ip=192.168.100.3

# Site3 to HQ
sudo ovs-vsctl add-port ovs-site3 gre-s3-hq -- set interface gre-s3-hq \
    type=gre options:remote_ip=192.168.100.1 options:local_ip=192.168.100.4

echo "✓ GRE tunnels created"

# =============================================================================
# CONNECT TO CONTROLLER
# =============================================================================

echo "[7/10] Configuring controller connections..."
sudo ovs-vsctl set-controller ovs-hq tcp:127.0.0.1:6633
sudo ovs-vsctl set-controller ovs-site1 tcp:127.0.0.1:6633
sudo ovs-vsctl set-controller ovs-site2 tcp:127.0.0.1:6633
sudo ovs-vsctl set-controller ovs-site3 tcp:127.0.0.1:6633
echo "✓ Bridges connected to controller (tcp:127.0.0.1:6633)"

# =============================================================================
# ENABLE TRAFFIC CONTROL (FOR FAILOVER TESTING)
# =============================================================================

echo "[8/10] Setting up traffic control capabilities..."

# Ensure tc (traffic control) is available in namespaces
sudo ip netns exec hq which tc > /dev/null 2>&1 || echo "Warning: tc not available in namespaces"
sudo ip netns exec site1 which tc > /dev/null 2>&1 || echo "Warning: tc not available in namespaces"
sudo ip netns exec site2 which tc > /dev/null 2>&1 || echo "Warning: tc not available in namespaces"
sudo ip netns exec site3 which tc > /dev/null 2>&1 || echo "Warning: tc not available in namespaces"

echo "✓ Traffic control ready"

# =============================================================================
# CREATE HELPER SCRIPTS
# =============================================================================

echo "[9/10] Creating helper scripts..."

# Cleanup script
cat > cleanup.sh << 'EOF'
#!/bin/bash
echo "Cleaning up SD-WAN topology..."
sudo ip netns del hq 2>/dev/null || true
sudo ip netns del site1 2>/dev/null || true
sudo ip netns del site2 2>/dev/null || true
sudo ip netns del site3 2>/dev/null || true
sudo ovs-vsctl --if-exists del-br ovs-hq
sudo ovs-vsctl --if-exists del-br ovs-site1
sudo ovs-vsctl --if-exists del-br ovs-site2
sudo ovs-vsctl --if-exists del-br ovs-site3
sudo ip link del hq-local 2>/dev/null || true
sudo ip link del s1-local 2>/dev/null || true
sudo ip link del s2-local 2>/dev/null || true
sudo ip link del s3-local 2>/dev/null || true
pkill -f ryu-manager 2>/dev/null || true
pkill -f iperf3 2>/dev/null || true
echo "✓ Cleanup complete!"
EOF

chmod +x cleanup.sh

# Routing fix script
cat > fix_routing.sh << 'EOF'
#!/bin/bash
echo "Fixing routing for SD-WAN topology..."

# Add routes in HQ to reach sites through the bridge
sudo ip netns exec hq ip route add 10.2.1.0/24 dev veth-hq 2>/dev/null || true
sudo ip netns exec hq ip route add 10.3.1.0/24 dev veth-hq 2>/dev/null || true
sudo ip netns exec hq ip route add 10.4.1.0/24 dev veth-hq 2>/dev/null || true

# Add routes in Site1
sudo ip netns exec site1 ip route add 10.1.1.0/24 dev veth-s1 2>/dev/null || true
sudo ip netns exec site1 ip route add 10.3.1.0/24 dev veth-s1 2>/dev/null || true
sudo ip netns exec site1 ip route add 10.4.1.0/24 dev veth-s1 2>/dev/null || true

# Add routes in Site2
sudo ip netns exec site2 ip route add 10.1.1.0/24 dev veth-s2 2>/dev/null || true
sudo ip netns exec site2 ip route add 10.2.1.0/24 dev veth-s2 2>/dev/null || true
sudo ip netns exec site2 ip route add 10.4.1.0/24 dev veth-s2 2>/dev/null || true

# Add routes in Site3
sudo ip netns exec site3 ip route add 10.1.1.0/24 dev veth-s3 2>/dev/null || true
sudo ip netns exec site3 ip route add 10.2.1.0/24 dev veth-s3 2>/dev/null || true
sudo ip netns exec site3 ip route add 10.3.1.0/24 dev veth-s3 2>/dev/null || true

echo "✓ Routes added"

# Test connectivity
echo ""
echo "Testing connectivity..."
sudo ip netns exec hq ping -c 2 10.2.1.10 && echo "✓ HQ → Site1 OK" || echo "✗ HQ → Site1 FAILED"
sudo ip netns exec hq ping -c 2 10.3.1.10 && echo "✓ HQ → Site2 OK" || echo "✗ HQ → Site2 FAILED"
sudo ip netns exec hq ping -c 2 10.4.1.10 && echo "✓ HQ → Site3 OK" || echo "✗ HQ → Site3 FAILED"
EOF

chmod +x fix_routing.sh

# Quick test script
cat > quick_test.sh << 'EOF'
#!/bin/bash
echo "=== Quick Connectivity Test ==="
echo ""
echo "Testing HQ → Site1 (10.2.1.10)..."
sudo ip netns exec hq ping -c 3 10.2.1.10
echo ""
echo "Testing HQ → Site2 (10.3.1.10)..."
sudo ip netns exec hq ping -c 3 10.3.1.10
echo ""
echo "Testing HQ → Site3 (10.4.1.10)..."
sudo ip netns exec hq ping -c 3 10.4.1.10
echo ""
echo "✓ Quick test complete!"
EOF

chmod +x quick_test.sh

# Monitoring script
cat > monitor.sh << 'EOF'
#!/bin/bash
echo "=== SD-WAN Network Status ==="
echo ""
echo "Network Namespaces:"
sudo ip netns list
echo ""
echo "OVS Bridges:"
sudo ovs-vsctl list-br
echo ""
echo "HQ Bridge Ports:"
sudo ovs-vsctl list-ports ovs-hq
echo ""
echo "Site1 Bridge Ports:"
sudo ovs-vsctl list-ports ovs-site1
echo ""
echo "Site2 Bridge Ports:"
sudo ovs-vsctl list-ports ovs-site2
echo ""
echo "Site3 Bridge Ports:"
sudo ovs-vsctl list-ports ovs-site3
echo ""
echo "Controller Connections:"
for br in ovs-hq ovs-site1 ovs-site2 ovs-site3; do
    echo "  $br: $(sudo ovs-vsctl get-controller $br)"
done
echo ""
echo "OpenFlow Flows (HQ):"
sudo ovs-ofctl dump-flows ovs-hq -O OpenFlow13 | head -5
echo ""
EOF

chmod +x monitor.sh

# Traffic generation script
cat > generate_traffic.sh << 'EOF'
#!/bin/bash
echo "=== Traffic Generation Script ==="
echo ""

# Start iperf3 servers
echo "Starting iperf3 servers on sites..."
sudo ip netns exec site1 iperf3 -s -D
sudo ip netns exec site2 iperf3 -s -D
sudo ip netns exec site3 iperf3 -s -D
sleep 2

echo ""
echo "Generating traffic HQ → Site1..."
sudo ip netns exec hq iperf3 -c 10.2.1.10 -t 10 -i 1

echo ""
echo "Generating traffic HQ → Site2..."
sudo ip netns exec hq iperf3 -c 10.3.1.10 -t 10 -i 1

echo ""
echo "Generating traffic HQ → Site3..."
sudo ip netns exec hq iperf3 -c 10.4.1.10 -t 10 -i 1

# Cleanup
sudo pkill iperf3
echo ""
echo "✓ Traffic generation complete!"
EOF

chmod +x generate_traffic.sh

# QoS test script
cat > test_qos.sh << 'EOF'
#!/bin/bash
echo "=== QoS Testing (Traffic Prioritization) ==="
echo ""

echo "Sending HIGH PRIORITY traffic (ToS=184, DSCP=46 - VoIP simulation)..."
sudo ip netns exec hq ping -Q 184 -c 5 10.2.1.10
echo ""

echo "Sending NORMAL PRIORITY traffic..."
sudo ip netns exec hq ping -c 5 10.2.1.10
echo ""

echo "✓ QoS test complete! Check controller logs for priority indicators (⭐)"
EOF

chmod +x test_qos.sh

echo "✓ Helper scripts created:"
echo "  - cleanup.sh (cleanup topology)"
echo "  - fix_routing.sh (fix inter-site routing)"
echo "  - quick_test.sh (quick connectivity test)"
echo "  - monitor.sh (show network status)"
echo "  - generate_traffic.sh (iperf3 traffic generation)"
echo "  - test_qos.sh (test traffic prioritization)"

# =============================================================================
# CREATE DOCUMENTATION
# =============================================================================

echo "[10/10] Creating documentation..."

cat > README.md << 'EOF'
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
EOF

echo "✓ Documentation created (README.md)"

# =============================================================================
# FINAL STATUS
# =============================================================================

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SETUP COMPLETE!                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Network Topology:"
echo "  HQ:     10.1.1.10/24 (namespace: hq)"
echo "  Site1:  10.2.1.10/24 (namespace: site1)"
echo "  Site2:  10.3.1.10/24 (namespace: site2)"
echo "  Site3:  10.4.1.10/24 (namespace: site3)"
echo ""
echo "Tunnel Endpoints (Underlay):"
echo "  HQ:     192.168.100.1/24"
echo "  Site1:  192.168.100.2/24"
echo "  Site2:  192.168.100.3/24"
echo "  Site3:  192.168.100.4/24"
echo ""
echo "Next Steps:"
echo "  1. Fix routing:"
echo "     sudo ./fix_routing.sh"
echo ""
echo "  2. Start controller:"
echo "     source ~/sdwan-venv/bin/activate"
echo "     ./ryu-manager --verbose controller.py"
echo ""
echo "  3. Test connectivity:"
echo "     ./quick_test.sh"
echo ""
echo "╚════════════════════════════════════════════════════════════════╝"
