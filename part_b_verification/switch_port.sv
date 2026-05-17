// FILE: switch_port.sv
`timescale 1ns/1ps

// ----------------------------------------------------------------------
// switch_port.sv
// Input Port Module with FIFO Buffering
// Buffers incoming packets to decouple input timing from internal switching.
// ----------------------------------------------------------------------
module switch_port #(
	parameter DATA_WIDTH = 16,
	parameter FIFO_DEPTH = 32 // Depth increased to 32 to absorb hotspot bursts
)(
	// Clock and Reset
	input  logic        clk,
	input  logic        rst_n,

	// Input Interface (Upstream)
	input  logic        valid_in,
	input  logic [3:0]  source_in,
	input  logic [3:0]  target_in,
	input  logic [7:0]  data_in,
	output logic        ready_out,   // Backpressure to upstream

	// Output Interface (Downstream to Arbiter)
	output logic        valid_out,   // Request to arbiter
	output logic [3:0]  source_out,
	output logic [3:0]  target_out,
	output logic [7:0]  data_out,
	input  logic        pop_in       // Read enable from arbiter
);

	// ------------------------------------------------------------------
	// Internal Memory & Pointers
	// ------------------------------------------------------------------
	logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];
	logic [$clog2(FIFO_DEPTH):0]   count;
	logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr, rd_ptr;
	
	// Status Flags
	wire full  = (count == FIFO_DEPTH);
	wire empty = (count == 0);
	
	// ------------------------------------------------------------------
	// Interface Logic
	// ------------------------------------------------------------------
	assign ready_out = !full;       
	assign valid_out = !empty;
	
	// Read Data Path (Combinational output from current read pointer)
	assign {data_out, target_out, source_out} = mem[rd_ptr];
	
	// ------------------------------------------------------------------
	// FIFO Control Logic
	// ------------------------------------------------------------------
	wire [DATA_WIDTH-1:0] write_data = {data_in, target_in, source_in};
	wire write_en = valid_in && !full;
	wire read_en  = pop_in   && !empty;
	
	always_ff @(posedge clk) begin
		if (!rst_n) begin
			count  <= 0;
			wr_ptr <= 0;
			rd_ptr <= 0;
		end else begin
			// Write Operation
			if (write_en) begin
				mem[wr_ptr] <= write_data;
				wr_ptr <= wr_ptr + 1;
			end
			
			// Read Operation
			if (read_en) begin
				rd_ptr <= rd_ptr + 1;
			end
			
			// Counter Updates
			case ({write_en, read_en})
				2'b10: count <= count + 1; // Push only
				2'b01: count <= count - 1; // Pop only
				default: count <= count;   // Push+Pop or Idle
			endcase
		end
	end

endmodule