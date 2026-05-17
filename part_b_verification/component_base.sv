`ifndef COMPONENT_BASE_SV
`define COMPONENT_BASE_SV

// ----------------------------------------------------------------------
// component_base.sv
// Verification Component Base Class
// Provides standardized naming, hierarchy management, and execution hooks.
// ----------------------------------------------------------------------
virtual class component_base; 
	
	// Identity
	string name;             
	component_base parent;   

	// ------------------------------------------------------------------
	// Constructor
	// Initializes the component name and establishes hierarchy.
	// ------------------------------------------------------------------
	function new(string name, component_base parent=null);
		this.name = name; 
		this.parent = parent;
	endfunction

	// ------------------------------------------------------------------
	// Method: pathname
	// Recursively constructs the full hierarchical path string.
	// ------------------------------------------------------------------
	function string pathname();
		if (parent == null) 
			return name;
		else 
			return {parent.pathname(), ".", name};
	endfunction

	// ------------------------------------------------------------------
	// Method: print
	// Displays component information for debugging.
	// ------------------------------------------------------------------
	virtual function void print(); 
		$display("[%0t] [INFO] Component: %s", $time, pathname()); 
	endfunction

	// ------------------------------------------------------------------
	// Task: run
	// Main execution phase for dynamic components.
	// 'num_packets' allows controlling transaction volume if applicable.
	// ------------------------------------------------------------------
	virtual task run(int num_packets = 0);
		// Base implementation is empty; derived classes override this.
	endtask

	// ------------------------------------------------------------------
	// Method: report
	// Final reporting phase for statistics and pass/fail summary.
	// ------------------------------------------------------------------
	virtual function void report();
		// Base implementation is empty; derived classes override this.
	endfunction

endclass

`endif