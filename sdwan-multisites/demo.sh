#!/bin/bash
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           SD-WAN DEMONSTRATION SCRIPT                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

echo "This script will demonstrate:"
echo "  1. Basic connectivity (HQ + 3 Sites)"
echo "  2. Traffic generation (bandwidth test)"
echo "  3. QoS (priority traffic)"
echo "  4. Failover simulation"
echo ""

read -p "Press Enter to start demonstration..."

echo ""
echo "=== STEP 1: Basic Connectivity ==="
./quick_test.sh

echo ""
read -p "Press Enter to continue to bandwidth testing..."

echo ""
echo "=== STEP 2: Bandwidth Testing ==="
./generate_traffic.sh

echo ""
read -p "Press Enter to continue to QoS testing..."

echo ""
echo "=== STEP 3: QoS / Traffic Prioritization ==="
./test_qos.sh

echo ""
read -p "Press Enter to continue to failover simulation..."

echo ""
echo "=== STEP 4: Failover Simulation ==="
./simulate_failover.sh

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║           DEMONSTRATION COMPLETE                               ║"
echo "║  Review controller logs for detailed information               ║"
echo "╚════════════════════════════════════════════════════════════════╝"
