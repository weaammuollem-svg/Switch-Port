`timescale 1ns/1ps
`ifndef AGENT_SV
`define AGENT_SV

// ----------------------------------------------------------------------
// agent.sv
// Verification Agent
// Encapsulates the Sequencer, Driver, and Monitor for a single port.
// ----------------------------------------------------------------------
class agent extends component_base;

	// Verification Components
	sequencer seq;
	driver    drv;
	monitor   mon;

	// Configuration
	int port_idx;
	virtual port_if vif;

	// ------------------------------------------------------------------
	// Constructor
	// Initializes the agent and instantiates its sub-components.
	// ------------------------------------------------------------------
	function new(string n, component_base p=null);
		super.new(n, p);
		
		seq = new("seq", this);
		drv = new("drv", this);
		mon = new("mon", this);
	endfunction

	// ------------------------------------------------------------------
	// Configure
	// Connects the sub-components to the physical interface and scoreboard.
	// ------------------------------------------------------------------
	function void configure(virtual port_if v, int idx, checkerr scb_h);
		this.vif      = v;
		this.port_idx = idx;

		// Configure Sequencer
		if (seq != null) begin
			seq.set_port_idx(idx);
		end

		// Connect Driver to Interface, Sequencer, and Scoreboard
		if (drv != null) begin
			drv.vif      = v;
			drv.port_idx = idx;
			drv.seq      = seq;
			drv.scb      = scb_h; 
		end

		// Connect Monitor to Interface and Scoreboard
		if (mon != null) begin
			mon.vif      = v;
			mon.port_idx = idx;
			mon.scb      = scb_h; 
		end
	endfunction

	// ------------------------------------------------------------------
	// Run
	// Starts the driver and monitor threads in the background.
	// ------------------------------------------------------------------
	task run(int num_packets = 0);
		if (port_idx < 0) begin
			$display("[%0t] [AGENT] Warning: port_idx not configured for %s", $time, pathname());
		end

		// Launch components in parallel non-blocking threads
		fork
			if (mon != null) mon.run();
			if (drv != null) drv.run(num_packets); 
		join_none
	endtask

endclass

`endif