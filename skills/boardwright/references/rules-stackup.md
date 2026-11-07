# Stackup and design rules from the fab profile

Every rule value must trace to the fab's published capability or to a
calculator. Rules recalled from memory are how a board fails at the fab.

## 1. Fab profile: fetch once, store, reuse

1. Look in the store first: `%USERPROFILE%\Boardwright\fab_profiles\<name>.json`.
   A stored profile younger than 12 months is used as it is (say so in
   the report).
2. Otherwise fetch the fab's **capabilities page** (for example the
   JLCPCB, PCBWay or Aisler capability tables) with web search and fetch,
   and transcribe it into a FabProfile:

```json
{
  "name": "JLCPCB standard 2L",
  "source": "<capability page URL>, retrieved <date>",
  "copper_layer_counts": [1, 2, 4, 6],
  "min_track_mils": 0, "min_gap_mils": 0, "min_drill_mils": 0,
  "min_annular_ring_mils": 0, "min_hole_to_hole_mils": 0,
  "min_mask_sliver_mils": 0, "min_silk_width_mils": 0,
  "stackups": [
    {"name": "2L 1.6mm 1oz", "layers": [
      {"name": "Top", "kind": "copper", "thickness_mils": 1.4, "copper_oz": 1},
      {"name": "Core", "kind": "core", "thickness_mils": 59.8, "er": 4.5},
      {"name": "Bottom", "kind": "copper", "thickness_mils": 1.4, "copper_oz": 1}]}
  ]
}
```

   Fill every `min_*` from the page (the zeros above are placeholders, not
   values). All dimensions are **mils**: the pages give mm, so divide by
   0.0254. Use the standard-process column unless the user chose an
   advanced process.
3. `design_load_fab_profile(profile)` must return `ok: true`. Then save
   the profile to the store for the next board.

## 2. Synthesize and apply

1. `design_synthesize_rules(profile, plan_json=<plan>, options={...})`.
   Useful options: `stackup`, `class_current_a` ({class: amps} from the
   constraints table), `delta_t_c`, `copper_oz`, `layer`,
   `diff_pair_target_ohms`, `diff_pair_spacing_mils`.
2. Read `notes`. Floors with no rule type (hole-to-hole, mask sliver, silk
   width, annular ring) must be enforced by hand: via styles, silk sizes.
3. Create every net class it names: `pcb_create_net_class(name, nets)`.
4. Apply each `rules` entry with `pcb_create_design_rule(**rule)` and each
   `stackup_ops` entry with `pcb_modify_layer(**op)`. Read back with
   `pcb_get_design_rules` and `pcb_get_layer_stackup`.

## 3. Rules synthesis does not write

Synthesis writes the fab floors, plus class widths only when
`class_current_a` is given. On the 45-part inverter plan it returned
exactly three rules (minimum clearance, width and drill) and the classes
power, switch, control, signal and ground. Nothing protects 360 V from a
5 mil gap until you add the rules below.

| Rule | How |
|---|---|
| **High-voltage clearance per class** | One clearance rule per HV class: `pcb_create_design_rule(name="HV_360V_Clearance", rule_type="clearance", value=<mils from the cited standard>, scope="InNetClass('HV')")`. A higher-priority, wider rule for mains or reinforced insulation. Name the standard and table in the rule name or the report |
| Vias in SMD pads | `pcb_create_design_rule(name="No_Via_In_SMD", rule_type="vias_under_smd", allowed=False)` unless the fab fills and caps vias |
| Tented vias | `rule_type="solder_mask_expansion"`, negative value, `scope="IsVia"` (the run that reached DRC 0 at JLC used a `Tent_Vias` rule) |
| Current-class widths | From `class_current_a`, or `rule_type="width"` per class with the widths from intake |
| Differential pairs | From `diff_pair_target_ohms`; define pairs in the schematic or with `pcb_create_diff_pair` |

Component clearance, hole-to-hole and board-outline clearance rules cannot
be created on this Altium build. Change the existing ones with
`pcb_set_rule_properties`.

**Fix the default rules that a new board fails** (first live run, 37
Altium DRC violations, none electrical):

| Default rule | Change |
|---|---|
| Hole Size, max 100 mil | Raise the max to the fab's largest drill (JLCPCB 6.3 mm). M3 holes (3.2 mm) and terminal pins fail the default |
| SilkToSolderMaskClearance, 10 mil | The fab's pad-to-silk minimum (JLCPCB 0.15 mm = 6 mil). Set it with `pcb_set_rule_properties(name=<rule>, gap_mm=0.15)` and check `gap_written`; only if that reports nothing written, ask the user to set it in Design ▸ Rules ▸ Manufacturing |
| Designator text | Set to the fab's minimum legible size (JLCPCB 1.0 mm height, 0.15 mm stroke) before placement, so it does not collide later |
| Silk outlines on pads | Footprint silk must clear its own pads by the rule above; fix it in the PcbLib, not on the board |

## 4. Board outline and skeleton

- `pcb_set_board_shape(x1, y1, x2, y2)` in mils from the agreed outline.
  Keep the origin at the lower-left corner.
- Mounting holes: place the hole footprint (or a pad with a plated or
  non-plated hole) at each agreed position. Add keep-outs on both sides
  for the screw head and washer.
- Fixed parts (connectors on edges, the heatsink line) get moved and
  **locked** now. Later placement treats them as fixed.
- Save the board by path.
