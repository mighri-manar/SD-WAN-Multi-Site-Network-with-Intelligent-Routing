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
