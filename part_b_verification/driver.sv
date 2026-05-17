`ifndef DRIVER_SV
`define DRIVER_SV

// ----------------------------------------------------------------------
// driver.sv
// Packet Driver Component
// Responsible for retrieving packets from the sequencer and driving them
// into the DUT via the virtual interface.
// ----------------------------------------------------------------------
class driver extends component_base;
	
	// Interface and Component Handles
	virtual port_if vif;
	sequencer seq;
	checkerr scb; 
	int port_idx;
	
	// Configuration Flags
	bit stress_mode = 0; 
	
	// ------------------------------------------------------------------
	// Constructor
	// ------------------------------------------------------------------
	function new(string n, component_base p=null);
		super.new(n, p);
	endfunction
	
	// ------------------------------------------------------------------
	// Task: run
	// Main execution loop. Drives 'num_packets' into the DUT.
	// Handles backpressure and reports transactions to the scoreboard.
	// ------------------------------------------------------------------
	task run(int num_packets = 0);
		packet p;
		bit sent_ok;
		int packets_sent = 0;
		int packets_dropped = 0;
		
		// Validation
		if (vif == null) $fatal(1, "[%s] Virtual Interface (vif) is NULL", pathname());
		if (seq == null) $fatal(1, "[%s] Sequencer handle is NULL", pathname());
		
		// 1. Initialization
		vif.valid_in  <= 1'b0;
		vif.source_in <= 4'b0000;
		vif.target_in <= 4'b0000;
		vif.data_in   <= 8'h00;
		
		// 2. Wait for Reset Release
		wait(vif.rst_n === 1'b1);
		@(posedge vif.clk);
		
		// Initial random delay to desynchronize drivers
		repeat($urandom_range(1, 50)) @(posedge vif.clk);
		
		// 3. Main Transmission Loop
		repeat(num_packets) begin
			
			// Wait for downstream readiness (Backpressure handling)
			// Loops until the DUT asserts ready_out.
			while (1) begin
				if (vif.ready_out === 1'b1) break;
				@(posedge vif.clk);
				#1; // Delay to ensure reading stable signal
			end
			
			// Retrieve next transaction
			seq.get_next_item(p);
			
			// Drive packet to interface
			vif.drive_packet(p, sent_ok);
			
			// Register with Scoreboard
			if (sent_ok) begin
				if (scb != null) scb.add_expected(p);
				packets_sent++;
			end else begin
				packets_dropped++;
			end
			
			// Inter-packet Delay
			// Adjusts throughput based on stress mode configuration.
			if (stress_mode) begin
				repeat($urandom_range(0, 2)) @(posedge vif.clk);
			end else begin
				repeat($urandom_range(5, 10)) @(posedge vif.clk); 
			end
		end
		
		$display("[%0t] [%s] Driver finished: %0d sent.", $time, pathname(), packets_sent);
	endtask

endclass
`endif