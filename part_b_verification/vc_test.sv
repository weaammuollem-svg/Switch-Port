// FILE: vc_test.sv
`timescale 1ns/1ps

// ----------------------------------------------------------------------
// vc_test.sv
// Unit Test: Single Port Verification Component
// Validates the functionality of the Packet VC, Agent, and Interface
// on a single port before full system integration.
// ----------------------------------------------------------------------
module vc_test;
	import packet_pkg::*;

	// ------------------------------------------------------------------
	// Clock & Reset Generation
	// ------------------------------------------------------------------
	bit clk = 0;
	always #5 clk = ~clk; 
	bit rst_n;

	// ------------------------------------------------------------------
	// Interface & DUT Instantiation
	// Note: We instantiate all 4 ports but only actively drive Port 0.
	// ------------------------------------------------------------------
	port_if port0(clk, rst_n);
	port_if port1(clk, rst_n);
	port_if port2(clk, rst_n);
	port_if port3(clk, rst_n);

	switch_4port dut(
		.clk   (clk),
		.rst_n (rst_n),
		.port0 (port0),
		.port1 (port1),
		.port2 (port2),
		.port3 (port3)
	);

	// ------------------------------------------------------------------
	// Verification Components
	// ------------------------------------------------------------------
	packet_vc  vc0;
	checkerr   scb; 

	// ------------------------------------------------------------------
	// Main Test Sequence
	// ------------------------------------------------------------------
	initial begin
		$display("[%0t] [VC_TEST] Building Environment...", $time);
		
		// 1. Environment Construction
		scb = new("scb", null);
		vc0 = new("vc0", null);

		// 2. Configuration (Targeting Port 0)
		vc0.configure(port0, 0, scb);

		// 3. System Reset
		rst_n = 0; 
		repeat(5) @(posedge clk); 
		rst_n = 1;
		repeat(2) @(posedge clk); 

		$display("[%0t] [VC_TEST] Starting Simulation...", $time);
		
		// 4. Start Background Processes
		fork scb.run(); join_none

		// 5. Run Stimulus (Single VC)
		// Drive 20 packets to verify basic connectivity
		fork
			vc0.run(20); 
		join_none
		
		// ----------------------------------------------------------------
		// Drain Phase
		// Waits for all pending packets to traverse the DUT.
		// Implements a stability counter to ensure complete flushing.
		// ----------------------------------------------------------------
		$display("[%0t] [VC_TEST] Draining packets...", $time);
		begin
			int drain_cycles = 0;
			int max_cycles = 200000; // Timeout safety (2ms at 100MHz)
			bit done = 0;
			int consecutive_zero_count = 0;
			int last_remaining = -1;
			
			while (!done && drain_cycles < max_cycles) begin
				@(posedge clk);
				drain_cycles++;
				
				// Monitor total pending packets across all scoreboard queues
				int total_remaining = scb.expected_q[0].size() +
									 scb.expected_q[1].size() +
									 scb.expected_q[2].size() +
									 scb.expected_q[3].size();
				
				// Stability Check: Ensure count remains zero for stable duration
				if (total_remaining == 0) begin
					consecutive_zero_count++;
				end else begin
					consecutive_zero_count = 0;
				end
				
				// Exit condition: 500 consecutive cycles of empty queues
				if (consecutive_zero_count >= 500) begin
					done = 1;
					$display("[%0t] [VC_TEST] ✓ Drain complete after %0d cycles (stable for %0d cycles)", 
							 $time, drain_cycles, consecutive_zero_count);
				end
				
				// Periodic Status Updates
				if (drain_cycles % 20000 == 0 && total_remaining > 0) begin
					$display("[%0t] [VC_TEST] Still draining... %0d packets remaining (%0d cycles)", 
							 $time, total_remaining, drain_cycles);
				end
				
				if (total_remaining != last_remaining && total_remaining > 0) begin
					if (drain_cycles % 5000 == 0) begin
						$display("[%0t] [VC_TEST] Progress: %0d packets remaining", 
								 $time, total_remaining);
					end
					last_remaining = total_remaining;
				end
			end
			
			if (!done) begin
				int final_remaining = scb.expected_q[0].size() + 
									 scb.expected_q[1].size() +
									 scb.expected_q[2].size() + 
									 scb.expected_q[3].size();
				$warning("[VC_TEST] Timeout: %0d packets still expected after %0d cycles!", 
						 final_remaining, drain_cycles);
			end
		end
		
		// Post-Drain Settling Time
		// Allows monitors to capture any final latent signals
		$display("[%0t] [VC_TEST] Final settling phase...", $time);
		repeat(500) @(posedge clk); 
		$display("[%0t] [VC_TEST] Settling complete", $time);
		
		// 6. Final Reporting
		if (scb != null) scb.report();
		
		// Automated Pass/Fail Check
		begin
			int total_drops = scb.expected_q[0].size() + scb.expected_q[1].size() +
							 scb.expected_q[2].size() + scb.expected_q[3].size();
			
			$display("\n" + {"="} * 80);
			if (total_drops == 0 && scb.total_errors == 0) begin
				$display("VC_TEST: ✓✓✓ PASSED (100%%) ✓✓✓");
				$display("  All packets correctly routed with no drops!");
			end else begin
				$display("VC_TEST: Status Report");
				if (total_drops > 0) begin
					$display("  Drops: %0d packets", total_drops);
				end
				if (scb.total_errors > 0) begin
					$display("  Errors: %0d routing errors", scb.total_errors);
				end
			end
			$display({"="} * 80 + "\n");
		end
		
		$finish;
	end
endmodule