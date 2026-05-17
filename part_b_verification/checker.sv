`ifndef CHECKER_SV
`define CHECKER_SV

// ----------------------------------------------------------------------
// checker.sv
// Scoreboard / Checker Component
// Tracks expected packets vs actual packets received and reports statistics.
// ----------------------------------------------------------------------
class checkerr extends component_base; 

	// Packet Queues: One per port
	packet expected_q [4][$];
	packet actual_q   [4][$];
	
	// Global Statistics
	int total_matches = 0;
	int total_errors  = 0;
	int cnt_uni = 0, cnt_multi = 0, cnt_bcast = 0;
	int packets_sent = 0;           
	int output_packets_expected = 0; 
	
	// Per-Port Statistics
	int port_matches[4];
	int port_errors[4];
	int port_received[4];
	int port_expected[4];
	
	// Timing Analysis
	time first_packet_time, last_packet_time;
	bit first_packet_seen = 0;

	// ------------------------------------------------------------------
	// Constructor
	// Initializes statistical counters.
	// ------------------------------------------------------------------
	function new(string n, component_base p=null); 
		super.new(n, p);
		for (int i = 0; i < 4; i++) begin
			port_matches[i]  = 0; 
			port_errors[i]   = 0;
			port_received[i] = 0; 
			port_expected[i] = 0;
		end
	endfunction

	// ------------------------------------------------------------------
	// Helper: get_backlog
	// Returns the total number of packets currently pending in expected queues.
	// ------------------------------------------------------------------
	function int get_backlog();
		return expected_q[0].size() + expected_q[1].size() + 
			   expected_q[2].size() + expected_q[3].size();
	endfunction

	// ------------------------------------------------------------------
	// Method: add_expected
	// Registers a packet sent by the driver as "Expected".
	// Handles Multicast/Broadcast replication logic.
	// ------------------------------------------------------------------
	function void add_expected(packet p);
		packet p_copy;
		logic [3:0] target_mask;
		packets_sent++;
		
		// Apply routing logic: Mask source bit to prevent self-loop
		target_mask = p.target & ~p.source;

		// Replicate packet to all valid destination queues
		for (int i = 0; i < 4; i++) begin
			if (target_mask[i]) begin
				p_copy = p.clone(); 
				expected_q[i].push_back(p_copy);
				port_expected[i]++;
				output_packets_expected++; 
			end
		end
	endfunction

	// ------------------------------------------------------------------
	// Method: check_actual
	// Registers a packet received by the monitor as "Actual".
	// ------------------------------------------------------------------
	function void check_actual(packet p_rcv, int port_idx);
		if (port_idx < 0 || port_idx >= 4) return;
		
		// Update timing stats
		if (!first_packet_seen) begin
			first_packet_time = $time;
			first_packet_seen = 1;
		end
		last_packet_time = $time;
		
		port_received[port_idx]++;
		actual_q[port_idx].push_back(p_rcv.clone());
	endfunction

	// ------------------------------------------------------------------
	// Method: match_packet
	// Searches for a received packet in the expected queue.
	// Returns 1 if matched, 0 if unexpected/error.
	// ------------------------------------------------------------------
	function bit match_packet(int port_idx, packet act);
		int found_idx = -1;
		
		// Linear search in the specific port's expected queue
		for (int k = 0; k < expected_q[port_idx].size(); k++) begin
			if (expected_q[port_idx][k].source == act.source && 
				expected_q[port_idx][k].data   == act.data) begin
				found_idx = k;
				break;
			end
		end

		if (found_idx >= 0) begin
			// Match Found
			port_matches[port_idx]++;
			
			// Update Packet Type Stats
			if (expected_q[port_idx][found_idx].target == 4'b1111) 
				cnt_bcast++;
			else if ($countones(expected_q[port_idx][found_idx].target) == 1) 
				cnt_uni++;
			else 
				cnt_multi++;
			
			// Remove from expected queue
			expected_q[port_idx].delete(found_idx);
			return 1'b1;
		end else begin
			// Mismatch / Unexpected Packet
			port_errors[port_idx]++;
			$error("[%0t] [CHECKER] Port %0d: Unexpected packet! Src=%b Data=%h", 
				   $time, port_idx, act.source, act.data);
			return 1'b0;
		end
	endfunction

	// ------------------------------------------------------------------
	// Task: run
	// Continuous background process to match actual vs expected packets.
	// ------------------------------------------------------------------
	task run(int num_packets = 0);
		forever begin
			for (int i = 0; i < 4; i++) begin
				while (actual_q[i].size() > 0) begin
					packet act = actual_q[i].pop_front();
					if (match_packet(i, act)) 
						total_matches++;
					else 
						total_errors++;
				end
			end
			#1ns; 
		end
	endtask

	// ------------------------------------------------------------------
	// Debug Method
	// Prints current queue sizes for diagnosis.
	// ------------------------------------------------------------------
	function void debug_q();
		$display("[SCB_DBG] Q Sizes: %0d %0d %0d %0d | Pending: %0d", 
				 expected_q[0].size(), expected_q[1].size(), 
				 expected_q[2].size(), expected_q[3].size(), get_backlog());
	endfunction

	// ------------------------------------------------------------------
	// Method: report
	// Displays the final verification summary and pass/fail status.
	// ------------------------------------------------------------------
	function void report();
		int drops = get_backlog();
		real output_success_rate;
		
		if (output_packets_expected > 0)
			output_success_rate = (total_matches / real'(output_packets_expected)) * 100.0;
		else
			output_success_rate = 0.0;
		
		$display("\n" + {"="} * 80);
		$display("CHECKER VERIFICATION REPORT");
		$display({"="} * 80);
		$display("  Unique Packets Sent:      %0d", packets_sent);
		$display("  Output Packets Expected:  %0d", output_packets_expected);
		$display("  Correctly Matched:        %0d", total_matches);
		$display("  Routing Errors:           %0d", total_errors);
		$display("  Dropped/Missing:          %0d", drops);
		$display({"-" } * 80);
		$display("  ★ OUTPUT SUCCESS RATE:    %.2f%%", output_success_rate);
		
		if (drops == 0 && total_errors == 0 && total_matches > 0)
			$display("VERIFICATION STATUS: ★★★ PASSED ★★★");
		else begin
			$display("VERIFICATION STATUS: ✗✗✗ FAILED ✗✗✗");
			if (drops > 0) $display("  • %0d packets dropped", drops);
		end
		$display({"="} * 80 + "\n");
	endfunction
endclass
`endif