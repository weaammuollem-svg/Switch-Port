`ifndef PACKET_DATA_SV
`define PACKET_DATA_SV

// This class will be included in packet_pkg.sv

class packet;
	// 1. Data Fields 
	logic [3:0] source;
	logic [3:0] target;
	logic [7:0] data;
	
	packet_type_e p_type; 

	static int count = 0;
	
	int tag; 

	// 2. ID
	string name;

	// 3. Constructor
	function new(string n = "pkt", int port_idx = 0);
		tag = count++;
		this.name = n;
		
		// Generate one-hot source encoding
		if (port_idx >= 0 && port_idx < NUM_PORTS) begin
			this.source = 1 << port_idx;
		end else begin
			this.source = 4'b0000; // Invalid source
		end
	endfunction
	
	// 4. Configurable print method
	function void display(string prefix);
		int src_idx;
		
		src_idx = $clog2(source); 
		
		$display("[%0t] %s: Tag=%0d, Src=%b (Port %0d), Tgt=%b, Data=%h", 
				 $time, prefix, tag, source, src_idx, target, data);
	endfunction
endclass
`endif