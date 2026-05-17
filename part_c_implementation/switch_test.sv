`timescale 1ns/1ps

// ----------------------------------------------------------------------
// switch_test.sv
// GLS regression top for Stage C
// ----------------------------------------------------------------------
module switch_test;
	import packet_pkg::*;

	// --- Clock/Reset ---
	bit clk = 0;
	always #5 clk = ~clk; // 100MHz 
	bit rst_n;

	// ------------------------------------------------------------------
	// Timing Annotation (SDF)
	// ------------------------------------------------------------------
	initial begin
		// Load gate delays for the 'dut' instance
		$display("[%0t] [SDF] Loading netlist timing...", $time);
		$sdf_annotate("switch_4port.sdf", dut); 
	end

	// --- Port IFs ---
	port_if port0(clk, rst_n);
	port_if port1(clk, rst_n);
	port_if port2(clk, rst_n);
	port_if port3(clk, rst_n);

	// ------------------------------------------------------------------
	// DUT: Netlist mapping
	// ------------------------------------------------------------------
	switch_4port dut (
		.clk(clk), .rst_n(rst_n),

		// Port 0 
		.p0_valid_in(port0.valid_in),   .p0_source_in(port0.source_in),
		.p0_target_in(port0.target_in), .p0_data_in(port0.data_in),
		.p0_ready_out(port0.ready_out), .p0_valid_out(port0.valid_out),
		.p0_source_out(port0.source_out), .p0_target_out(port0.target_out),
		.p0_data_out(port0.data_out),   .p0_ready_in(port0.ready_in),

		// Port 1 
		.p1_valid_in(port1.valid_in),   .p1_source_in(port1.source_in),
		.p1_target_in(port1.target_in), .p1_data_in(port1.data_in),
		.p1_ready_out(port1.ready_out), .p1_valid_out(port1.valid_out),
		.p1_source_out(port1.source_out), .p1_target_out(port1.target_out),
		.p1_data_out(port1.data_out),   .p1_ready_in(port1.ready_in),

		// Port 2 
		.p2_valid_in(port2.valid_in),   .p2_source_in(port2.source_in),
		.p2_target_in(port2.target_in), .p2_data_in(port2.data_in),
		.p2_ready_out(port2.ready_out), .p2_valid_out(port2.valid_out),
		.p2_source_out(port2.source_out), .p2_target_out(port2.target_out),
		.p2_data_out(port2.data_out),   .p2_ready_in(port2.ready_in),

		// Port 3 
		.p3_valid_in(port3.valid_in),   .p3_source_in(port3.source_in),
		.p3_target_in(port3.target_in), .p3_data_in(port3.data_in), 
		.p3_ready_out(port3.ready_out), .p3_valid_out(port3.valid_out),
		.p3_source_out(port3.source_out), .p3_target_out(port3.target_out),
		.p3_data_out(port3.data_out),   .p3_ready_in(port3.ready_in)
	);

	// --- VCs and Scoreboard ---
	packet_vc vc0, vc1, vc2, vc3;
	checkerr scb; 

	// ------------------------------------------------------------------
	// Coverage
	// ------------------------------------------------------------------
	covergroup switch_coverage @(posedge clk);
		option.per_instance = 1;
		option.name = "Switch_Cov";

		// Packet Distribution
		cp_type: coverpoint {scb.cnt_uni, scb.cnt_multi, scb.cnt_bcast} {
			bins seen_unicast   = {[1:$]} iff (scb.cnt_uni > 50);
			bins seen_multicast = {[1:$]} iff (scb.cnt_multi > 50);
			bins seen_broadcast = {[1:$]} iff (scb.cnt_bcast > 50);
		}

		// Ready bit monitoring
		cp_ready_in_0: coverpoint port0.ready_in {
			bins always_ready = {1};
			bins stalled      = {0};
		}
	endgroup

	switch_coverage cov;

	// ------------------------------------------------------------------
	// Main Loop
	// ------------------------------------------------------------------
	initial begin
		cov = new();
		scb = new("scb", null);
		vc0 = new("vc0", null); vc1 = new("vc1", null);
		vc2 = new("vc2", null); vc3 = new("vc3", null);
		
		vc0.configure(port0, 0, scb); vc1.configure(port1, 1, scb);
		vc2.configure(port2, 2, scb); vc3.configure(port3, 3, scb);

		// Reset toggle
		rst_n = 0; repeat(20) @(posedge clk); 
		rst_n = 1; repeat(10) @(posedge clk);

		fork scb.run(); join_none
		vc0.start_monitor(); vc1.start_monitor();
		vc2.start_monitor(); vc3.start_monitor();
		
		$display("\n" + {"="} * 80);
		$display("STARTING GLS REGRESSION (SDF ON)");
		$display({"="} * 80);
		
		$fsdbDumpfile("novas.fsdb");
		$fsdbDumpvars(0, switch_test);

		// --- TEST 1: Basic Sanity ---
		$display("TEST 1: SANITY");
		vc0.agt.mon.stop_backpressure=1; vc1.agt.mon.stop_backpressure=1;
		vc2.agt.mon.stop_backpressure=1; vc3.agt.mon.stop_backpressure=1;
		fork vc0.run_driver(25); vc1.run_driver(25); vc2.run_driver(25); vc3.run_driver(25); join
		run_drain("TEST 1");

		// --- TEST 2: Flow Control ---
		$display("TEST 2: RANDOM BACKPRESSURE");
		vc0.agt.mon.stop_backpressure=0; vc1.agt.mon.stop_backpressure=0;
		vc2.agt.mon.stop_backpressure=0; vc3.agt.mon.stop_backpressure=0;
		fork vc0.run_driver(500); vc1.run_driver(500); vc2.run_driver(500); vc3.run_driver(500); join
		run_drain("TEST 2");

		// --- TEST 3: Stress ---
		$display("TEST 3: SATURATION");
		vc0.agt.drv.stress_mode=1; vc1.agt.drv.stress_mode=1;
		vc2.agt.drv.stress_mode=1; vc3.agt.drv.stress_mode=1;
		fork vc0.run_driver(750); vc1.run_driver(750); vc2.run_driver(750); vc3.run_driver(750); join
		run_drain("TEST 3");

		repeat(5000) @(posedge clk);
		scb.report();
		$display("\nFINAL COVERAGE: %.2f%%", cov.get_coverage());
		$finish;
	end
	
	// Flush DUT between tests
	task run_drain(string test_name);
		int drain_cycles = 0;
		int stable_count = 0;
		bit drain_complete = 0;
		int total_remaining;
		
		vc0.agt.mon.stop_backpressure = 1; vc1.agt.mon.stop_backpressure = 1;
		vc2.agt.mon.stop_backpressure = 1; vc3.agt.mon.stop_backpressure = 1;
		
		while (!drain_complete && drain_cycles < 10000) begin
			@(posedge clk);
			drain_cycles++;
			total_remaining = scb.get_backlog();
			if (total_remaining == 0) begin
				stable_count++;
				if (stable_count >= 1000) drain_complete = 1;
			end else stable_count = 0;
		end
		
		vc0.agt.mon.stop_backpressure = 0; vc1.agt.mon.stop_backpressure = 0;
		vc2.agt.mon.stop_backpressure = 0; vc3.agt.mon.stop_backpressure = 0;
		vc0.agt.mon.ready_weight = 80; vc1.agt.mon.ready_weight = 80;
		vc2.agt.mon.ready_weight = 80; vc3.agt.mon.ready_weight = 80;
		$display("[%0t] [DRAIN] %s done.\n", $time, test_name);
	endtask

endmodule