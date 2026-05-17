`ifndef PACKET_DATA_SV
`define PACKET_DATA_SV

// ----------------------------------------------------------------------
// packet_data.sv
// Packet Data Definitions
// Defines the transaction object, its types, and constraint classes.
// ----------------------------------------------------------------------

// ----------------------------------------------------------------------
// Enumeration: Packet Category
// ----------------------------------------------------------------------
typedef enum { 
	SINGLE_DESTINATION, 
	MULTICAST, 
	BROADCAST 
} packet_type_e;


// ----------------------------------------------------------------------
// Class: packet
// Base transaction class representing a data packet in the switch.
// ----------------------------------------------------------------------
class packet;

	// --- Protocol Fields ---
	logic [3:0] source;          // Input port (One-Hot encoded)
	rand logic [3:0] target;     // Destination mask (One-Hot or Bitmap)
	rand logic [7:0] data;       // Payload data
	packet_type_e p_type;

	// --- Meta-data & Bookkeeping ---
	static int count = 0;        // Global instance counter
	int tag;                     // Unique ID for tracking
	string name;

	// ------------------------------------------------------------------
	// Constraints
	// ------------------------------------------------------------------

	// Ensure destination is valid (non-zero)
	constraint c_target_valid {
		target != 4'b0000;
	}

	// Prevent loopback: Source cannot be a target (unless Broadcast)
	constraint c_anti_source {
		if (p_type != BROADCAST)
			(target & source) == 4'b0000;
	}

	// ------------------------------------------------------------------
	// Constructor
	// Initializes the packet, assigns a unique tag, and sets source encoding.
	// ------------------------------------------------------------------
	function new(string n = "pkt", int port_idx = 0);
		name = n;
		tag  = count++;

		// Encode integer port index to one-hot source
		if (port_idx >= 0 && port_idx < 4)
			source = 4'b0001 << port_idx;
		else
			source = 4'b0000;
	endfunction

	// ------------------------------------------------------------------
	// Method: clone
	// Creates a deep copy of the current packet object.
	// Required for scoreboard storage to prevent reference issues.
	// ------------------------------------------------------------------
	function packet clone();
		packet c = new(this.name);
		c.source = this.source;
		c.target = this.target;
		c.data   = this.data;
		c.p_type = this.p_type;
		c.tag    = this.tag;
		return c;
	endfunction

	// ------------------------------------------------------------------
	// Method: to_string
	// Returns a formatted string representation of the packet fields.
	// ------------------------------------------------------------------
	function string to_string();
		return $sformatf(
			"Tag=%0d Type=%s Src=%b Tgt=%b Data=%02h",
			tag, p_type.name(), source, target, data
		);
	endfunction

	// ------------------------------------------------------------------
	// Method: display
	// Prints the packet details to the console with a timestamp.
	// ------------------------------------------------------------------
	virtual function void display(string prefix = "PKT");
		$display("[%0t] %s: %s", $time, prefix, to_string());
	endfunction

endclass


// ----------------------------------------------------------------------
// Class: unicast_packet
// Specialized packet for single destination targets.
// ----------------------------------------------------------------------
class unicast_packet extends packet;

	function new(string n = "uni", int port_idx = 0);
		super.new(n, port_idx);
		p_type = SINGLE_DESTINATION;
	endfunction

	// Constraint: Exactly one bit set in target
	constraint c_unicast {
		$countones(target) == 1;
	}

endclass


// ----------------------------------------------------------------------
// Class: multicast_packet
// Specialized packet for multiple (2-3) destinations.
// ----------------------------------------------------------------------
class multicast_packet extends packet;

	function new(string n = "multi", int port_idx = 0);
		super.new(n, port_idx);
		p_type = MULTICAST;
	endfunction

	// Constraint: 2 or 3 bits set in target
	constraint c_multicast {
		$countones(target) inside {[2:3]};
	}

endclass


// ----------------------------------------------------------------------
// Class: broadcast_packet
// Specialized packet for all-port transmission.
// ----------------------------------------------------------------------
class broadcast_packet extends packet;

	function new(string n = "bcast", int port_idx = 0);
		super.new(n, port_idx);
		p_type = BROADCAST;
	endfunction

	// Constraint: All bits set in target
	constraint c_broadcast {
		target == 4'b1111;
	}

endclass

`endif