#!/bin/bash
echo "=== Simulating Network Degradation ==="
echo ""

# Allow user to choose site
echo "Select site to degrade:"
echo "1) Site1 (10.2.1.10)"
echo "2) Site2 (10.3.1.10)"
echo "3) Site3 (10.4.1.10)"
read -p "Choice [1-3]: " choice

case $choice in
    1)
        SITE="site1"
        IP="10.2.1.10"
        DEV="veth-s1"
        ;;
    2)
        SITE="site2"
        IP="10.3.1.10"
        DEV="veth-s2"
        ;;
    3)
        SITE="site3"
        IP="10.4.1.10"
        DEV="veth-s3"
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo "Adding 150ms latency to $SITE path..."
sudo ip netns exec $SITE tc qdisc add dev $DEV root netem delay 150ms
echo "✓ Latency added to $SITE"

echo ""
echo "Testing latency (should be ~150ms higher)..."
sudo ip netns exec hq ping -c 5 $IP

echo ""
echo "Waiting 20 seconds for controller to detect and react..."
sleep 20

echo ""
echo "Removing latency..."
sudo ip netns exec $SITE tc qdisc del dev $DEV root
echo "✓ Latency removed from $SITE"

echo ""
echo "Testing latency (should return to normal)..."
sudo ip netns exec hq ping -c 5 $IP

echo ""
echo "✓ Failover simulation complete! Check controller logs."
