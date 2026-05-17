`timescale 1ns/1ps
`ifndef PORT_IF_SV
`define PORT_IF_SV

import packet_pkg::*; 

// ----------------------------------------------------------------------
// port_if.sv
// Switch Port Interface - STAGE C GLS VERSION
// Defines the signal bundle and BFM (Bus Functional Model) tasks for
// driving and monitoring a single switch port with timing robustness. [cite: 205]
// ----------------------------------------------------------------------
interface port_if (input bit clk, input bit rst_n);
	
	// ------------------------------------------------------------------
	// Signal Definitions
	// ------------------------------------------------------------------

	// Input Bus (Stimulus to DUT)
	logic        valid_in;    
	logic [3:0] source_in;   
	logic [3:0] target_in;   
	logic [7:0] data_in;     
	
	// Output Bus (Response from DUT)
	logic        valid_out;   
	logic [3:0] source_out;  
	logic [3:0] target_out;  
	logic [7:0] data_out;    
	logic        ready_out;   // Backpressure from DUT (High = Ready to accept) [cite: 27]
	
	// Downstream Flow Control
	logic        ready_in;    // Backpressure to DUT (High = Monitor ready)
	logic        pop_in;      // Read enable for DUT output FIFO [cite: 27]
	
	// ------------------------------------------------------------------
	// Signal Initialization
	// ------------------------------------------------------------------
	initial begin
		valid_in  = 1'b0;
		source_in = 4'b0000;
		target_in = 4'b0000;
		data_in   = 8'h00;
		ready_in  = 1'b1; 
		pop_in    = 1'b0; 
	end
	
	// ------------------------------------------------------------------
	// Task: drive_packet
	// Drives a packet onto the bus and handles the ready/valid handshake.
	// Updated with #2ns delay to ensure stability against gate delays. [cite: 247]
	// ------------------------------------------------------------------
	task automatic drive_packet(input packet p, output bit sent_ok);
		sent_ok = 0;

		// Ensure system is out of reset [cite: 131]
		while (rst_n !== 1'b1) @(posedge clk);

		// 1. Setup Data Phase
		valid_in  <= 1'b0;
		@(posedge clk);
		valid_in  <= 1'b1;
		source_in <= p.source;
		target_in <= p.target;
		data_in   <= p.data;

		// 2. Handshake Phase
		forever begin
			@(posedge clk);
			
			// Sampling delay increased for Gate-Level Simulation (GLS).
			// This allows the gate-level logic to propagate through the netlist
			// before we check the ready_out signal.
			#2; 

			// Abort if reset occurs during transmission [cite: 148]
			if (rst_n !== 1'b1) begin
				valid_in <= 1'b0;
				sent_ok  = 0;
				return;
			end

			// Check for acceptance
			if (ready_out === 1'b1) begin
				valid_in <= 1'b0;
				sent_ok  = 1;
				return;
			end
		end
	endtask

	// ------------------------------------------------------------------
	// Task: collect_packet
	// Blocks until valid output data is available.
	// Includes sampling delay to wait for post-synthesis gate transitions. [cite: 247]
	// ------------------------------------------------------------------
	task automatic collect_packet(output packet p);
		// Wait for Valid assertion from the DUT [cite: 149]
		while (valid_out !== 1'b1) begin
			@(posedge clk);
		end
		
		// Wait for signal stabilization after gate-level propagation
		#2;
		
		// Reconstruct and sample the observed packet data [cite: 181]
		p = new("monitored", 0); // Constructor per Stage B spec [cite: 107]
		p.source = source_out;
		p.target = target_out;
		p.data   = data_out;
	endtask

endinterface
`endif