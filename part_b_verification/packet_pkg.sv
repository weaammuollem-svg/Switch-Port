`timescale 1ns/1ps
`ifndef PACKET_PKG_SV
`define PACKET_PKG_SV

// ----------------------------------------------------------------------
// packet_pkg.sv
// Verification Package
// Aggregates all verification classes, types, and constants into a
// single namespace to simplify compilation and usage.
// ----------------------------------------------------------------------
package packet_pkg;

	// ------------------------------------------------------------------
	// Global Parameters
	// ------------------------------------------------------------------
	parameter NUM_PORTS = 4;

	// ------------------------------------------------------------------
	// Forward Typedefs
	// Resolves cyclic dependencies by declaring class types before
	// their full definitions are loaded.
	// ------------------------------------------------------------------
	typedef class packet;
	typedef class unicast_packet;
	typedef class multicast_packet;
	typedef class broadcast_packet;
	
	typedef class component_base;
	typedef class checkerr;
	typedef class monitor;
	typedef class driver;
	typedef class sequencer;
	typedef class agent;
	typedef class packet_vc;

	// ------------------------------------------------------------------
	// Core Definitions
	// Data objects and foundational classes.
	// ------------------------------------------------------------------
	`include "packet_data.sv"
	`include "component_base.sv"

	// ------------------------------------------------------------------
	// Component Definitions
	// Note: Inclusion order is critical for dependency resolution.
	// ------------------------------------------------------------------
	`include "checker.sv"
	`include "sequencer.sv"
	`include "driver.sv"
	`include "monitor.sv"
	`include "agent.sv"
	`include "packet_vc.sv"

endpackage : packet_pkg

`endif