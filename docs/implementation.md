# Implementation and Results

## Stage C Scope

Stage C takes the design through synthesis and implementation analysis. The repository keeps the important signoff artifacts as text files and generated design outputs rather than relying on large tool screenshots.

## Deliverables

| File | Description |
| --- | --- |
| `switch_4port_netlist.v` | Synthesized gate-level netlist |
| `switch_4port.sdf` | Standard Delay Format timing annotation |
| `simulation.log` | Gate-level simulation result |
| `area_no_cg.txt`, `area_with_cg.txt` | Area reports |
| `power_no_cg.txt`, `power_with_cg.txt` | Power reports |
| `timing_no_cg.txt`, `timing_with_cg.txt` | Timing reports |
| `qor_no_cg.txt`, `qor_with_cg.txt` | QoR reports |
| `clock_gating_details.txt` | Clock-gating insertion summary |

## Gate-Level Simulation

The gate-level simulation was run with SDF back-annotation. The result is recorded in `part_c_implementation/simulation.log`.

| Metric | Result |
| --- | ---: |
| Unique packets sent | 5,100 |
| Output packets expected | 7,401 |
| Correctly matched packets | 7,401 |
| Routing errors | 0 |
| Dropped/missing packets | 0 |
| Output success rate | 100.00% |
| Functional coverage | 100.00% |

## QoR Summary

| Metric | No Clock Gating | With Clock Gating |
| --- | ---: | ---: |
| Total cell area | 25,118.83 | 25,222.78 |
| Leaf cell count | 4,267 | 4,298 |
| Critical path slack, slow clk | 0.01 ns | 0.07 ns |
| Critical path slack, fast clk | 0.37 ns | 0.42 ns |
| Total dynamic power | 1.58e+08 pW | 1.55e+08 pW |
| Clock-gating cells | 141 | 153 |
| Gated registers | - | 2,196 / 2,202 |

## Netlist

The synthesized netlist is available directly as source:

```text
part_c_implementation/switch_4port_netlist.v
```

Keeping the netlist as a text artifact is cleaner than embedding a screenshot, because interviewers can inspect the generated module and hierarchy directly.

## Timing

The final timing report shows positive setup slack:

```text
Worst reported setup slack: 0.07 ns
Total negative slack: 0.00 ns
Violating paths: 0
```

## Clock Gating

The clock-gating report shows extensive register gating:

```text
Clock-gating elements: 153
Gated registers: 2,196 / 2,202
Maximum clock-gate levels: 2
```
