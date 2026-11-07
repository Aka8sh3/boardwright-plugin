# Netlist to board without the ECO dialog

Altium's ECO (Design ▸ Update PCB Document) always raises a modal that a
person must click, and that blocks the bridge. Boardwright's headless route
places synced footprints and then binds every pad to its net. The exit
gate is `proj_compare_sch_pcb` reporting `in_sync: true`.

## Steps

1. `pcb_focus_board(<PcbDoc>)`, then `app_checkpoints(action="make", args={"label": "before sch_to_pcb"})`.
2. **Identity:** `obj_query(object_type="eSchComponent", scope="doc:<SchDoc>", properties="Designator.Text,UniqueId,LibReference")`
   for each sheet. The UniqueId lets a later ECO recognise the part.
3. **Pad nets:** `proj_get_connectivity_many(...)` for the designators
   gives pad number → net per part.
4. **Footprint and library:** from the plan or the BOM. Each footprint
   lives in the project PcbLib (absolute path).
5. **Place, synced, in one call:**
   ```
   pcb_place_components(board_path="<PcbDoc>", placements=[
     {"designator":"Q1","footprint":"TO-247-4_INF","library_path":"<lib>.PcbLib",
      "x": <staging x>, "y": <staging y>, "rotation":0, "layer":"Top",
      "unique_id":"<from 2>", "pad_nets":{"1":"VRECT","2":"U_L","3":"KS5","4":"G5"},
      "lib_reference":"<symbol>", "comment":"<value>"}, ...])
   ```
   Stage the parts in a grid **outside** the outline, grouped by block,
   so the placement phase starts from known positions.
   **Pinless parts** (mounting holes, fiducials) still have pads in their
   footprint. On the first live run, a call with an empty pad list placed
   MH1–MH4 with no hole pad at all, and no audit caught it. After placing
   them, check each one with `pcb_get_component_pads` (pad present, hole size right).
6. **Nets:** `pcb_build_from_project()` creates any missing nets and binds
   every pad. Read `missing_components`, `missing_pads` and
   `missing_nets`. A missing pad means the footprint's pad names do not
   match the symbol's pin numbers: fix the library and do not edit nets
   by hand.
7. **Gate:** `proj_compare_sch_pcb()` gives `in_sync: true`, with equal
   component counts. If not, `proj_get_differences` lists what is extra
   on each side.
8. Save the board by path.

## When to use the ECO instead

Use the ECO when the user is at the screen and prefers Altium's ECO (for
example to also transfer rooms and classes from the schematic):
`proj_sync_pcb()`. It focuses the PCB and blocks until they click
**Validate Changes** and **Execute Changes** and close the dialog. Then
`pcb_focus_board` again and run the same `proj_compare_sch_pcb` gate.

## Changes later

After a schematic change: re-run steps 2–7 for the changed parts only
(new parts placed, removed parts deleted with `pcb_delete_object`), or
use the attended ECO. Never leave the board out of sync at the end of a
run.
