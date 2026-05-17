// ----------------------------------------------------------------------
// switch_4port.sv
// Top-Level 4-Port Switch RTL
// ----------------------------------------------------------------------
`timescale 1ns/1ps

module switch_4port #(
    parameter NUM_PORTS = 4
)(
    // Global Clock and Reset
    input  logic        clk,
    input  logic        rst_n,

    // Port 0 Interface
    input  logic        p0_valid_in,
    input  logic [3:0]  p0_source_in,
    input  logic [3:0]  p0_target_in,
    input  logic [7:0]  p0_data_in,
    output logic        p0_ready_out,
    output logic        p0_valid_out,
    output logic [3:0]  p0_source_out,
    output logic [3:0]  p0_target_out,
    output logic [7:0]  p0_data_out,
    input  logic        p0_ready_in,

    // Port 1 Interface
    input  logic        p1_valid_in,
    input  logic [3:0]  p1_source_in,
    input  logic [3:0]  p1_target_in,
    input  logic [7:0]  p1_data_in,
    output logic        p1_ready_out,
    output logic        p1_valid_out,
    output logic [3:0]  p1_source_out,
    output logic [3:0]  p1_target_out,
    output logic [7:0]  p1_data_out,
    input  logic        p1_ready_in,

    // Port 2 Interface
    input  logic        p2_valid_in,
    input  logic [3:0]  p2_source_in,
    input  logic [3:0]  p2_target_in,
    input  logic [7:0]  p2_data_in,
    output logic        p2_ready_out,
    output logic        p2_valid_out,
    output logic [3:0]  p2_source_out,
    output logic [3:0]  p2_target_out,
    output logic [7:0]  p2_data_out,
    input  logic        p2_ready_in,

    // Port 3 Interface
    input  logic        p3_valid_in,
    input  logic [3:0]  p3_source_in,
    input  logic [3:0]  p3_target_in,
    input  logic [7:0]  p3_data_in,
    output logic        p3_ready_out,
    output logic        p3_valid_out,
    output logic [3:0]  p3_source_out,
    output logic [3:0]  p3_target_out,
    output logic [7:0]  p3_data_out,
    input  logic        p3_ready_in
);

    // Main FSM States
    typedef enum logic [1:0] {
        S_IDLE     = 2'b00,
        S_ROUTE    = 2'b01,
        S_TRANSMIT = 2'b10
    } state_e;
    
    state_e current_state, next_state;

    // Internal bus and arbiter signals
    logic [NUM_PORTS-1:0] p_valid, p_pop;
    logic [3:0] p_src [NUM_PORTS];
    logic [3:0] p_tgt [NUM_PORTS];
    logic [7:0] p_dat [NUM_PORTS];

    logic [NUM_PORTS-1:0][3:0] granted_src, granted_tgt;
    logic [NUM_PORTS-1:0][7:0] granted_dat;

    // Output Stage Pipeline Registers
    logic [NUM_PORTS-1:0] out_valid_reg;
    logic [3:0] out_src_reg [NUM_PORTS];
    logic [3:0] out_tgt_reg [NUM_PORTS];
    logic [7:0] out_dat_reg [NUM_PORTS];

    logic [NUM_PORTS-1:0] port_ready_in_bus;
    logic [NUM_PORTS-1:0] port_ready_out_bus;

    // Arbitration and Multicast Control
    logic [1:0] rr_ptr [NUM_PORTS];
    logic [3:0] pending_mask [NUM_PORTS];

    // Function to calculate target mask while enforcing anti-source rule
    function automatic logic [3:0] calc_final_target(
        input logic [3:0] pending,
        input logic [3:0] tgt,
        input integer      src_idx
    );
        logic [3:0] raw;
        raw = (pending != 4'b0000) ? pending : tgt;
        // Do not route back to the source port
        calc_final_target = raw & ~(4'b0001 << src_idx);
    endfunction

    // ------------------------------------------------------------------
    // Ingress Port Instances (Input Buffering)
    // ------------------------------------------------------------------
    switch_port sp0 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(p0_valid_in), .source_in(p0_source_in),
        .target_in(p0_target_in), .data_in(p0_data_in),
        .valid_out(p_valid[0]), .source_out(p_src[0]),
        .target_out(p_tgt[0]), .data_out(p_dat[0]),
        .ready_out(port_ready_out_bus[0]), .pop_in(p_pop[0])
    );
    
    switch_port sp1 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(p1_valid_in), .source_in(p1_source_in),
        .target_in(p1_target_in), .data_in(p1_data_in),
        .valid_out(p_valid[1]), .source_out(p_src[1]),
        .target_out(p_tgt[1]), .data_out(p_dat[1]),
        .ready_out(port_ready_out_bus[1]), .pop_in(p_pop[1])
    );
    
    switch_port sp2 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(p2_valid_in), .source_in(p2_source_in),
        .target_in(p2_target_in), .data_in(p2_data_in),
        .valid_out(p_valid[2]), .source_out(p_src[2]),
        .target_out(p_tgt[2]), .data_out(p_dat[2]),
        .ready_out(port_ready_out_bus[2]), .pop_in(p_pop[2])
    );
    
    switch_port sp3 (
        .clk(clk), .rst_n(rst_n),
        .valid_in(p3_valid_in), .source_in(p3_source_in),
        .target_in(p3_target_in), .data_in(p3_data_in),
        .valid_out(p_valid[3]), .source_out(p_src[3]),
        .target_out(p_tgt[3]), .data_out(p_dat[3]),
        .ready_out(port_ready_out_bus[3]), .pop_in(p_pop[3])
    );

    // Grouping port handshake signals
    assign port_ready_in_bus = {p3_ready_in, p2_ready_in, p1_ready_in, p0_ready_in};
    assign p0_ready_out = port_ready_out_bus[0];
    assign p1_ready_out = port_ready_out_bus[1];
    assign p2_ready_out = port_ready_out_bus[2];
    assign p3_ready_out = port_ready_out_bus[3];

    // ------------------------------------------------------------------
    // Control Logic: State Machine and Registers
    // ------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
            for (integer i=0; i<NUM_PORTS; i++) begin
                rr_ptr[i]        <= 2'b00;
                pending_mask[i]  <= 4'b0000;
                out_valid_reg[i] <= 1'b0;
                out_src_reg[i]   <= 4'b0000;
                out_tgt_reg[i]   <= 4'b0000;
                out_dat_reg[i]   <= 8'h00;
            end
        end else begin
            current_state <= next_state;

            if (current_state == S_ROUTE || current_state == S_TRANSMIT) begin
                for (integer i=0; i<NUM_PORTS; i++) begin
                    // Shift round-robin pointer on successful transfer
                    if (out_valid_reg[i] && port_ready_in_bus[i] && granted_src[i] != 4'b0000) begin
                        rr_ptr[i] <= rr_ptr[i] + 1'b1;
                    end

                    // Data pipeline registers
                    out_valid_reg[i] <= (granted_src[i] != 4'b0000);
                    out_src_reg[i]   <= granted_src[i];
                    out_tgt_reg[i]   <= granted_tgt[i];
                    out_dat_reg[i]   <= granted_dat[i];

                    // Multicast logic: update mask as targets are served
                    if (p_valid[i]) begin
                        logic [3:0] current_mask;
                        current_mask = (pending_mask[i] == 4'b0000) ? p_tgt[i] : pending_mask[i];
                        current_mask &= ~(4'b0001 << i); 

                        for (integer out_idx=0; out_idx<NUM_PORTS; out_idx++) begin
                            if (granted_src[out_idx] == (4'b0001 << i) && port_ready_in_bus[out_idx]) begin
                                current_mask[out_idx] = 1'b0; 
                            end
                        end
                        pending_mask[i] <= current_mask;
                    end else begin
                        pending_mask[i] <= 4'b0000;
                    end
                end
            end else begin
                out_valid_reg <= 4'b0000;
            end
        end
    end

    // Assigning reg values to output ports
    assign p0_valid_out  = out_valid_reg[0];  assign p0_source_out = out_src_reg[0];
    assign p0_target_out = out_tgt_reg[0];    assign p0_data_out   = out_dat_reg[0];
    assign p1_valid_out  = out_valid_reg[1];  assign p1_source_out = out_src_reg[1];
    assign p1_target_out = out_tgt_reg[1];    assign p1_data_out   = out_dat_reg[1];
    assign p2_valid_out  = out_valid_reg[2];  assign p2_source_out = out_src_reg[2];
    assign p2_target_out = out_tgt_reg[2];    assign p2_data_out   = out_dat_reg[2];
    assign p3_valid_out  = out_valid_reg[3];  assign p3_source_out = out_src_reg[3];
    assign p3_target_out = out_tgt_reg[3];    assign p3_data_out   = out_dat_reg[3];

    // ------------------------------------------------------------------
    // Combinational Logic: Arbitration
    // ------------------------------------------------------------------
    always_comb begin
        integer i, out, k, inp;
        logic [3:0] final_target;
        logic [3:0] mask_after_service;
        logic all_empty;

        // Default signal states
        next_state = current_state;
        p_pop = 4'b0000;
        granted_src = 16'h0000;
        granted_tgt = 16'h0000;
        granted_dat = 32'h00000000;

        case (current_state)
            S_IDLE: next_state = (|p_valid) ? S_ROUTE : S_IDLE;

            S_ROUTE, S_TRANSMIT: begin
                all_empty = 1'b1;

                // Arbiter loop for each egress port
                for (out=0; out<NUM_PORTS; out++) begin
                    logic granted_this_port;
                    granted_this_port = 1'b0;
                    
                    for (k=0; k<NUM_PORTS; k++) begin
                        inp = (rr_ptr[out] + k) % NUM_PORTS;
                        
                        if (p_valid[inp] && !granted_this_port) begin
                            all_empty = 1'b0;
                            final_target = calc_final_target(pending_mask[inp], p_tgt[inp], inp);
                            
                            if (final_target[out] && port_ready_in_bus[out]) begin
                                granted_src[out] = p_src[inp];
                                granted_tgt[out] = p_tgt[inp];
                                granted_dat[out] = p_dat[inp];
                                granted_this_port = 1'b1;
                            end
                        end
                    end
                end

                // Pop logic: clear input FIFO if all destinations have been served
                for (i=0; i<NUM_PORTS; i++) begin
                    if (p_valid[i]) begin
                        mask_after_service = calc_final_target(pending_mask[i], p_tgt[i], i);
                        for (out=0; out<NUM_PORTS; out++) begin
                            if (granted_src[out] == (4'b0001 << i))
                                mask_after_service[out] = 1'b0;
                        end
                        if (mask_after_service == 4'b0000) p_pop[i] = 1'b1;
                    end
                end

                next_state = (all_empty && !(|granted_src)) ? S_IDLE : S_TRANSMIT;
            end
            default: next_state = S_IDLE;
        endcase
    end

endmodule