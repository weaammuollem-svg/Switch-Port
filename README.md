# Four-Port Packet Switch

SystemVerilog project for a 4-port packet switch, covering RTL design, class-based verification, synthesis, gate-level simulation, and QoR analysis.

## Overview

The switch routes packets between four ports using per-port buffering, ready/valid flow control, FSM-based routing, multicast/broadcast support, and round-robin arbitration.

The project is organized into three stages:

| Stage | Focus |
| --- | --- |
| Part A | RTL design and directed signal-level validation |
| Part B | Class-based verification environment, scoreboard, constrained-random traffic, and coverage |
| Part C | Synthesis, clock-gating analysis, timing/power/area reports, netlist, SDF, and gate-level simulation |

## Key Results

| Metric | Result |
| --- | ---: |
| RTL regression output success | 100.00% |
| RTL functional coverage | 100.00% |
| Gate-level simulation output success | 100.00% |
| Gate-level simulation routing errors | 0 |
| Worst post-synthesis setup slack | 0.07 ns |
| Clock-gated registers | 2,196 / 2,202 |

## Documentation

- [Design Overview](docs/design.md)
- [Verification Overview](docs/verification.md)
- [Implementation and Results](docs/implementation.md)

## Repository Structure

```text
.
|-- part_a_design/            # RTL design and Stage A report
|-- part_b_verification/      # Verification components and regression
|-- part_c_implementation/    # Synthesis, netlist, SDF, reports, GLS log
|-- docs/                     # Project documentation and images
|-- .gitignore
`-- README.md
```

## Main Files

- `part_a_design/switch_4port.sv` - initial top-level RTL
- `part_b_verification/switch_test.sv` - main RTL regression
- `part_b_verification/checker.sv` - scoreboard/checker
- `part_c_implementation/switch_4port_netlist.v` - synthesized gate-level netlist
- `part_c_implementation/switch_4port.sdf` - SDF timing annotation
- `part_c_implementation/simulation.log` - gate-level simulation result

## How to Run

The Part B verification file list is provided in `part_b_verification/run.f`.

```bash
cd part_b_verification
vcs -sverilog -f run.f -full64 -debug_access+all
./simv
```

## Tools Used

- SystemVerilog RTL
- SystemVerilog class-based verification
- Synopsys VCS / Verdi
- Synopsys Fusion Compiler

## Author

Created by Weaam Muollem as part of a digital design, verification, and implementation project.
