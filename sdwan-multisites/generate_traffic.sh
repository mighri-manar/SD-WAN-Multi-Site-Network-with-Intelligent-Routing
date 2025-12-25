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
