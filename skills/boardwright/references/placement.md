# Placement: floorplan, then patterns, then measure

A board is judged by its organisation first: blocks you can recognise,
signal flow you can follow, critical loops short. Function and
routability follow from the same discipline. A placer's wirelength score
does not make a board readable. The floorplan does.

## 1. Floorplan (before any part moves)

In this order:

1. **Fixed skeleton:** the outline, the mounting holes and their
   keep-outs, the connectors at their edges, the heatsink line, and any
   part a datasheet or the enclosure pins down. These are **locked**.
2. **Corridors** for critical and high-current paths, along region edges
   and never through a region that must stay whole (analog, HV).
3. **Sections:** power, high-voltage, analog, digital, I/O. Each is one
   contiguous area, sized at about 2× its parts' area. **High-voltage
   sections are separated from low-voltage ones by at least the creepage
   distance from intake**, with a slot where surface creepage is short.
4. **One rectangle per functional block** (the plan's zones), in
   signal-flow order (input, protection, conversion, output), each next
   to the blocks it shares nets with. Create rooms for them:
   `pcb_create_room(name, x1, y1, x2, y2, components="Q1,Q2,...")`.

`design_suggest_partition(plan_json, n_groups)` helps when the plan has no
zones.

Write the floorplan down (block → rectangle) and log it
(`design_live_note`) before moving anything.

## 2. Each block to a pattern

- The key part (IC, switch pair, transformer) at the block's centre,
  turned so its pads face what they connect to.
- Parts on a pin go in a column on that pin's side: **decoupling closest**,
  then the other parts on the pin, then the parts chained to them.
- Passive-only blocks go in rows, same orientation, uniform pitch.
  Repeated channels (four gate drives, eight switches) are identical tiles
  on a grid.

### Power-electronics patterns (apply when the plan has them)

| Structure | Pattern |
|---|---|
| Half-/full-bridge leg | High-side and low-side switches side by side, with the **DC-link decoupling capacitor across the leg** at the shortest distance (the commutation loop: +bus → HS → LS → −bus → cap). Measure it with `loop_audit` |
| Gate drive | The driver next to its switch; the gate resistor at the gate; the **Kelvin source** return routed alongside the gate track (smallest gate loop); bootstrap diode and capacitor at the driver |
| TO-247 / TO-220 on a heatsink | In one straight row along the board edge on the heatsink line, tabs facing out, at a pitch that keeps the creepage between tabs at different potentials. The tab potentials come from the datasheet cards |
| Transformer / magnetics | Between the primary and secondary sections, so the isolation gap runs through the magnetics. Primary pins face the bridge, secondary pins face the rectifier |
| Rectifier and output filter | In the flow direction after the magnetics; the filter capacitor close to the rectifier output; the output connector at the edge |
| Current sense (shunt) | A Kelvin connection at the shunt pads, with the amplifier close by and away from switch nodes |
| Bulk electrolytics | Near the input connector and the bridge, not under heatsinks; mind the height near the enclosure lid |

## 3. Run the placer, dry run first

Empty board:
```
pcb_plan_placement(engine="construct", plan_json=<plan>, fixed=[locked refs],
  edge_parts={"J1":"L","J2":"R"}, keepout_groups={...HV vs LV...},
  critical_nets=[switch/loop nets], restarts=3, apply=False)
```
Read `summary`, `overlap_pairs_after`, `hpwl_improvement_pct` and the
objective terms, then repeat with `apply=True`. Afterwards use
`engine="refine"` with `designators=[one block]` to polish block by block.
The job alternative is `pcb_autoplace(expect_file, parts=[...])`, then
`design_job_result`, then `pcb_autoplace_apply`.

Hand placement of one block: plan all the moves, check each with
`pcb_check_placement_collision`, then apply them in **one**
`pcb_move_components` call.

**Read the legaliser's moves.** A part pushed more than about 2 mm means
the floorplan is wrong there: change the block rectangle, not the part.
If the result looks scattered, tuning placer weights will not fix it. Go
back to the floorplan.

## 4. Measured gate, then the user's OK

1. `pcb_layout_audit(expect_file=<PcbDoc>, checks=["placement_audit","loop_audit"])`.
   **Pass:** overlaps 0, pad_gaps_below_rule 0, on_keepouts 0,
   on_mounting_holes 0, off_board 0. List the worst loops from
   `loop_audit` (hot loop, gate loop, decoupling); shrink any that are
   clearly too large.
2. One `design_visual_review(target="pcb")`, then Read the PNG. Check that
   the blocks are recognisable, the flow runs left to right, connectors
   are on the edges and the HV gap is visible.
3. Log the stage: `design_session_log(stage="placement", status="ok", data=<audit>)`.
4. **Gate 2:** show the render, the floorplan and the numbers. Wait for
   the user's OK or their moves. Save the board by path.
