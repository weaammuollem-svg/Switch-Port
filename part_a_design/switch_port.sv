module switch_port #(
	parameter DATA_WIDTH = 16,
	parameter FIFO_DEPTH = 4
)(
	input  logic        clk,
	input  logic        rst_n,

	input  logic        valid_in,
	input  logic [3:0]  source_in,
	input  logic [3:0]  target_in,
	input  logic [7:0]  data_in,

	output logic        valid_out,
	output logic [3:0]  source_out,
	output logic [3:0]  target_out,
	output logic [7:0]  data_out,

	output logic        ready_out,   
	input  logic        pop_in
);

	logic [DATA_WIDTH-1:0] mem [FIFO_DEPTH-1:0];
	logic [$clog2(FIFO_DEPTH):0]   count;
	logic [$clog2(FIFO_DEPTH)-1:0] wr_ptr, rd_ptr;

	wire full  = (count == FIFO_DEPTH);
	wire empty = (count == 0);

	assign ready_out = !full;       
	assign valid_out = !empty;

	assign {data_out, target_out, source_out} = mem[rd_ptr];
	wire [DATA_WIDTH-1:0] write_data = {data_in, target_in, source_in};

	wire write_en = valid_in && !full;
	wire read_en  = pop_in   && !empty;

	always_ff @(posedge clk) begin
		if (!rst_n) begin
			count  <= 0;
			wr_ptr <= 0;
			rd_ptr <= 0;
		end else begin
			if (write_en) begin
				mem[wr_ptr] <= write_data;
				wr_ptr <= wr_ptr + 1;
			end
			if (read_en) begin
				rd_ptr <= rd_ptr + 1;
			end
			case ({write_en, read_en})
				2'b10: count <= count + 1;
				2'b01: count <= count - 1;
				default: count <= count;
			endcase
		end
	end
endmodule