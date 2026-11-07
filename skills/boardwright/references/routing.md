# Routing: staged, critical first, measured

Copper from an earlier stage is fixed for the later ones, so the order
decides the quality: the paths that matter electrically get the best
space.

## 1. Before routing

- `pcb_focus_board(<PcbDoc>)`, `app_save_document(<PcbDoc>)`, then
  `app_checkpoints(action="make", args={"label": "before routing"})`.
- Confirm that the rules from phase 3 are on the board
  (`pcb_get_design_rules`): class widths, HV clearances, no via in SMD.
- Open `design_live_view` if the user wants to watch.

## 2. Stages

| # | Stage | How |
|---|---|---|
| 1 | Differential pairs and impedance nets | `pcb_autoroute(expect_file, nets=[pair nets], diff_pairs=True)`; check `pairs` (length, skew) in the job result |
| 2 | Sense lines and gate-drive loops | Short and direct, gate and Kelvin return side by side. Place them yourself with `pcb_place_tracks` where the path is obvious, or route those nets alone |
| 3 | **Power paths as copper** | Wide tracks at the class width from intake, or polygons (`pcb_place_polygon_rect` on the net and layer, then `pcb_repour_polygons`). The commutation loop and the bus get copper areas, not thin tracks |
| 4 | Plane fan-out | For plane nets (GND on a 4-layer board): a short dog-bone from each pad to a via beside it, `pcb_autoroute(..., plane_fanout=True)`, or by hand |
| 5 | Buses | 3+ nets between the same parts as nested lanes (`bus_lanes=True`) |
| 6 | The rest | `pcb_autoroute(expect_file, pad_vias=...)` on the remaining nets |

**Router job loop:** `pcb_autoroute(...)` returns a job_id. Then
`design_job_status(job_id)` until done, then `design_job_result(job_id)`.
Read `unreached` (pads and what blocks them), `via_in_pad` and the DRC
verdict. If it is acceptable, `pcb_autoroute_apply(job_id, expect_file)`.

`pad_vias`: use `"bga"` for fabs that do not fill and cap vias (JLCPCB
standard 2-layer). The default `"ic"` allows vias in IC pins. Every via
in a pad becomes a fab note.

**Offline alternative:** `route_plan(fetch_geometry=True, nets=[...])` gives
tracks and vias as ops; apply them with `pcb_place_tracks` /
`pcb_place_vias`. Its repairs come from
`route_plan_repairs(violations)`.

## 3. When something will not route

- An **unreached pad** is a placement problem at that pad. Rotate or move
  the part (refine placement for that block) and re-route that net only.
  Do not re-run the whole router hoping for a different result.
- Earlier copper blocking a bus: rip up that copper (`pcb_unroute` on the
  net, or delete its tracks) and re-plan it together with the bus.
- Two rounds without progress: stop and show the user the blocking area.

## 4. DRC without a modal

- During routing, `pcb_layout_audit(checks=["connectivity_summary","drc","corner_audit"])`
  runs the exact clearance check offline. It never blocks.
- `pcb_get_clearance_violations()` reads the violations Altium **stored**
  at its last DRC. Zero means none stored, not a pass, unless DRC ran this
  session.
- Altium's own DRC: `pcb_run_drc()` (batch check, no dialog). Then
  `pcb_get_clearance_violations`.
- Fix loop, at most **3 rounds**: read the violations, fix the cause
  (placement, width, clearance class), re-audit. Rule changes need the
  user's OK unless they correct an error against the agreed spec.

## 5. Measured gate

`pcb_layout_audit(expect_file=<PcbDoc>)`:
- `connectivity_summary` routed == nets
- `drc` violations == 0
- `corner_audit` sharper_than_45 == 0

Plus `pcb_get_unrouted_nets(reanalyze=True)` is empty. Log the numbers
(`design_session_log(stage="routing", data=...)`) and save the board by
path.
