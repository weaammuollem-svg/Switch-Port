`timescale 1ns/1ps
`ifndef PORT_IF_SV
`define PORT_IF_SV

import packet_pkg::*; 

// ----------------------------------------------------------------------
// port_if.sv
// Switch Port Interface
// Defines the signal bundle and BFM (Bus Functional Model) tasks for
// driving and monitoring a single switch port.
// ----------------------------------------------------------------------
interface port_if (input bit clk, input bit rst_n);
	
	// ------------------------------------------------------------------
	// Signal Definitions
	// ------------------------------------------------------------------

	// Input Bus (Stimulus to DUT)
	logic       valid_in;    
	logic [3:0] source_in;   
	logic [3:0] target_in;   
	logic [7:0] data_in;     
	
	// Output Bus (Response from DUT)
	logic       valid_out;   
	logic [3:0] source_out;  
	logic [3:0] target_out;  
	logic [7:0] data_out;    
	logic       ready_out;   // Backpressure from DUT (High = Ready to accept)
	
	// Downstream Flow Control
	logic       ready_in;    // Backpressure to DUT (High = Monitor ready)
	logic       pop_in;      // Read enable for DUT output FIFO
	
	// ------------------------------------------------------------------
	// Signal Initialization
	// Sets default idle states to prevent X-propagation at start 0.
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
	// Bus Functional Model (BFM) for packet injection.
	// Drives a packet onto the bus and handles the ready/valid handshake.
	// ------------------------------------------------------------------
	task automatic drive_packet(input packet p, output bit sent_ok);
		sent_ok = 0;

		// Ensure system is out of reset
		while (rst_n !== 1'b1) @(posedge clk);

		// 1. Setup Data Phase
		valid_in  <= 1'b0;
		@(posedge clk);
		valid_in  <= 1'b1;
		source_in <= p.source;
		target_in <= p.target;
		data_in   <= p.data;

		// 2. Handshake Phase
		// Hold valid high until the DUT asserts ready_out.
		forever begin
			@(posedge clk);
			
			// Post-clock delay required to sample stable RTL signals 
			// after logic updates (avoids race conditions).
			#1; 

			// Abort if reset occurs during transmission
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
			// If ready_out is low, valid_in remains high for next cycle
		end
	endtask

	// ------------------------------------------------------------------
	// Task: collect_packet
	// BFM for packet observation.
	// Blocks until valid output data is available.
	// ------------------------------------------------------------------
	task automatic collect_packet(output packet p);
		// Wait for Valid assertion
		while (valid_out !== 1'b1) begin
			@(posedge clk);
		end
		
		// Sample Data
		p = new("monitored");
		p.source = source_out;
		p.target = target_out;
		p.data   = data_out;
	endtask

endinterface
`endif