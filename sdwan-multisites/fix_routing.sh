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
