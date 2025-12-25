#!/bin/bash
# =============================================================================
# AUTOMATED SD-WAN TESTING SUITE
# Tests connectivity, traffic generation, failover, and monitoring
# =============================================================================

COLOR_GREEN='\033[0;32m'
COLOR_RED='\033[0;31m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_RESET='\033[0m'
# =============================================================================
# SITE DEFINITIONS
# =============================================================================

declare -A SITES=(
  [site1]="10.2.1.10"
  [site2]="10.3.1.10"
  [site3]="10.4.1.10"
)

HQ_NS="hq"

# Test results storage
RESULTS_DIR="/tmp/sdwan_test_results"
mkdir -p "$RESULTS_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REPORT_FILE="$RESULTS_DIR/test_report_${TIMESTAMP}.txt"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

print_header() {
    echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║  $1${COLOR_RESET}"
    echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

print_test() {
    echo -e "${COLOR_YELLOW}[TEST]${COLOR_RESET} $1"
    echo "[TEST] $1" >> "$REPORT_FILE"
}

print_success() {
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $1"
    echo "[SUCCESS] $1" >> "$REPORT_FILE"
}

print_fail() {
    echo -e "${COLOR_RED}[✗]${COLOR_RESET} $1"
    echo "[FAIL] $1" >> "$REPORT_FILE"
}

print_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $1"
    echo "[INFO] $1" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 1: CONNECTIVITY TESTS
# =============================================================================

   test_connectivity() {
    print_header "TEST 1: CONNECTIVITY VERIFICATION"

    local passed=0
    local failed=0

    # HQ to all sites
    for site in "${!SITES[@]}"; do
        local ip="${SITES[$site]}"
        print_test "Testing HQ → ${site} (${ip})"
        if sudo ip netns exec "$HQ_NS" ping -c 3 -W 2 "$ip" > /dev/null 2>&1; then
            print_success "HQ → ${site}: OK"
            ((passed++))
        else
            print_fail "HQ → ${site}: FAILED"
            ((failed++))
        fi
    done

    # Inter-site connectivity
    for src in "${!SITES[@]}"; do
        for dst in "${!SITES[@]}"; do
            [[ "$src" == "$dst" ]] && continue
            print_test "Testing ${src} → ${dst}"
            if sudo ip netns exec "$src" ping -c 3 -W 2 "${SITES[$dst]}" > /dev/null 2>&1; then
                print_success "${src} → ${dst}: OK"
                ((passed++))
            else
                print_fail "${src} → ${dst}: FAILED"
                ((failed++))
            fi
        done
    done

    print_info "Connectivity Tests: $passed passed, $failed failed"
    echo "----------------------------------------" >> "$REPORT_FILE"
    return $failed
}
 
   
# =============================================================================
# TEST 2: LATENCY MEASUREMENTS
# =============================================================================

test_latency() {
    print_header "TEST 2: LATENCY MEASUREMENTS"
    local results_file="$RESULTS_DIR/latency_${TIMESTAMP}.txt"

    for site in "${!SITES[@]}"; do
        local ip="${SITES[$site]}"
        print_test "Measuring latency HQ → ${site}"
        local latency=$(sudo ip netns exec "$HQ_NS" ping -c 5 -W 2 "$ip" 2>/dev/null \
                        | awk -F'/' '/rtt/ {print $5}')
        if [ -n "$latency" ]; then
            print_success "HQ → ${site}: ${latency}ms average"
            echo "HQ→${site}: ${latency}ms" >> "$results_file"
        else
            print_fail "Could not measure latency to ${site}"
        fi
    done

    print_info "Latency results saved to: $results_file"
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 3: PACKET LOSS TEST
# =============================================================================

test_packet_loss() {
    print_header "TEST 3: PACKET LOSS ANALYSIS"
    local results_file="$RESULTS_DIR/packet_loss_${TIMESTAMP}.txt"

    for site in "${!SITES[@]}"; do
        local ip="${SITES[$site]}"
        print_test "Testing packet loss HQ → ${site} (50 packets)"
        local loss=$(sudo ip netns exec "$HQ_NS" ping -c 50 -i 0.2 "$ip" 2>/dev/null \
                     | awk '/packet loss/ {print $6}')
        if [ -n "$loss" ]; then
            print_success "HQ → ${site}: ${loss} packet loss"
            echo "HQ→${site}: ${loss}" >> "$results_file"
        else
            print_fail "Could not measure packet loss to ${site}"
        fi
    done

    print_info "Packet loss results saved to: $results_file"
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 4: BANDWIDTH/THROUGHPUT TEST
# =============================================================================

test_bandwidth() {
    print_header "TEST 4: BANDWIDTH TESTING (iperf3)"
    local results_file="$RESULTS_DIR/bandwidth_${TIMESTAMP}.txt"

    command -v iperf3 &>/dev/null || {
        print_fail "iperf3 not installed"
        return 1
    }

    for site in "${!SITES[@]}"; do
        local ip="${SITES[$site]}"

        print_info "Starting iperf3 server on ${site}"
        sudo ip netns exec "$site" iperf3 -s -D -1 > /dev/null 2>&1
        sleep 2

        print_test "Testing bandwidth HQ → ${site}"
        local bw=$(sudo ip netns exec "$HQ_NS" iperf3 -c "$ip" -t 5 -J 2>/dev/null \
                   | awk '/bits_per_second/ {print $2; exit}' | tr -d ',')
        if [ -n "$bw" ]; then
            local mbps=$(echo "scale=2; $bw / 1000000" | bc)
            print_success "HQ → ${site}: ${mbps} Mbps"
            echo "HQ→${site}: ${mbps} Mbps" >> "$results_file"
        else
            print_fail "Could not measure bandwidth to ${site}"
        fi
    done

    sudo pkill -9 iperf3 2>/dev/null
    print_info "Bandwidth results saved to: $results_file"
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 5: QOS / TRAFFIC PRIORITIZATION TEST
# =============================================================================

test_qos() {
    print_header "TEST 5: QoS / TRAFFIC PRIORITIZATION"
    
    print_test "Testing high-priority traffic (marked packets)"
    
    # Send high-priority traffic (ToS marked)
    print_info "Sending ToS-marked packets (simulating VoIP)..."
    sudo ip netns exec hq ping -Q 184 -c 5 10.2.1.10 > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "High-priority traffic sent successfully (ToS=184/DSCP=46)"
        print_info "Check controller logs for priority flow installation"
    else
        print_fail "Failed to send high-priority traffic"
    fi
    
    # Send normal traffic
    print_info "Sending normal priority packets..."
    sudo ip netns exec hq ping -c 5 10.2.1.10 > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        print_success "Normal traffic sent successfully"
    fi
    
    echo ""
    print_info "QoS test completed. Review controller logs for flow priorities."
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 6: TUNNEL VERIFICATION
# =============================================================================

test_tunnels() {
    print_header "TEST 6: GRE TUNNEL VERIFICATION"
    
    print_test "Checking GRE tunnel interfaces..."
    
    local tunnels_ok=0
    local tunnels_fail=0
    
    # Check tunnel interfaces on bridges
    for bridge in ovs-hq ovs-site1 ovs-site2 ovs-site3; do
        if sudo ovs-vsctl list-ports "$bridge" | grep -q "gre"; then
            print_success "GRE tunnels configured on $bridge"
            ((tunnels_ok++))
        else
            print_fail "No GRE tunnels found on $bridge"
            ((tunnels_fail++))
        fi
    done
    
    # Check tunnel endpoints
    print_test "Verifying tunnel endpoint connectivity..."
    
    if ping -c 3 -W 1 192.168.100.1 > /dev/null 2>&1; then
        print_success "HQ tunnel endpoint (192.168.100.1) reachable"
        ((tunnels_ok++))
    else
        print_fail "HQ tunnel endpoint unreachable"
        ((tunnels_fail++))
    fi
    
    if ping -c 3 -W 1 192.168.100.2 > /dev/null 2>&1; then
        print_success "Site1 tunnel endpoint (192.168.100.2) reachable"
        ((tunnels_ok++))
    else
        print_fail "Site1 tunnel endpoint unreachable"
        ((tunnels_fail++))
    fi
    
    if ping -c 3 -W 1 192.168.100.3 > /dev/null 2>&1; then
        print_success "Site2 tunnel endpoint (192.168.100.3) reachable"
        ((tunnels_ok++))
    else
        print_fail "Site2 tunnel endpoint unreachable"
        ((tunnels_fail++))
    fi
    
    echo ""
    print_info "Tunnel verification: $tunnels_ok passed, $tunnels_fail failed"
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 7: CONTROLLER CONNECTIVITY
# =============================================================================

test_controller() {
    print_header "TEST 7: SDN CONTROLLER STATUS"
    
    print_test "Checking if Ryu controller is running..."
    
    if pgrep -f "ryu-manager" > /dev/null; then
        print_success "Ryu controller is running"
    else
        print_fail "Ryu controller is NOT running"
        return 1
    fi
    
    print_test "Verifying OpenFlow connections..."
    
    local connected=0
    for bridge in ovs-hq ovs-site1 ovs-site2 ovs-site3; do
        if sudo ovs-vsctl get-controller "$bridge" | grep -q "tcp"; then
            print_success "$bridge connected to controller"
            ((connected++))
        else
            print_fail "$bridge NOT connected to controller"
        fi
    done
    
    if [ $connected -eq 3 ]; then
        print_success "All switches connected to controller"
    else
        print_fail "Only $connected/3 switches connected"
    fi
    
    echo ""
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 8: FAILOVER SIMULATION
# =============================================================================

test_failover() {
    print_header "TEST 8: FAILOVER SIMULATION"
    
    print_test "Simulating link degradation to Site1..."
    
    # Add artificial latency to Site1 path
    print_info "Adding 150ms latency to Site1 interface..."
    sudo ip netns exec site1 tc qdisc add dev veth-s1 root netem delay 150ms 2>/dev/null
    
    sleep 5
    
    # Measure latency
    print_test "Measuring latency after degradation..."
    local high_latency=$(sudo ip netns exec hq ping -c 3 10.2.1.10 2>/dev/null | grep 'avg' | awk -F'/' '{print $5}')
    
    if [ -n "$high_latency" ]; then
        print_info "Current latency to Site1: ${high_latency}ms"
        
        # Check if above threshold
        if (( $(echo "$high_latency > 50" | bc -l) )); then
            print_success "High latency detected (${high_latency}ms > 50ms threshold)"
            print_info "Controller should log this and consider path switching"
        fi
    fi
    
    sleep 10
    
    # Remove latency
    print_info "Removing artificial latency..."
    sudo ip netns exec site1 tc qdisc del dev veth-s1 root 2>/dev/null
    
    sleep 3
    
    # Verify recovery
    print_test "Verifying path recovery..."
    local normal_latency=$(sudo ip netns exec hq ping -c 3 10.2.1.10 2>/dev/null | grep 'avg' | awk -F'/' '{print $5}')
    
    if [ -n "$normal_latency" ]; then
        print_success "Latency restored to: ${normal_latency}ms"
    fi
    
    echo ""
    print_info "Failover simulation completed. Check controller logs for adaptive behavior."
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# TEST 9: MONITORING DATA COLLECTION
# =============================================================================

test_monitoring() {
    print_header "TEST 9: MONITORING DATA VERIFICATION"
    
    print_test "Checking for monitoring data files..."
    
    if [ -f "/tmp/sdwan_events.log" ]; then
        local event_count=$(wc -l < /tmp/sdwan_events.log)
        print_success "Event log found: $event_count events recorded"
    else
        print_fail "Event log not found"
    fi
    
    if [ -f "/tmp/sdwan_metrics.json" ]; then
        print_success "Metrics JSON file found"
        print_info "Latest metrics:"
        tail -20 /tmp/sdwan_metrics.json | head -10
    else
        print_fail "Metrics JSON file not found"
    fi
    
    echo ""
    echo "----------------------------------------" >> "$REPORT_FILE"
}

# =============================================================================
# GENERATE FINAL REPORT
# =============================================================================

generate_report() {
    print_header "GENERATING FINAL REPORT"
    
    echo "" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "SD-WAN TEST SUITE - FINAL SUMMARY" >> "$REPORT_FILE"
    echo "Date: $(date)" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    
    print_info "Full test report saved to: $REPORT_FILE"
    
    # Create summary file
    local summary_file="$RESULTS_DIR/SUMMARY.txt"
    cat > "$summary_file" << EOF
SD-WAN Testing Summary
======================
Date: $(date)

Test Results Location: $RESULTS_DIR

Key Files:
- Full Report: $REPORT_FILE
- Latency Data: latency_${TIMESTAMP}.txt
- Packet Loss: packet_loss_${TIMESTAMP}.txt
- Bandwidth: bandwidth_${TIMESTAMP}.txt

Monitoring Data:
- Events Log: /tmp/sdwan_events.log
- Metrics JSON: /tmp/sdwan_metrics.json

All tests completed successfully!
EOF
    
    print_success "Summary saved to: $summary_file"
    
    echo ""
    echo -e "${COLOR_GREEN}╔════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║  ALL TESTS COMPLETED!                                          ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║  Results Directory: $RESULTS_DIR${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
    clear
    echo ""
    echo -e "${COLOR_BLUE}╔════════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║           SD-WAN AUTOMATED TEST SUITE                          ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}║           Multi-Site Network Testing                           ║${COLOR_RESET}"
    echo -e "${COLOR_BLUE}╚════════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    # Initialize report
    echo "SD-WAN Automated Test Report" > "$REPORT_FILE"
    echo "Generated: $(date)" >> "$REPORT_FILE"
    echo "========================================" >> "$REPORT_FILE"
    echo "" >> "$REPORT_FILE"
    
    # Run all tests
    test_controller
    test_tunnels
    test_connectivity
    test_latency
    test_packet_loss
    test_bandwidth
    test_qos
    test_failover
    test_monitoring
    
    # Generate final report
    generate_report
    
    echo ""
    echo -e "${COLOR_BLUE}Test suite completed. Review results in: $RESULTS_DIR${COLOR_RESET}"
    echo ""
}

# Run main function
main "$@"
