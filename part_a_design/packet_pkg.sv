`ifndef PACKET_PKG_SV
`define PACKET_PKG_SV
`timescale 1ns/1ps
// Global Constants
`define NUM_PORTS 4
`define PAYLOAD_WIDTH 8
`define ADDR_WIDTH 4
`define PACKET_WIDTH 16

package packet_pkg;
	parameter int NUM_PORTS     = `NUM_PORTS;
	parameter int PAYLOAD_WIDTH = `PAYLOAD_WIDTH;
	parameter int ADDR_WIDTH    = `ADDR_WIDTH;
	parameter int PACKET_WIDTH  = `PACKET_WIDTH;

	typedef enum {
		SINGLE_DESTINATION,
		MULTICAST,
		BROADCAST
	} packet_type_e;      

	typedef enum bit [ADDR_WIDTH-1:0] {
		PORT_0 = 4'b0001,
		PORT_1 = 4'b0010,
		PORT_2 = 4'b0100,
		PORT_3 = 4'b1000
	} port_addr_e;

	// --- MUST BE UNCOMMENTED FOR COMPILATION ---
	// FIXED: Added ./ to help Euclide find the file
	`include "/project/verif/users/weaammoallem/ws/ex_vlsi_3/packet_data.sv"	

endpackage
`endif