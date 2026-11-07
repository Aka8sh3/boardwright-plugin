# Board intake: what the board must satisfy, agreed before any copper

The schematic says what connects. The board also has to fit a mechanical
envelope, a fab's process, the currents and voltages the circuit carries,
and the safety distances between them. None of these show in ERC, and all
of them are expensive to change after placement. Agree them first.

## 1. Read what the schematic run left

- `Design Notes\schematic_plan.json` (older projects: `<proj>.plan.json`): the parts, nets, **blocks (zones)** and **net
  roles** (`switch`, `feedback`, `high_current`, `analog_sensitive`,
  `differential`, `clock`, ...). The blocks become board regions, and the
  roles drive the net classes.
- The schematic report: the operating point, the stresses from the design
  checks, and open items (heatsinks, creepage, custom magnetics).
- The BOM: packages, and through-hole versus SMD.

## 2. Ask, in one message (numbered, each with a default)

| # | Question | Default |
|---|---|---|
| 1 | Fab house and its process (standard, or advanced) | JLCPCB standard |
| 2 | Layers and copper weight | 2 layers, 1 oz (≤ 40 parts, no fast signals); 4 layers, 1 oz otherwise |
| 3 | Board size and shape, fixed by an enclosure? | Smallest rectangle that fits, rounded up to 5 mm |
| 4 | Mounting holes: count, size, positions | 4 × M3 (3.2 mm), 4 mm from the corners |
| 5 | Parts with fixed positions (connectors on edges, heatsink line, display, buttons) | Connectors on the edges facing their cables |
| 6 | Assembly: one side or two; who assembles (fab or by hand) | One side, top |
| 7 | High-speed or impedance-controlled nets (USB, Ethernet, RF, fast edges) | From the plan's `differential` / `clock` roles |
| 8 | Cooling: heatsinks, airflow, maximum ambient | Natural convection, 40 °C |
| 9 | Safety standard for clearance and creepage (anything above 30 V AC / 60 V DC, mains or HV) | IPC-2221B for functional insulation; ask which standard if mains or a user can touch it |

Skip a question the plan or the user already answered. For **quick** mode,
ask only #1 and the project path.

## 3. Derive the constraints table

One row per net class: the classes come from the plan's roles and flags
(`design_synthesize_rules` derives them), plus HV classes by voltage.

| Class | Nets (examples) | Current (A) | → width (mil) | Voltage to other nets | → clearance (mm) | Other |
|---|---|---|---|---|---|---|
| PWR_HI | VDC+, LEG_A | 18 A rms | from `pcb_calc(kind="trace_width_for_current")` (1 oz, ΔT 10 °C, external), or a pour | 50 V | fab min | pour + stitching |
| HV | VRECT, U_L | 1.5 A | ... | 360 V to LV | from the cited standard | slot if creepage is short |

Rules for the numbers:

- **Width from current:** `pcb_calc(kind="trace_width_for_current", args={"current_a": ..., "copper_oz": ..., "delta_t_c": ..., "layer": ...})`.
  Above about 3–5 A on 1 oz, plan a pour or polygon instead of a track,
  and say so.
- **Clearance and creepage from voltage:** take the values from the
  standard named in #9, fetched and **cited** (table and row), never from
  memory. The rule is "no unverifiable safety tables". Write the
  working voltage, the pollution degree and the insulation type you
  assumed. Where creepage on the surface exceeds the copper clearance,
  plan a **slot** (milled cut-out) or a larger gap, and list it as a fab
  note.
- **Impedance:** `pcb_calc(kind="impedance")` / `pcb_calc(kind="trace_width_for_impedance")`
  with the fab's stackup. Differential targets go to
  `design_synthesize_rules` as `diff_pair_target_ohms`.
- **Thermal:** parts the schematic checks flagged as hot get copper area
  and thermal vias (`pcb_calc(kind="thermal_vias", args={"power_w": ..., "delta_t_c": ..., ...})`), or
  a heatsink position on the edge.

Check each row against the fab profile's floors (track, gap, drill,
annular ring). Mark ✅, or ⚠ with the fix (heavier copper, more layers, a
pour, a slot).

## 4. Gate 1

Show the answers, the constraints table and the board outline you intend
(size, holes, fixed parts), and wait for the user's OK. Then save the
agreed spec in `<proj dir>\Design Notes\` as two files with the same
content, so a later run or a context reset starts from it:

- `Board spec.md`, for engineers: a first line saying it was written by
  the altium-agent plugin and that Altium does not read it; then the
  answers, the outline, the constraints table with each source cited, and
  the decisions taken (thermal vias, clearance exceptions). It reads like
  the layout-requirements sheet a hardware team writes by hand.
- `board_spec.json`, for the agent: fab profile name, layers, outline,
  holes, fixed parts, and the classes with width and clearance.

The binding values live in the board itself (rules, net classes,
stackup). These files record what was agreed and why; deleting them
never changes the design.
