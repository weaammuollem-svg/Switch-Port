`define BROADCAST_TGT 4'b1111

module switch_4port #(
	parameter NUM_PORTS = 4
)(
	input  logic clk,
	input  logic rst_n,
	port_if port0,
	port_if port1,
	port_if port2,
	port_if port3
);
	import packet_pkg::*;

	typedef enum {S_IDLE, S_ROUTE, S_TRANSMIT} state_e;
	state_e current_state, next_state;

	logic [NUM_PORTS-1:0] p_valid, p_pop;

	logic [3:0] p_src [NUM_PORTS];
	logic [3:0] p_tgt [NUM_PORTS];
	logic [7:0] p_dat [NUM_PORTS];

	logic [NUM_PORTS-1:0][3:0] granted_src, granted_tgt;
	logic [NUM_PORTS-1:0][7:0] granted_dat;

	logic [NUM_PORTS-1:0] out_valid_reg;
	logic [3:0] out_src_reg [NUM_PORTS];
	logic [3:0] out_tgt_reg [NUM_PORTS];
	logic [7:0] out_dat_reg [NUM_PORTS];

	// env ready to accept switch outputs
	logic [NUM_PORTS-1:0] port_ready_in;

	// switch_port backpressure to env (no-drop)
	logic [NUM_PORTS-1:0] port_ready_out;

	logic [1:0] rr_ptr [NUM_PORTS];
	logic [3:0] pending_mask [NUM_PORTS];

	// --- function: pending priority + anti-source except broadcast ---
	function automatic logic [3:0] calc_final_target(
		input logic [3:0] pending,
		input logic [3:0] tgt,
		input int         src_idx
	);
		logic [3:0] raw;
		raw = (pending != 0) ? pending : tgt;

		if (raw == `BROADCAST_TGT)
			calc_final_target = raw;
		else
			calc_final_target = raw & ~(4'b0001 << src_idx);
	endfunction

	// --------------------------------------------------------
	// 1) Input FIFOs
	// --------------------------------------------------------
	switch_port sp0 (
		.clk(clk), .rst_n(rst_n),
		.valid_in(port0.valid_in),
		.source_in(port0.source_in),
		.target_in(port0.target_in),
		.data_in(port0.data_in),
		.valid_out(p_valid[0]),
		.source_out(p_src[0]),
		.target_out(p_tgt[0]),
		.data_out(p_dat[0]),
		.ready_out(port_ready_out[0]),
		.pop_in(p_pop[0])
	);

	switch_port sp1 (
		.clk(clk), .rst_n(rst_n),
		.valid_in(port1.valid_in),
		.source_in(port1.source_in),
		.target_in(port1.target_in),
		.data_in(port1.data_in),
		.valid_out(p_valid[1]),
		.source_out(p_src[1]),
		.target_out(p_tgt[1]),
		.data_out(p_dat[1]),
		.ready_out(port_ready_out[1]),
		.pop_in(p_pop[1])
	);

	switch_port sp2 (
		.clk(clk), .rst_n(rst_n),
		.valid_in(port2.valid_in),
		.source_in(port2.source_in),
		.target_in(port2.target_in),
		.data_in(port2.data_in),
		.valid_out(p_valid[2]),
		.source_out(p_src[2]),
		.target_out(p_tgt[2]),
		.data_out(p_dat[2]),
		.ready_out(port_ready_out[2]),
		.pop_in(p_pop[2])
	);

	switch_port sp3 (
		.clk(clk), .rst_n(rst_n),
		.valid_in(port3.valid_in),
		.source_in(port3.source_in),
		.target_in(port3.target_in),
		.data_in(port3.data_in),
		.valid_out(p_valid[3]),
		.source_out(p_src[3]),
		.target_out(p_tgt[3]),
		.data_out(p_dat[3]),
		.ready_out(port_ready_out[3]),
		.pop_in(p_pop[3])
	);

	// --------------------------------------------------------
	// 2) ready mapping
	// --------------------------------------------------------
	assign port_ready_in[0] = port0.ready_in;
	assign port_ready_in[1] = port1.ready_in;
	assign port_ready_in[2] = port2.ready_in;
	assign port_ready_in[3] = port3.ready_in;

	// Backpressure to env: no-drop guarantee
	assign port0.ready_out = port_ready_out[0];
	assign port1.ready_out = port_ready_out[1];
	assign port2.ready_out = port_ready_out[2];
	assign port3.ready_out = port_ready_out[3];

	// --------------------------------------------------------
	// 3) Sequential: registers + pending mask + rr_ptr
	// --------------------------------------------------------
	always_ff @(posedge clk) begin
		int i, out;
		logic [3:0] current;

		if (!rst_n) begin
			current_state <= S_IDLE;
			for (i=0; i<NUM_PORTS; i++) begin
				rr_ptr[i]        <= 0;
				pending_mask[i]  <= 0;
				out_valid_reg[i] <= 0;
			end
		end else begin
			current_state <= next_state;

			if (current_state inside {S_ROUTE, S_TRANSMIT}) begin
				for (i=0; i<NUM_PORTS; i++) begin
					// advance rr only if we actually output on that port
					if (out_valid_reg[i]) rr_ptr[i] <= rr_ptr[i] + 1;

					out_valid_reg[i] <= (granted_src[i] != 0);
					out_src_reg[i]   <= granted_src[i];
					out_tgt_reg[i]   <= granted_tgt[i];
					out_dat_reg[i]   <= granted_dat[i];

					if (p_valid[i]) begin
						current = (pending_mask[i] == 0) ? p_tgt[i] : pending_mask[i];

						// anti-source unless broadcast
						if (current != `BROADCAST_TGT)
							current &= ~(4'b0001 << i);

						// clear destinations we served this cycle (only if grant came from this input i)
						for (out=0; out<NUM_PORTS; out++) begin
							if (granted_src[out] == (4'b0001 << i))
								current[out] = 1'b0;
						end

						pending_mask[i] <= p_pop[i] ? 4'b0000 : current;
					end else begin
						pending_mask[i] <= 0;
					end
				end
			end else begin
				out_valid_reg <= '0;
			end
		end
	end

	// --------------------------------------------------------
	// 4) Drive outputs
	// --------------------------------------------------------
	assign port0.valid_out  = out_valid_reg[0];
	assign port0.source_out = out_src_reg[0];
	assign port0.target_out = out_tgt_reg[0];
	assign port0.data_out   = out_dat_reg[0];

	assign port1.valid_out  = out_valid_reg[1];
	assign port1.source_out = out_src_reg[1];
	assign port1.target_out = out_tgt_reg[1];
	assign port1.data_out   = out_dat_reg[1];

	assign port2.valid_out  = out_valid_reg[2];
	assign port2.source_out = out_src_reg[2];
	assign port2.target_out = out_tgt_reg[2];
	assign port2.data_out   = out_dat_reg[2];

	assign port3.valid_out  = out_valid_reg[3];
	assign port3.source_out = out_src_reg[3];
	assign port3.target_out = out_tgt_reg[3];
	assign port3.data_out   = out_dat_reg[3];

	// --------------------------------------------------------
	// 5) Combinational: next state + arbitration + pop logic
	// --------------------------------------------------------
	always_comb begin
		int i, out, k, inp;
		logic [3:0] final_target;
		logic [3:0] mask_after_service;
		bit granted;
		logic all_empty;

		next_state = current_state;

		for (i=0; i<NUM_PORTS; i++) begin
			p_pop[i]       = 0;
			granted_src[i] = 0;
			granted_tgt[i] = 0;
			granted_dat[i] = 0;
		end

		case (current_state)
			S_IDLE: begin
				next_state = (|p_valid) ? S_ROUTE : S_IDLE;
			end

			S_ROUTE, S_TRANSMIT: begin
				all_empty = 1;

				// arbitration per output
				for (out=0; out<NUM_PORTS; out++) begin
					granted = 0;

					for (k=0; k<NUM_PORTS; k++) begin
						inp = (rr_ptr[out] + k) % NUM_PORTS;

						if (p_valid[inp]) begin
							all_empty = 0;

							if (!granted) begin
								final_target = calc_final_target(pending_mask[inp], p_tgt[inp], inp);

								if (final_target[out] && port_ready_in[out]) begin
									granted_src[out] = p_src[inp];
									granted_tgt[out] = p_tgt[inp];
									granted_dat[out] = p_dat[inp];
									granted          = 1;
								end
							end
						end
					end
				end

				// Completion Logic
				for (i=0; i<NUM_PORTS; i++) begin
					if (p_valid[i]) begin
						mask_after_service = calc_final_target(pending_mask[i], p_tgt[i], i);

						for (out=0; out<NUM_PORTS; out++) begin
							if (granted_src[out] == (4'b0001 << i))
								mask_after_service[out] = 1'b0;
						end

						if (mask_after_service == 4'b0000)
							p_pop[i] = 1;
					end
				end

				next_state = (all_empty && !(|granted_src)) ? S_IDLE : S_TRANSMIT;
			end
		endcase
	end

endmodule