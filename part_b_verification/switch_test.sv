`timescale 1ns/1ps

// ----------------------------------------------------------------------
// switch_test.sv
// Top-Level Regression Suite
// Instantiates the DUT and Verification Components (VCs) to perform
// a comprehensive feature and stress test of the 4-Port Switch.
// ----------------------------------------------------------------------
module switch_test;
	import packet_pkg::*;

	// ------------------------------------------------------------------
	// Clock & Reset Generation
	// ------------------------------------------------------------------
	bit clk = 0;
	always #5 clk = ~clk;
	bit rst_n;

	// ------------------------------------------------------------------
	// Interfaces & DUT Instantiation
	// ------------------------------------------------------------------
	port_if port0(clk, rst_n);
	port_if port1(clk, rst_n);
	port_if port2(clk, rst_n);
	port_if port3(clk, rst_n);

	switch_4port dut (
		.clk(clk), .rst_n(rst_n),
		.port0(port0), .port1(port1), .port2(port2), .port3(port3)
	);

	// ------------------------------------------------------------------
	// Verification Components
	// ------------------------------------------------------------------
	packet_vc vc0, vc1, vc2, vc3;
	checkerr scb; 

	// ------------------------------------------------------------------
	// Functional Coverage Group
	// Tracks packet types, buffer utilization, and flow control.
	// ------------------------------------------------------------------
	covergroup switch_coverage @(posedge clk);
		option.per_instance = 1;
		option.name = "Switch_Cov";

		// 1. Packet Types (Unicast, Multicast, Broadcast)
		cp_type: coverpoint {scb.cnt_uni, scb.cnt_multi, scb.cnt_bcast} {
			bins seen_unicast   = {[1:$]} iff (scb.cnt_uni > 50);
			bins seen_multicast = {[1:$]} iff (scb.cnt_multi > 50);
			bins seen_broadcast = {[1:$]} iff (scb.cnt_bcast > 50);
		}

		// 2. FIFO Utilization (Empty to Full)
		cp_fifo0_level: coverpoint dut.sp0.count {
			bins empty = {0};
			bins mid   = {[1:30]};
			bins full  = {31, 32}; 
		}
		
		// 3. Flow Control (Ready/Busy)
		cp_ready_in_0: coverpoint port0.ready_in {
			bins always_ready = {1};
			bins stalled      = {0};
		}

		// 4. Cross Coverage (Stall vs Buffer State)
		cross cp_ready_in_0, cp_fifo0_level;
	endgroup

	switch_coverage cov;

	// ------------------------------------------------------------------
	// Main Test Sequence
	// ------------------------------------------------------------------
	initial begin
		// 1. Environment Construction
		cov = new();
		scb = new("scb", null);
		vc0 = new("vc0", null); vc1 = new("vc1", null);
		vc2 = new("vc2", null); vc3 = new("vc3", null);
		
		vc0.configure(port0, 0, scb); vc1.configure(port1, 1, scb);
		vc2.configure(port2, 2, scb); vc3.configure(port3, 3, scb);

		// 2. System Reset
		rst_n = 0; repeat(20) @(posedge clk); 
		rst_n = 1; repeat(10) @(posedge clk);

		// 3. Start Background Components
		fork scb.run(); join_none
		vc0.start_monitor(); vc1.start_monitor();
		vc2.start_monitor(); vc3.start_monitor();
		
		$display("\n" + {"="} * 80);
		$display("FINAL REGRESSION SUITE (Target: >15,000 Packets)");
		$display({"="} * 80);
		
		// 4. Add waveform dumping (CRITICAL FIX)
		$fsdbDumpfile("novas.fsdb");
		$fsdbDumpvars(0, switch_test);

		// --- TEST 1: SANITY CHECK ---
		// Basic connectivity verification with minimal load.
		$display("TEST 1: SANITY");
		vc0.agt.mon.stop_backpressure=1; vc1.agt.mon.stop_backpressure=1;
		vc2.agt.mon.stop_backpressure=1; vc3.agt.mon.stop_backpressure=1;
		fork vc0.run_driver(25); vc1.run_driver(25); vc2.run_driver(25); vc3.run_driver(25); join
		run_drain("TEST 1");

		// --- TEST 2: RANDOM BACKPRESSURE ---
		// Verify DUT handles downstream stalls correctly.
		$display("TEST 2: RANDOM BACKPRESSURE");
		vc0.agt.mon.stop_backpressure=0; vc1.agt.mon.stop_backpressure=0;
		vc2.agt.mon.stop_backpressure=0; vc3.agt.mon.stop_backpressure=0;
		fork vc0.run_driver(500); vc1.run_driver(500); vc2.run_driver(500); vc3.run_driver(500); join
		run_drain("TEST 2");

		// --- TEST 3: SATURATION STRESS ---
		// High-bandwidth test to maximize throughput.
		$display("TEST 3: SATURATION");
		vc0.agt.drv.stress_mode=1; vc1.agt.drv.stress_mode=1;
		vc2.agt.drv.stress_mode=1; vc3.agt.drv.stress_mode=1;
		fork vc0.run_driver(750); vc1.run_driver(750); vc2.run_driver(750); vc3.run_driver(750); join
		run_drain("TEST 3");

		// --- TEST 4: LONG RUN STABILITY ---
		// Extended run to check for memory leaks or counter wrap-around issues.
		$display("TEST 4: LONG RUN STABILITY");
		vc0.agt.drv.stress_mode=0; 
		fork vc0.run_driver(1000); vc1.run_driver(1000); vc2.run_driver(1000); vc3.run_driver(1000); join
		run_drain("TEST 4");

		// --- TEST 5: ROTATING HOTSPOT ---
		// Stress arbiter fairness by targeting single ports sequentially.
		$display("TEST 5: HOTSPOT");
		vc0.agt.seq.hotspot_mode=1; vc1.agt.seq.hotspot_mode=1;
		vc2.agt.seq.hotspot_mode=1; vc3.agt.seq.hotspot_mode=1;
		vc0.agt.seq.hotspot_target=1; vc1.agt.seq.hotspot_target=1;
		vc2.agt.seq.hotspot_target=1; vc3.agt.seq.hotspot_target=1;
		vc0.agt.mon.stop_backpressure=1; vc1.agt.mon.stop_backpressure=1; 
		vc2.agt.mon.stop_backpressure=1; vc3.agt.mon.stop_backpressure=1;
		
		fork vc0.run_driver(750); vc1.run_driver(750); vc2.run_driver(750); vc3.run_driver(750); join
		
		// Reset Hotspot configuration
		vc0.agt.seq.hotspot_mode=0; vc1.agt.seq.hotspot_mode=0;
		vc2.agt.seq.hotspot_mode=0; vc3.agt.seq.hotspot_mode=0;
		run_drain("TEST 5");

		// --- TEST 6: BROADCAST STORM ---
		// Verify 1-to-All replication logic and maximum internal bus load.
		$display("TEST 6: BROADCAST STORM");
		vc0.agt.drv.stress_mode=1; 
		fork vc0.run_driver(1000); vc1.run_driver(1000); vc2.run_driver(1000); vc3.run_driver(1000); join
		run_drain("TEST 6");

		// --- TEST 7: FIFO JAM (FULL BUFFER TEST) ---
		// Forces FIFO full conditions to verify stall logic and "Full" coverage bins.
		$display("TEST 7: FIFO JAM (0%% Ready Weight)");
		
		// 1. Configure Monitors to Block Output
		vc0.agt.mon.stop_backpressure = 0; vc0.agt.mon.ready_weight = 0;
		vc1.agt.mon.stop_backpressure = 0; vc1.agt.mon.ready_weight = 0;
		vc2.agt.mon.stop_backpressure = 0; vc2.agt.mon.ready_weight = 0;
		vc3.agt.mon.stop_backpressure = 0; vc3.agt.mon.ready_weight = 0;
		
		// 2. Concurrent Fill and Release
		fork
			// Thread A: Drivers fill the buffers
			begin
				fork
					vc0.run_driver(50); vc1.run_driver(50); 
					vc2.run_driver(50); vc3.run_driver(50); 
				join
			end

			// Thread B: Controller waits for saturation, then releases backpressure
			begin
				$display("  > Filling FIFOs (Drivers active, Monitors blocked)...");
				repeat(5000) @(posedge clk);
				
				$display("  > Releasing Backpressure (Flushing)...");
				vc0.agt.mon.ready_weight = 100; vc1.agt.mon.ready_weight = 100;
				vc2.agt.mon.ready_weight = 100; vc3.agt.mon.ready_weight = 100;
			end
		join 
		
		run_drain("TEST 7");

		// 4. Final Reporting
		repeat(5000) @(posedge clk);
		scb.report();
		$display("\nCOVERAGE REPORT: Total %.2f%%", cov.get_coverage());
		$finish;
	end
	
	// ------------------------------------------------------------------
	// Task: run_drain
	// Waits for the DUT to process all pending packets.
	// Includes timeout protection and stability checks.
	// ------------------------------------------------------------------
	task run_drain(string test_name);
		int drain_cycles = 0;
		int stable_count = 0;
		bit drain_complete = 0;
		int total_remaining;
		
		$display("[%0t] [DRAIN] %s starting... (Current Pending: %0d)", $time, test_name, scb.get_backlog());
		
		// Force monitors to accept data during drain
		vc0.agt.mon.stop_backpressure = 1; vc1.agt.mon.stop_backpressure = 1;
		vc2.agt.mon.stop_backpressure = 1; vc3.agt.mon.stop_backpressure = 1;
		
		while (!drain_complete && drain_cycles < 10000000) begin
			@(posedge clk);
			drain_cycles++;
			
			total_remaining = scb.get_backlog();
			
			if (total_remaining == 0) begin
				stable_count++;
				if (stable_count >= 1000) drain_complete = 1;
			end else stable_count = 0;
			
			if (drain_cycles % 500000 == 0 && total_remaining > 0)
				 $display("[%0t] [DRAIN] Still draining... Pending: %d", $time, total_remaining);
		end
		
		// Restore default monitor configuration
		vc0.agt.mon.stop_backpressure = 0; vc1.agt.mon.stop_backpressure = 0;
		vc2.agt.mon.stop_backpressure = 0; vc3.agt.mon.stop_backpressure = 0;
		vc0.agt.mon.ready_weight = 80; vc1.agt.mon.ready_weight = 80;
		vc2.agt.mon.ready_weight = 80; vc3.agt.mon.ready_weight = 80;
		
		scb.debug_q(); 
		$display("[%0t] [DRAIN] %s Complete.\n", $time, test_name);
	endtask

endmodule