// FILE: testForStageA.sv
// MODULE: testForStageA
// DESCRIPTION: Stage A Directed Testing Environment with Self-Checking Scoreboard
// ----------------------------------------------------------------------

`timescale 1ns/1ps

module testForStageA; 
    import packet_pkg::*;
    
    // ----------------------------------------------------------------------
    // SCOREBOARD & GLOBAL VARIABLES
    // ----------------------------------------------------------------------
    // Golden reference queues to store expected packets for data integrity verification
    packet expected_q[4][$]; 
    
    // Global error counter to track data corruption or protocol violations
    int error_count = 0;

    // ----------------------------------------------------------------------
    // 1. SIGNAL GENERATION & INTERFACES
    // ----------------------------------------------------------------------
    bit clk = 0;    
    always #5 clk = ~clk;    
    
    bit rst_n;
    
    port_if port0(clk, rst_n);
    port_if port1(clk, rst_n);
    port_if port2(clk, rst_n);
    port_if port3(clk, rst_n);
    
    // ----------------------------------------------------------------------
    // 2. DUT INSTANTIATION
    // ----------------------------------------------------------------------
    switch_4port dut(
        .clk  (clk),
        .rst_n(rst_n),
        .port0(port0),
        .port1(port1),
        .port2(port2),
        .port3(port3)
    );

    // ----------------------------------------------------------------------
    // 3. DRIVER TASKS
    // ----------------------------------------------------------------------
    
    // TASK: drive_packet_on_port
    // Purpose: Generates a packet, registers it in the scoreboard, and drives it to the DUT.
    task automatic drive_packet_on_port(
        input int          port_idx,
        input logic [3:0]  src, 
        input logic [3:0]  tgt,
        input logic [7:0]  dat
    );
        // Create new packet, passing port_idx to set the source
        packet p = new($sformatf("pkt_p%0d", port_idx), port_idx); 
        p.target = tgt;
        p.data   = dat;

        // --- SCOREBOARD REGISTRATION ---
        // Push a deep copy of the packet to the expected queue for every target port.
        // This establishes the "Golden Reference" for the output monitor.
        for (int i=0; i<4; i++) begin
            if (tgt[i]) begin 
                packet p_copy = new p; 
                expected_q[i].push_back(p_copy); 
            end
        end

        // Drive the packet on the requested interface
        case (port_idx)
            0: port0.drive_packet(p);
            1: port1.drive_packet(p);
            2: port2.drive_packet(p);
            3: port3.drive_packet(p);
        endcase
    endtask

    // TASK: run_basic_tests
    // Purpose: Executes the sequence of directed tests defined for Stage A.
    task run_basic_tests;
        
        $display("\n[%0t] TEST 1: Sending Unicast (Src=0 -> Tgt=1)", $time);
        drive_packet_on_port(0, 4'b0001, 4'b0010, 8'hAA);
        repeat(10) @(posedge clk);

        $display("\n[%0t] TEST 2: Sending Multicast (Src=1 -> Tgt={0,3})", $time);
        drive_packet_on_port(1, 4'b0010, 4'b1001, 8'hBB);
        repeat(20) @(posedge clk);

        $display("\n[%0t] TEST 3: Sending Broadcast (Src=2 -> All)", $time);
        drive_packet_on_port(2, 4'b0100, 4'b1111, 8'hCC);
        repeat(20) @(posedge clk);

        $display("\n[%0t] TEST 4: Concurrent Arrivals (Src=0->2 & Src=1->3)", $time);
        fork
            drive_packet_on_port(0, 4'b0001, 4'b0100, 8'hD1);
            drive_packet_on_port(1, 4'b0010, 4'b1000, 8'hD2);
        join
        repeat(20) @(posedge clk);

        $display("\n[%0t] TEST 5: Back-to-Back Packets", $time);
        fork
            drive_packet_on_port(0, 4'b0001, 4'b0010, 8'hE1);
            begin
                repeat(2) @(posedge clk);
                drive_packet_on_port(1, 4'b0010, 4'b0100, 8'hE2);
            end
        join
        repeat(20) @(posedge clk);

        $display("\n[%0t] TEST 6: Output Contention (0->2 and 1->2)", $time);
        fork
            drive_packet_on_port(0, 4'b0001, 4'b0100, 8'hF1);      
            drive_packet_on_port(1, 4'b0010, 4'b0100, 8'hF2);      
        join
        repeat(20) @(posedge clk);

        $display("\n[%0t] TEST 7: Anti-Source Check (0 -> {0,1})", $time);
        drive_packet_on_port(0, 4'b0001, 4'b0011, 8'h99);      
        repeat(50) @(posedge clk);
        
        // TEST 8: Data Integrity Verification (Randomized Stress Test)
        $display("\n[%0t] TEST 8: Data Integrity Stress Test (Random Payload)", $time);
        // Sends multiple randomized packets to verify no data corruption occurs
        for (int i=0; i<10; i++) begin
            drive_packet_on_port(0, 4'b0001, 4'b1000, $urandom_range(0, 255));
            #20; 
        end
        repeat(50) @(posedge clk); // Allow time for all packets to drain

        // Final Verification Result
        if (error_count == 0)
            $display("\n>>> [PASSED] ALL TESTS COMPLETED SUCCESSFULLY. NO DATA CORRUPTION. <<<");
        else
            $display("\n>>> [FAILED] %0d ERRORS DETECTED DURING SIMULATION. <<<", error_count);

    endtask
    
    // ----------------------------------------------------------------------
    // 4. MAIN EXECUTION BLOCK
    // ----------------------------------------------------------------------
    initial begin
        // Initialize inputs
        port0.valid_in = 0;
        port1.valid_in = 0;
        port2.valid_in = 0;
        port3.valid_in = 0;

        // All outputs are considered ready (simple flow control for Stage A)
        port0.ready_in = 1'b1;
        port1.ready_in = 1'b1;
        port2.ready_in = 1'b1;
        port3.ready_in = 1'b1;

        // Reset sequence
        rst_n = 0;    
        repeat(3) @(posedge clk);    
        rst_n = 1;
        $display("=== [%0t] Reset Release ===", $time);

        // Call the encapsulated tests
        run_basic_tests();
        
        $display("\n=== [%0t] Simulation Complete ===", $time);
        $finish;
    end

    // ----------------------------------------------------------------------
    // 5. OUTPUT MONITOR & SELF-CHECKER
    // ----------------------------------------------------------------------
    initial begin
        fork
            // --- Monitor Port 0 ---
            forever begin 
                automatic packet p_rcv; 
                automatic packet p_exp;
                
                port0.collect_packet(p_rcv); 
                p_rcv.display("Port 0 Output");

                // Scoreboard Check
                if (expected_q[0].size() > 0) begin
                    p_exp = expected_q[0].pop_front();
                    if (p_rcv.data !== p_exp.data) begin
                        $error("[SCB] DATA CORRUPTION on Port 0! Exp: %h, Got: %h", p_exp.data, p_rcv.data);
                        error_count++;
                    end
                end else begin
                    $error("[SCB] UNEXPECTED PACKET on Port 0!");
                    error_count++;
                end
            end
            
            // --- Monitor Port 1 ---
            forever begin 
                automatic packet p_rcv; 
                automatic packet p_exp;
                
                port1.collect_packet(p_rcv); 
                p_rcv.display("Port 1 Output");

                // Scoreboard Check
                if (expected_q[1].size() > 0) begin
                    p_exp = expected_q[1].pop_front();
                    if (p_rcv.data !== p_exp.data) begin
                        $error("[SCB] DATA CORRUPTION on Port 1! Exp: %h, Got: %h", p_exp.data, p_rcv.data);
                        error_count++;
                    end
                end else begin
                    $error("[SCB] UNEXPECTED PACKET on Port 1!");
                    error_count++;
                end
            end
            
            // --- Monitor Port 2 ---
            forever begin 
                automatic packet p_rcv; 
                automatic packet p_exp;
                
                port2.collect_packet(p_rcv); 
                p_rcv.display("Port 2 Output");

                // Scoreboard Check
                if (expected_q[2].size() > 0) begin
                    p_exp = expected_q[2].pop_front();
                    if (p_rcv.data !== p_exp.data) begin
                        $error("[SCB] DATA CORRUPTION on Port 2! Exp: %h, Got: %h", p_exp.data, p_rcv.data);
                        error_count++;
                    end
                end else begin
                    $error("[SCB] UNEXPECTED PACKET on Port 2!");
                    error_count++;
                end
            end
            
            // --- Monitor Port 3 ---
            forever begin 
                automatic packet p_rcv; 
                automatic packet p_exp;
                
                port3.collect_packet(p_rcv); 
                p_rcv.display("Port 3 Output");

                // Scoreboard Check
                if (expected_q[3].size() > 0) begin
                    p_exp = expected_q[3].pop_front();
                    if (p_rcv.data !== p_exp.data) begin
                        $error("[SCB] DATA CORRUPTION on Port 3! Exp: %h, Got: %h", p_exp.data, p_rcv.data);
                        error_count++;
                    end
                end else begin
                    $error("[SCB] UNEXPECTED PACKET on Port 3!");
                    error_count++;
                end
            end
        join_none
    end

endmodule