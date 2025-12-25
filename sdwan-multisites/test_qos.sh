#!/bin/bash
echo "=== QoS Testing (Traffic Prioritization) ==="
echo ""

for site_num in 1 2 3; do
    site_ip="10.$((site_num + 1)).1.10"
    echo "Testing Site${site_num} (${site_ip})..."
    echo ""
    
    echo "  Sending HIGH PRIORITY traffic (ToS=184, DSCP=46 - VoIP)..."
    sudo ip netns exec hq ping -Q 184 -c 3 $site_ip
    echo ""
    
    echo "  Sending NORMAL PRIORITY traffic..."
    sudo ip netns exec hq ping -c 3 $site_ip
    echo ""
done

echo "✓ QoS test complete! Check controller logs for priority indicators (⭐)"
