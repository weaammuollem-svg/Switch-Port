`ifndef PACKET_VC_SV
`define PACKET_VC_SV

// ----------------------------------------------------------------------
// packet_vc.sv
// Packet Verification Component (VC)
// Top-level container for a single port's verification logic. 
// Wraps the agent and provides high-level control methods.
// ----------------------------------------------------------------------
class packet_vc extends component_base;
	
	// Internal Agent Handle
	agent agt;

	// ------------------------------------------------------------------
	// Constructor
	// Initializes the VC and instantiates the encapsulated agent.
	// ------------------------------------------------------------------
	function new(string n, component_base p=null);
		super.new(n, p);
		agt = new("agt", this);
	endfunction

	// ------------------------------------------------------------------
	// Method: configure
	// Passes configuration data (interface, port index, scoreboard) down
	// to the agent.
	// ------------------------------------------------------------------
	function void configure(virtual port_if v, int idx, checkerr scb_h);
		agt.configure(v, idx, scb_h);
	endfunction

	// ------------------------------------------------------------------
	// Task: start_monitor
	// Starts the monitor thread in the background (non-blocking).
	// ------------------------------------------------------------------
	task start_monitor();
		fork 
			agt.mon.run(); 
		join_none
	endtask

	// ------------------------------------------------------------------
	// Task: run_driver
	// Direct call to execute the driver sequence (blocking).
	// ------------------------------------------------------------------
	task run_driver(int num_packets);
		agt.drv.run(num_packets);
	endtask

	// ------------------------------------------------------------------
	// Task: run
	// Main execution method used by testbenches.
	// Launches the monitor in parallel and executes the driver sequence.
	// ------------------------------------------------------------------
	task run(int num_packets);
		// Start monitor in background thread
		fork
			agt.mon.run();
		join_none
		
		// Run driver (blocks until completion)
		agt.drv.run(num_packets);
	endtask

endclass
`endif