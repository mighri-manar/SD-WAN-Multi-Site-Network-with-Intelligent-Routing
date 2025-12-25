#!/usr/bin/env python3
"""
Enhanced SD-WAN Multi-Site Controller with Ryu
Features: Dynamic routing, QoS, path selection, monitoring, failover
Author: SD-WAN Project Team
"""

from ryu.base import app_manager
from ryu.controller import ofp_event
from ryu.controller.handler import CONFIG_DISPATCHER, MAIN_DISPATCHER, set_ev_cls
from ryu.ofproto import ofproto_v1_3
from ryu.lib.packet import packet, ethernet, ether_types, ipv4, icmp, tcp, udp
from ryu.lib import hub
import time
import subprocess
import re
import json
from datetime import datetime

class EnhancedSDWANController(app_manager.RyuApp):
    OFP_VERSIONS = [ofproto_v1_3.OFP_VERSION]

    def __init__(self, *args, **kwargs):
        super(EnhancedSDWANController, self).__init__(*args, **kwargs)
        
        # MAC learning table: {dpid: {mac: port}}
        self.mac_to_port = {}
        
        # Track datapaths
        self.datapaths = {}
        
        # Path metrics storage: {path_name: {latency, loss, bandwidth, timestamp}}
        self.path_metrics = {}
        
        # Thresholds for path selection
        self.LATENCY_THRESHOLD = 50  # ms
        self.LOSS_THRESHOLD = 5      # %
        self.LATENCY_CRITICAL = 100  # ms - triggers immediate failover
        
        # QoS Configuration
        self.VOIP_PORTS = [5060, 5061]  # SIP ports
        self.HIGH_PRIORITY_PORTS = [22, 443]  # SSH, HTTPS
        
        # Statistics
        self.flow_stats = {}
        self.port_stats = {}
        self.bandwidth_stats = {}
        
        # Active paths tracking
        self.active_paths = {
            'HQ-to-Site1': {'status': 'unknown', 'last_switch': 0},
            'HQ-to-Site2': {'status': 'unknown', 'last_switch': 0},
            'HQ-to-Site3': {'status': 'unknown', 'last_switch': 0}
        }
        
        # Performance history for trend analysis
        self.performance_history = {
            'HQ-to-Site1': [],
            'HQ-to-Site2': [],
            'HQ-to-Site3': []
        }
        
        # Anomaly detection counters
        self.anomaly_counts = {}
        
        # Start monitoring thread
        self.monitor_thread = hub.spawn(self._monitor_loop)
        
        # Log file
        self.log_file = open('/tmp/sdwan_events.log', 'w')
        
        self._log_event("SYSTEM", "SD-WAN Controller Initialized")
        self.logger.info("="*70)
        self.logger.info("    ENHANCED SD-WAN CONTROLLER STARTED")
        self.logger.info("    Features: QoS, Dynamic Routing, Failover, Monitoring")
        self.logger.info("="*70)

    def _log_event(self, event_type, message):
        """Log events to file for analysis"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        log_entry = f"[{timestamp}] {event_type}: {message}\n"
        self.log_file.write(log_entry)
        self.log_file.flush()

    @set_ev_cls(ofp_event.EventOFPSwitchFeatures, CONFIG_DISPATCHER)
    def switch_features_handler(self, ev):
        """Handle switch connection"""
        datapath = ev.msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        dpid = datapath.id
        
        # Store datapath
        self.datapaths[dpid] = datapath
        
        self.logger.info(f"✓ Switch connected: DPID={dpid}")
        self._log_event("SWITCH", f"Switch {dpid} connected")
        
        # Install table-miss flow entry (send to controller)
        match = parser.OFPMatch()
        actions = [parser.OFPActionOutput(ofproto.OFPP_CONTROLLER,
                                          ofproto.OFPCML_NO_BUFFER)]
        self.add_flow(datapath, 0, match, actions)
        
        # Request initial stats
        self._request_stats(datapath)

    def add_flow(self, datapath, priority, match, actions, buffer_id=None, 
                 idle_timeout=0, hard_timeout=0):
        """Add flow entry to switch"""
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser

        inst = [parser.OFPInstructionActions(ofproto.OFPIT_APPLY_ACTIONS, actions)]
        
        if buffer_id:
            mod = parser.OFPFlowMod(
                datapath=datapath, buffer_id=buffer_id,
                priority=priority, match=match,
                instructions=inst, idle_timeout=idle_timeout,
                hard_timeout=hard_timeout
            )
        else:
            mod = parser.OFPFlowMod(
                datapath=datapath, priority=priority,
                match=match, instructions=inst,
                idle_timeout=idle_timeout, hard_timeout=hard_timeout
            )
        datapath.send_msg(mod)

    @set_ev_cls(ofp_event.EventOFPPacketIn, MAIN_DISPATCHER)
    def _packet_in_handler(self, ev):
        """Handle packet-in events with QoS support"""
        msg = ev.msg
        datapath = msg.datapath
        ofproto = datapath.ofproto
        parser = datapath.ofproto_parser
        in_port = msg.match['in_port']
        dpid = datapath.id

        pkt = packet.Packet(msg.data)
        eth = pkt.get_protocols(ethernet.ethernet)[0]

        # Ignore LLDP packets
        if eth.ethertype == ether_types.ETH_TYPE_LLDP:
            return

        dst = eth.dst
        src = eth.src

        # Initialize MAC table for this switch
        self.mac_to_port.setdefault(dpid, {})
        
        # Learn source MAC
        self.mac_to_port[dpid][src] = in_port

        # Determine output port
        if dst in self.mac_to_port[dpid]:
            out_port = self.mac_to_port[dpid][dst]
        else:
            out_port = ofproto.OFPP_FLOOD

        actions = [parser.OFPActionOutput(out_port)]

        # Install flow if destination is known
        if out_port != ofproto.OFPP_FLOOD:
            # Determine priority based on traffic type
            priority = self._calculate_priority(pkt)
            
            ip_pkt = pkt.get_protocol(ipv4.ipv4)
            
            if ip_pkt:
                if priority >= 100:
                    self.logger.info(f"⭐ HIGH PRIORITY flow: {ip_pkt.src} -> {ip_pkt.dst} on DPID={dpid} (priority={priority})")
                    self._log_event("QOS", f"High priority flow installed: {ip_pkt.src}->{ip_pkt.dst}")
                else:
                    self.logger.info(f"📝 Standard flow: {src} -> {dst} on DPID={dpid} port={out_port}")
            
            match = parser.OFPMatch(in_port=in_port, eth_dst=dst, eth_src=src)
            
            # Install flow with timeout
            if msg.buffer_id != ofproto.OFP_NO_BUFFER:
                self.add_flow(datapath, priority, match, actions, 
                            msg.buffer_id, idle_timeout=30, hard_timeout=60)
                return
            else:
                self.add_flow(datapath, priority, match, actions,
                            idle_timeout=30, hard_timeout=60)

        # Send packet out
        data = None
        if msg.buffer_id == ofproto.OFP_NO_BUFFER:
            data = msg.data

        out = parser.OFPPacketOut(
            datapath=datapath, buffer_id=msg.buffer_id,
            in_port=in_port, actions=actions, data=data
        )
        datapath.send_msg(out)

    def _calculate_priority(self, pkt):
        """Calculate flow priority based on traffic type (QoS)"""
        ip_pkt = pkt.get_protocol(ipv4.ipv4)
        
        if not ip_pkt:
            return 1  # Default priority
        
        # Check TCP/UDP ports for application identification
        tcp_pkt = pkt.get_protocol(tcp.tcp)
        udp_pkt = pkt.get_protocol(udp.udp)
        
        # VoIP traffic (highest priority)
        if udp_pkt and (udp_pkt.src_port in self.VOIP_PORTS or 
                        udp_pkt.dst_port in self.VOIP_PORTS):
            return 200
        
        # High priority services (SSH, HTTPS)
        if tcp_pkt and (tcp_pkt.src_port in self.HIGH_PRIORITY_PORTS or 
                        tcp_pkt.dst_port in self.HIGH_PRIORITY_PORTS):
            return 150
        
        # Check ToS/DSCP field
        dscp = ip_pkt.tos >> 2
        
        # DSCP EF (46) - Expedited Forwarding (VoIP)
        if dscp == 46:
            return 200
        
        # DSCP AF4x (32-38) - Assured Forwarding Class 4
        if 32 <= dscp <= 38:
            return 150
        
        # Any marked traffic
        if ip_pkt.tos > 0:
            return 100
        
        return 1  # Default best-effort

    def _request_stats(self, datapath):
        """Request statistics from switch"""
        parser = datapath.ofproto_parser
        
        # Request flow stats
        req = parser.OFPFlowStatsRequest(datapath)
        datapath.send_msg(req)
        
        # Request port stats
        req = parser.OFPPortStatsRequest(datapath, 0, datapath.ofproto.OFPP_ANY)
        datapath.send_msg(req)

    @set_ev_cls(ofp_event.EventOFPFlowStatsReply, MAIN_DISPATCHER)
    def _flow_stats_reply_handler(self, ev):
        """Handle flow statistics reply"""
        body = ev.msg.body
        dpid = ev.msg.datapath.id
        
        self.flow_stats[dpid] = []
        
        total_packets = 0
        total_bytes = 0
        
        for stat in body:
            self.flow_stats[dpid].append({
                'priority': stat.priority,
                'packet_count': stat.packet_count,
                'byte_count': stat.byte_count,
                'duration_sec': stat.duration_sec
            })
            total_packets += stat.packet_count
            total_bytes += stat.byte_count
        
        # Calculate bandwidth (rough estimate)
        if dpid not in self.bandwidth_stats:
            self.bandwidth_stats[dpid] = {'last_bytes': 0, 'last_time': time.time()}
        
        current_time = time.time()
        time_diff = current_time - self.bandwidth_stats[dpid]['last_time']
        
        if time_diff > 0:
            bytes_diff = total_bytes - self.bandwidth_stats[dpid]['last_bytes']
            bandwidth_mbps = (bytes_diff * 8) / (time_diff * 1000000)
            self.bandwidth_stats[dpid]['bandwidth'] = bandwidth_mbps
        
        self.bandwidth_stats[dpid]['last_bytes'] = total_bytes
        self.bandwidth_stats[dpid]['last_time'] = current_time

    @set_ev_cls(ofp_event.EventOFPPortStatsReply, MAIN_DISPATCHER)
    def _port_stats_reply_handler(self, ev):
        """Handle port statistics reply"""
        body = ev.msg.body
        dpid = ev.msg.datapath.id
        
        self.port_stats[dpid] = {}
        
        for stat in body:
            self.port_stats[dpid][stat.port_no] = {
                'rx_packets': stat.rx_packets,
                'tx_packets': stat.tx_packets,
                'rx_bytes': stat.rx_bytes,
                'tx_bytes': stat.tx_bytes,
                'rx_errors': stat.rx_errors,
                'tx_errors': stat.tx_errors,
                'rx_dropped': stat.rx_dropped,
                'tx_dropped': stat.tx_dropped
            }

    def _monitor_loop(self):
        """Main monitoring loop with enhanced features"""
        self.logger.info("🔄 Enhanced monitoring thread started")
        
        # Wait for switches to connect
        hub.sleep(5)
        
        cycle = 0
        while True:
            hub.sleep(10)  # Monitor every 10 seconds
            cycle += 1
            
            if not self.datapaths:
                continue
            
            self.logger.info("")
            self.logger.info("="*70)
            self.logger.info(f"📊 MONITORING CYCLE #{cycle} - {datetime.now().strftime('%H:%M:%S')}")
            self.logger.info("="*70)
            
            # Request stats from all switches
            for dpid, datapath in self.datapaths.items():
                self._request_stats(datapath)
            
            # Measure path metrics
            self._measure_all_paths()
            
            # Detect anomalies
            self._detect_anomalies()
            
            # Analyze paths and potentially trigger failover
            self._analyze_paths()
            
            # Display current status
            self._display_status()
            
            # Save metrics to file every 30 seconds
            if cycle % 3 == 0:
                self._save_metrics()

    def _measure_all_paths(self):
        """Measure latency and loss for all paths"""
        paths = [
            ('10.2.1.10', 'HQ-to-Site1'),
            ('10.3.1.10', 'HQ-to-Site2'),
            ('10.4.1.10', 'HQ-to-Site3'),
        ]
        
        for target_ip, path_name in paths:
            metrics = self._measure_path(target_ip)
            
            # Store in history
            if path_name not in self.performance_history:
                self.performance_history[path_name] = []
            
            self.performance_history[path_name].append({
                'timestamp': time.time(),
                'latency': metrics['latency'],
                'loss': metrics['loss']
            })
            
            # Keep only last 20 measurements
            if len(self.performance_history[path_name]) > 20:
                self.performance_history[path_name].pop(0)
            
            self.path_metrics[path_name] = metrics

    def _measure_path(self, target_ip):
        """Measure latency and packet loss to target"""
        try:
            # Try from hq namespace
            try:
                result = subprocess.run(
                    ['sudo', 'ip', 'netns', 'exec', 'hq', 'ping', '-c', '3', '-W', '1', target_ip],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
            except:
                # Fallback to regular ping
                result = subprocess.run(
                    ['ping', '-c', '3', '-W', '1', target_ip],
                    capture_output=True,
                    text=True,
                    timeout=5
                )
            
            output = result.stdout
            
            # Parse latency
            latency_match = re.search(r'min/avg/max/[^=]*= [\d.]+/([\d.]+)/[\d.]+', output)
            if not latency_match:
                latency_match = re.search(r'avg = ([\d.]+)', output)
            
            latency = float(latency_match.group(1)) if latency_match else 999.0
            
            # Parse packet loss
            loss_match = re.search(r'(\d+)% packet loss', output)
            loss = float(loss_match.group(1)) if loss_match else 100.0
            
            return {
                'latency': latency,
                'loss': loss,
                'timestamp': time.time(),
                'available': loss < 100,
                'quality': self._calculate_quality_score(latency, loss)
            }
            
        except Exception as e:
            return {
                'latency': 999.0,
                'loss': 100.0,
                'timestamp': time.time(),
                'available': False,
                'quality': 0
            }

    def _calculate_quality_score(self, latency, loss):
        """Calculate path quality score (0-100)"""
        if loss == 100:
            return 0
        
        # Score based on latency and loss
        latency_score = max(0, 100 - (latency / 2))  # 0ms=100, 200ms=0
        loss_score = 100 - (loss * 10)  # 0%=100, 10%=0
        
        # Weighted average (latency 60%, loss 40%)
        score = (latency_score * 0.6) + (loss_score * 0.4)
        
        return max(0, min(100, score))

    def _detect_anomalies(self):
        """Detect network anomalies"""
        for path_name, history in self.performance_history.items():
            if len(history) < 5:
                continue
            
            # Get recent measurements
            recent = history[-5:]
            latencies = [m['latency'] for m in recent]
            losses = [m['loss'] for m in recent]
            
            # Calculate average
            avg_latency = sum(latencies) / len(latencies)
            avg_loss = sum(losses) / len(losses)
            
            # Detect spike
            current_latency = latencies[-1]
            if current_latency > avg_latency * 2 and current_latency > 50:
                self.logger.warning(f"🚨 ANOMALY DETECTED on {path_name}: Latency spike!")
                self.logger.warning(f"   Current: {current_latency:.1f}ms, Average: {avg_latency:.1f}ms")
                self._log_event("ANOMALY", f"{path_name} latency spike: {current_latency:.1f}ms")
                
                # Increment anomaly counter
                if path_name not in self.anomaly_counts:
                    self.anomaly_counts[path_name] = 0
                self.anomaly_counts[path_name] += 1

    def _analyze_paths(self):
        """Analyze path quality and trigger failover if needed"""
        for path_name, metrics in self.path_metrics.items():
            status = "✓ OK"
            action_needed = False
            
            if not metrics['available']:
                status = "❌ DOWN"
                action_needed = True
                self.logger.error(f"{status} Path {path_name} is DOWN!")
                self._log_event("FAILOVER", f"{path_name} is down - triggering failover")
                
            elif metrics['latency'] > self.LATENCY_CRITICAL:
                status = "🔴 CRITICAL"
                action_needed = True
                self.logger.error(f"{status} Path {path_name}: CRITICAL LATENCY!")
                self.logger.error(f"   Current: {metrics['latency']:.2f}ms (threshold: {self.LATENCY_CRITICAL}ms)")
                self._log_event("FAILOVER", f"{path_name} critical latency: {metrics['latency']:.2f}ms")
                
            elif metrics['latency'] > self.LATENCY_THRESHOLD:
                status = "⚠️  HIGH"
                self.logger.warning(f"{status} Path {path_name}: HIGH LATENCY")
                self.logger.warning(f"   Current: {metrics['latency']:.2f}ms (threshold: {self.LATENCY_THRESHOLD}ms)")
                
            elif metrics['loss'] > self.LOSS_THRESHOLD:
                status = "⚠️  LOSS"
                self.logger.warning(f"{status} Path {path_name}: HIGH PACKET LOSS")
                self.logger.warning(f"   Current: {metrics['loss']:.1f}% (threshold: {self.LOSS_THRESHOLD}%)")
            
            # Update active path status
            if path_name in self.active_paths:
                self.active_paths[path_name]['status'] = status
                
                # Trigger failover if needed (with cooldown)
                if action_needed:
                    last_switch = self.active_paths[path_name]['last_switch']
                    if time.time() - last_switch > 30:  # 30 second cooldown
                        self.logger.info(f"   🔄 Initiating automatic failover for {path_name}")
                        self.active_paths[path_name]['last_switch'] = time.time()
                        # In real implementation, this would trigger flow reconfiguration

    def _display_status(self):
        """Display comprehensive network status"""
        self.logger.info("")
        self.logger.info("--- Network Status Summary ---")
        self.logger.info(f"Connected Switches: {len(self.datapaths)}")
        
        # Show switch details
        for dpid in self.datapaths:
            learned_macs = len(self.mac_to_port.get(dpid, {}))
            flows = len(self.flow_stats.get(dpid, []))
            bw = self.bandwidth_stats.get(dpid, {}).get('bandwidth', 0)
            self.logger.info(f"  DPID {dpid}: {learned_macs} MACs, {flows} flows, ~{bw:.2f} Mbps")
        
        # Show path metrics
        if self.path_metrics:
            self.logger.info("")
            self.logger.info("--- Path Metrics & Quality ---")
            for path_name, metrics in sorted(self.path_metrics.items()):
                status = self.active_paths.get(path_name, {}).get('status', 'unknown')
                quality = metrics.get('quality', 0)
                
                quality_bar = "█" * int(quality / 10) + "░" * (10 - int(quality / 10))
                
                self.logger.info(f"{status} {path_name}:")
                self.logger.info(f"   Latency: {metrics['latency']:.2f}ms | Loss: {metrics['loss']:.1f}% | Quality: [{quality_bar}] {quality:.0f}/100")
        
        # Show anomaly counts
        if self.anomaly_counts:
            self.logger.info("")
            self.logger.info("--- Anomaly Detection ---")
            for path_name, count in self.anomaly_counts.items():
                self.logger.info(f"  {path_name}: {count} anomalies detected")
        
        self.logger.info("="*70)

    def _save_metrics(self):
        """Save metrics to JSON file for later analysis"""
        try:
            metrics_data = {
                'timestamp': datetime.now().isoformat(),
                'paths': self.path_metrics,
                'anomalies': self.anomaly_counts,
                'bandwidth': self.bandwidth_stats
            }
            
            with open('/tmp/sdwan_metrics.json', 'w') as f:
                json.dump(metrics_data, f, indent=2)
                
        except Exception as e:
            self.logger.error(f"Failed to save metrics: {e}")

    def __del__(self):
        """Cleanup on shutdown"""
        if hasattr(self, 'log_file'):
            self.log_file.close()
