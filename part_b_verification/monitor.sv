`ifndef MONITOR_SV
`define MONITOR_SV

// ----------------------------------------------------------------------
// monitor.sv
// Packet Monitor Component
// Observes output traffic from the DUT, manages backpressure (ready_in),
// and reports received packets to the scoreboard.
// ----------------------------------------------------------------------
class monitor extends component_base;
	
	// Interface and Component Handles
	virtual port_if vif;
	int port_idx;
	checkerr scb;
	
	// Configuration & Control Flags
	bit stop_backpressure = 0; // If set, Monitor always asserts ready (Drain Mode)
	int ready_weight      = 80; // Probability (0-100%) of asserting ready in normal operation
	
	// Internal State
	bit last_pop_asserted;
	bit packet_accepted;

	// ------------------------------------------------------------------
	// Constructor
	// ------------------------------------------------------------------
	function new(string n, component_base p=null);
		super.new(n, p);
		last_pop_asserted = 0;
		packet_accepted   = 0;
	endfunction
	
	// ------------------------------------------------------------------
	// Task: run
	// Continuous loop that drives backpressure signals and samples outputs.
	// ------------------------------------------------------------------
	task run(int num_packets = 0);
		packet p_rcv;
		
		// Validation
		if (vif == null) $fatal(1, "[%s] Virtual Interface (vif) is NULL", pathname());
		
		// 1. Initialization
		vif.ready_in <= 1'b1;
		vif.pop_in   <= 1'b0;
		
		// 2. Wait for Reset Release
		wait(vif.rst_n === 1'b1);
		@(posedge vif.clk);
		
		// 3. Main Operational Loop
		forever begin
			
			// --- Phase A: Drive Backpressure (Pre-Clock) ---
			if (stop_backpressure) begin
				// Drain Mode: Always accept data
				vif.ready_in <= 1'b1; 
			end else begin
				// Normal Mode: Apply random backpressure based on weight
				vif.ready_in <= ($urandom_range(0,99) < ready_weight) ? 1'b1 : 1'b0;
			end

			// --- Phase B: Sample DUT Output (Post-Clock) ---
			@(posedge vif.clk);
			#1; // Delay to ensure signal stability
			
			if (vif.valid_out === 1'b1) begin
				
				// Packet Capture Logic:
				// Capture if this is a fresh packet (popped previously) 
				// or if it's the first time seeing this unpopped packet.
				if (last_pop_asserted || !packet_accepted) begin
					p_rcv = new($sformatf("mon_p%0d", port_idx), port_idx);
					p_rcv.source = vif.source_out;
					p_rcv.target = vif.target_out;
					p_rcv.data   = vif.data_out;
					
					// Send to Scoreboard
					if (scb != null) scb.check_actual(p_rcv, port_idx);
					
					packet_accepted = 1;
				end
				
				// Pop Logic:
				// Assert pop if we previously signaled ready_in.
				if (stop_backpressure || vif.ready_in) begin
					vif.pop_in <= 1'b1;
					last_pop_asserted = 1;
				end else begin
					vif.pop_in <= 1'b0;
					last_pop_asserted = 0;
				end
				
			end else begin
				// No valid data present
				vif.pop_in <= 1'b0;
				last_pop_asserted = 0;
				packet_accepted   = 0;
			end
		end
	endtask
	
endclass
`endif