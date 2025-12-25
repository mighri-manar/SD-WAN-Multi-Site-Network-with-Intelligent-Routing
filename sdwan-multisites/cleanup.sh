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
