#!/bin/bash
echo "=== Simulating Network Degradation ==="
echo ""

echo "Adding 150ms latency to Site1 path..."
sudo ip netns exec site1 tc qdisc add dev veth-s1 root netem delay 150ms
echo "✓ Latency added"

echo ""
echo "Testing latency (should be ~150ms higher)..."
sudo ip netns exec hq ping -c 5 10.2.1.10

echo ""
echo "Waiting 20 seconds for controller to detect and react..."
sleep 20

echo ""
echo "Removing latency..."
sudo ip netns exec site1 tc qdisc del dev veth-s1 root
echo "✓ Latency removed"

echo ""
echo "Testing latency (should return to normal)..."
sudo ip netns exec hq ping -c 5 10.2.1.10

echo ""
echo "✓ Failover simulation complete! Check controller logs."
