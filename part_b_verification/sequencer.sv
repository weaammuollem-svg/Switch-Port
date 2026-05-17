`ifndef SEQUENCER_SV
`define SEQUENCER_SV

// ----------------------------------------------------------------------
// sequencer.sv
// Stimulus Generator
// Responsible for creating randomized packet objects and supplying them
// to the driver. Supports weighted distribution and "Hotspot" stress testing.
// ----------------------------------------------------------------------
class sequencer extends component_base;
	
	// Configuration
	int port_idx; 

	// --- Stress Test Configuration ---
	// Hotspot Mode forces traffic to a specific target to test arbitration.
	bit         hotspot_mode   = 0;
	logic [3:0] hotspot_target = 4'b0001; 

	// ------------------------------------------------------------------
	// Constructor
	// ------------------------------------------------------------------
	function new(string n, component_base p=null);
		super.new(n, p);
	endfunction

	// ------------------------------------------------------------------
	// Method: set_port_idx
	// Sets the physical port index this sequencer is associated with.
	// ------------------------------------------------------------------
	function void set_port_idx(int idx);
		this.port_idx = idx;
	endfunction

	// ------------------------------------------------------------------
	// Task: run
	// Placeholder for consistency with component architecture. 
	// The sequencer is passive and reacts to driver requests via get_next_item.
	// ------------------------------------------------------------------
	task run(int num_packets = 0);
	endtask

	// ------------------------------------------------------------------
	// Task: get_next_item
	// Generates a new randomized packet based on configured weights
	// and mode settings.
	// ------------------------------------------------------------------
	task get_next_item(output packet p);
		int rand_type;
		
		unicast_packet   u_pkt;
		multicast_packet m_pkt;
		broadcast_packet b_pkt;

		// 1. Determine Packet Type (Weighted Distribution)
		// 70% Unicast, 20% Multicast, 10% Broadcast
		if (!std::randomize(rand_type) with { 
			rand_type dist { 0:=70, 1:=20, 2:=10 }; 
		}) begin
			$error("[%s] Type randomization failed", pathname());
		end

		// 2. Instantiate Specific Class
		case (rand_type)
			0: begin
				u_pkt = new($sformatf("uni_p%0d", port_idx), port_idx);
				p = u_pkt; 
			end
			1: begin
				m_pkt = new($sformatf("multi_p%0d", port_idx), port_idx);
				p = m_pkt;
			end
			2: begin
				b_pkt = new($sformatf("bcast_p%0d", port_idx), port_idx);
				p = b_pkt;
			end
			default: begin
				u_pkt = new("default", port_idx);
				p = u_pkt;
			end
		endcase

		// 3. Apply Constraints and Randomize
		if (hotspot_mode && rand_type == 0) begin
			
			// Hotspot Logic:
			// Force the packet target to the configured hotspot port.
			
			// Self-Loop Prevention:
			// Hardware constraint: A packet source cannot equal its target.
			// If the hotspot target is this sequencer's own port, we must redirect.
			if ((4'b0001 << port_idx) == hotspot_target) begin
				
				// Redirect to a safe neighbor (Port 0 or Port 1)
				logic [3:0] safe_target = (port_idx == 0) ? 4'b0010 : 4'b0001;
				
				if (!p.randomize() with { target == safe_target; }) begin
					$error("[%0t] [SEQ] Redirect Randomization failed on Port %0d", $time, port_idx);
				end
			end else begin
				// Standard Hotspot: Force target
				if (!p.randomize() with { target == hotspot_target; }) begin
					$error("[%0t] [SEQ] Hotspot Randomization failed on Port %0d", $time, port_idx);
				end
			end

		end else begin
			// Normal Randomization
			if (!p.randomize()) begin
				$error("[%0t] [SEQ] Randomization failed on Port %0d", $time, port_idx);
				
				// Error Recovery: Assign safe default values to prevent simulation hang
				p.target = (port_idx == 0) ? 4'b0010 : 4'b0001;
				p.data   = 8'h00;
			end
		end
	endtask

endclass
`endif