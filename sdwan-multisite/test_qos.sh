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
