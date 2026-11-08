# DesignPlan + template: how a sheet gets drawn

Two pieces, in this order:

1. The **DesignPlan** says *what* the circuit is: parts (with MPN,
   footprint, datasheet) and nets. It is checked without Altium and it
   stamps Value / Manufacturer / MPN / Footprint on every drawn part.
2. The **template** says *where* everything goes: every part's position,
   every wire's path, power ports and net labels, all on the 100 mil grid.
   You plan it the way an engineer draws the block. `sch_preview_template`
   checks it and renders a PNG without touching a sheet (it reads the
   symbols' pins through the bridge, so Altium must be up);
   `sch_draw_template` draws it.

`boardwright_draft_schematic` writes the template from the plan (see the
next paragraph); your job is to review and adjust it, not to write one
from nothing. The live schema and rules come from `design_get_discipline`.

**The drafter.** It reads each part as an engineer does before drawing:
a net is ground, a rail (the plan's `is_power` / `is_ground`) or a
signal; a two-pin part between two signals is in the path and lies
across it, one between a signal and ground or a rail hangs off that
line (a pull-down under it, a pull-up or clamp above it, a divider
stacked on its node), a capacitor between a rail and ground decouples
(by an IC, in a row above it with its own symbols). Connectors whose
`role` or `value` says in/input/supply/ctrl go on the left edge,
out/output/load on the right; any other connector (a debug header, a bus)
goes where its pins lead. So give connectors a `role` such as
`vin_conn`, `ctrl_conn`, `load_conn`. It then searches placements and
routes each one; the engine's template checker scores every candidate,
so a draft has no shorts and matches the plan pin by pin.

## The plan

```json
{
  "spec": "what the user asked for, verbatim or close",
  "summary": "one paragraph: topology and key values",
  "sheets": [{"name": "main", "size": "A4"}],
  "zones":  [{"name": "drive", "sheet": "main", "role": "gate_drive"}],
  "parts": [
    {"refdes": "Q1", "lib_ref": "NMOS_SOT23", "lib_path": "C:\\...\\x_lib.SchLib",
     "value": "2N7002", "footprint": "SOT-23-3", "manufacturer": "...",
     "mpn": "2N7002", "datasheet_url": "https://...", "sheet": "main",
     "zone": "drive", "status": "existing"}
  ],
  "nets": [
    {"name": "GATE", "pins": [{"refdes": "R1", "pin": "2"}, {"refdes": "Q1", "pin": "1"}]},
    {"name": "GND",  "pins": [...], "is_ground": true},
    {"name": "V12",  "pins": [...], "is_power": true}
  ],
  "open_questions": ["assumptions the user should confirm"]
}
```

Rules the validator enforces:

- `spec`, `summary`, `sheets`, `parts` and `nets` are required and must
  not be empty. No extra fields are allowed.
- **Every net has at least 2 pins.** If a pin is meant to be unconnected,
  leave it out of every net and report it in phase 5.
- `pin` is the pin **number** (or name) exactly as the symbol has it.
  Confirm it with `lib_get_pin_list`.
- Every part has `status: "existing"` (it resolves in a library) or
  `"needs_creation"`. Author `needs_creation` parts before drawing.
- Refdes: R, C, L, D, Q, U, J, SW, F, FB, numbered from 1 with no gaps.
- Rails use `is_power` and ground uses `is_ground`.
- Fill in `manufacturer`, `mpn`, `footprint` and `datasheet_url` on every
  part. Without them the BOM has empty columns and `design_validate` warns
  about atomic parts.

Build the plan with blocks, not by hand:

```
design_compose_netlist(plan_json, operations=[
  {"op":"add_part","refdes":"U1","lib_ref":"...","connections":{"1":"VCC","2":"GND","3":"SIG"},
   "power_nets":["VCC"],"ground_nets":["GND"]},
  {"op":"add_block","block":"decoupling","params":{"power_net":"VCC","ground_net":"GND","lib_ref":"CAP_GEN","value":"100nF","count":2}},
  {"op":"add_block","block":"pullup","params":{"signal_net":"SIG","rail_net":"VCC","lib_ref":"RES_GEN","value":"10k"}}
])
```

Blocks (exact parameters from `design_list_circuit_blocks`): decoupling,
pullup, pulldown, series_resistor, voltage_divider, rc_lowpass,
rc_highpass, led_indicator, crystal, pi_filter, mosfet_low_side,
mosfet_high_side. Values: `design_compute_component_value` or the
datasheet's formulas, rounded to E-series values.

## The template

```json
{"parts": [{"designator": "U1", "x": 3000, "y": 4000, "rotation": 0},
           {"designator": "C1", "x": 2000, "y": 3600, "rotation": 90}],
 "wires": [{"net": "VIN", "path": [[1500, 4600], "U1.PVIN"]},
           {"net": "VIN", "path": [[2000, 4600], "C1.1"]}],
 "ports": [{"net": "VIN", "at": [1500, 4600], "style": "bar"},
           {"net": "GND", "at": [2000, 3200], "style": "gnd_power"}],
 "labels": [{"net": "PG", "at": [4200, 3700]}],
 "nets": {"VIN": ["U1.PVIN", "C1.1"]}}
```

- With `plan_json` given, a part needs only `designator` and position:
  symbol, library and value come from the plan, and the plan's nets are
  checked pin by pin.
- A path point is `[x, y]` or a **pin anchor** `"U1.11"` / `"U1.EN"`, the
  pin's wire end worked out from the symbol, so you never compute pin
  coordinates. A name shared by several pins (PGND, SW) needs the number.
- Two off-axis points get one corner, horizontal first (`"corner": "vh"`
  for vertical first). Do not plan junction dots; Altium adds them.
- Ports: `bar` points up for a rail, `gnd_power` points down; each ground
  drop gets its own port.
- A big sheet's template is tens of KB: write it to
  `Design Notes\schematic_template.json` and pass `template_path`.

**How an engineer draws a block** (the template rules): the IC in the
middle; the input rail as one straight wire with its capacitors hanging
straight down to ground; a feedback divider as a vertical stack whose
midpoint runs straight across to the FB pin; the output rail straight
with its capacitors and pull-ups hanging from it; signal flow left to
right in the order named in phase 1; **net labels only where a signal
leaves the block**; room beside each part for its value text.

## Validate → preview → approve → draw

1. `design_validate_plan(plan_json)` costs nothing and needs no Altium. Fix
   every error.
2. `boardwright_draft_schematic(plan_path=<Design Notes\schematic_plan.json>)`,
   read its PNG, adjust the draft if needed and save it as
   `Design Notes\schematic_template.json`.
3. `sch_preview_template(template, plan_json=..., png_path="<proj dir>\\Design Notes\\schematic_preview.png")`.
   Fix **every** error (shorts, overlapping wires, bad anchors, netlist
   differences, a port touching nothing) and every warning (crossings, a
   wire through a body, dangling ends, off-grid points, stacked labels).
   Then read the PNG once, give the user its path and wait for an OK.
4. `sch_draw_template(template, document_path=<SchDoc>, plan_json=...)`.
   It checks against the real placed pins and stops before the first wire
   on any error. It does not save.
5. Save by path: `app_save_document(<SchDoc>)`, then `proj_save`.
6. `design_audit_schematic(project_path)` before ERC: overlaps, wires
   through bodies, stacked ports.

Keep `Design Notes\schematic_plan.json` and
`Design Notes\schematic_template.json`, so a later edit and the layout
skill start from them. Every file that is not an Altium document goes in
`<proj dir>\Design Notes\`.

## Lessons from live runs (follow them)

- **Sheet size first:** set it before drawing with
  `sch_set_sheet_size("A3")` (`"A1"` for more than about 30 parts), then
  check with `sch_audit_outside_sheet` after the draw. Custom sizes use
  `UseCustomSheet` with an explicit size.
- **Net names:** Altium names a wire-only net after one of its pins
  (`NetJ3_1`). Put one entry in `labels` on every block-local net whose
  name matters (anything the layout rules, the BOM or a reader refers to)
  so it keeps its plan name. Check `proj_get_nets` after the draw.
- **Diode and polarised-capacitor polarity:** the auto glyphs do not
  report which end is anode or +. For a part whose pin numbering comes
  from its datasheet (TO-220 diode with cathode = pin 1), check
  `lib_get_pin_list` against the card. If the glyph cannot show it, draw
  the symbol yourself with `lib_create_symbol`.
- **Read the PNG once per approved change**, not once per experiment:
  each image costs context on every later turn. Judge connectivity from
  the preview's `netlist` and `unconnected_pins`, not from the picture.

## Editing later

- Change the plan with `design_edit_plan` (it scrubs removed parts out of
  the nets), update the template, and **redraw the block on a fresh
  sheet**: `sch_draw_template` refuses a designator already on the sheet,
  so do not patch part by part.
- If the parts are already on a board, give each one its old
  `"unique_id"` in the template (read them first with
  `obj_query(object_type="eSchComponent", properties="Designator.Text,UniqueId")`),
  so the board stays linked.
- For a sheet Boardwright did not draw, `design_plan_from_sheet` reads a
  plan back off it.
- The `sch_` and `obj_` tools are for small repairs only. For several
  objects at once, give `obj_create` / `obj_modify` / `obj_delete` an
  `items` list (one Altium transaction).
