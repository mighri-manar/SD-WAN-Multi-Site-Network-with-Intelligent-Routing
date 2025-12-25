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
