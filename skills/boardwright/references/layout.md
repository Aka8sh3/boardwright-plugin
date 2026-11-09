# Layout part: schematic → board → DRC 0 → fab package

Read this when the job includes a board: layout, placement, routing,
DRC or fab outputs. The tool rules and the preflight in SKILL.md come
first and still apply.

You drive Altium Designer through the `boardwright` MCP server. The
input is a project whose schematic compiles with **ERC 0** (normally built
by the schematic part, [schematic.md](schematic.md)). You deliver a saved board that is
**100 % routed, DRC 0 and passes the measured layout audits**, plus a
fabrication package, laid out the way a reviewer expects: blocks you can
recognise, signal flow you can read, critical loops short.

Work through the phases in order. At each phase, report one short line to
the user: what you did and the numbers the tool returned. There are three
approval gates where you stop and wait: the **board spec** (phase 1), the
**placement** (phase 5) and the **final review before outputs** (phase 8).

### Mode: full (default) or quick

If the request contains **`quick`**, **`draft`** or **`sketch`**: ask only
for the project path and the fab profile (or use one from the store),
skip phase 1's other questions (use the defaults in the reference), run
phases 2–7 with a single placement and route pass, report the audit
numbers, and **stop before outputs**. The report says it is a draft.

### Mode: demo (hands-free)

If the request contains **`demo`**, **`hands-free`** or **`no questions`**,
run without stopping; the user is recording and will not answer:

- No gates and no questions. Use the request, the board notes on the
  schematic's block diagram, a stored fab profile (JLCPCB standard when
  none is named) and the reference defaults. Show the board spec, the
  placement numbers and the final audit as status lines and go on.
- Narrate each phase as `▶ Phase n/8: <name>`, then one line of numbers.
- Never call a tool that opens a modal (`proj_sync_pcb`, ECO,
  `pcb_run_drc(allow_modal=True)`, menu or dialog tools). Altium's own
  DRC still runs: `pcb_run_drc()` is the batch check, no dialog. Run it
  in phase 7 like any other mode; the measured audits do not check silk
  spacing, and a demo board once passed them with two silk-to-silk
  violations.
- Generate outputs only through the headless path. If it needs a click,
  skip it and say so in the report.
- If the request also contains `quick`, run the quick mode without stopping.

### Token economy

- `design_get_discipline` once per conversation (about 18k tokens). If the
  schematic part already loaded it in this conversation, do not load it
  again.
- Read each reference file once, when its phase starts.
- Judge the board from numbers (`pcb_layout_audit`, `proj_compare_sch_pcb`,
  `pcb_get_unrouted_nets`), not from pictures. Render
  (`design_visual_review`) only at the placement gate and the final
  review. Each image costs about 1.5k tokens and stays in context.
- Avoid `pcb_get_components` on a large board more than once per phase:
  keep its result and work from it.
- Long placement and routing runs are **jobs** (`pcb_autoplace`,
  `pcb_autoroute`). Start them, then poll `design_job_status` sparingly.

## 0. Tools, focus and safety (read first)

Tool modes (full or minimal `tool_catalog` / `tool_invoke`) are in
SKILL.md and [tool-access.md](tool-access.md). Coordinates are **mils**.

Board safety rules. Each comes from a real incident:

1. **Focus the board before every board edit.** With more than one PcbDoc
   open, board tools act on the *focused* board, and DRC, ECO and report
   windows steal focus. A repour and three tracks once landed on the
   user's thesis board. So: `pcb_focus_board(board_path)` at the start of
   every phase and after anything that opens a window; pass `expect_file`
   / `board_path` wherever a tool takes one; check with a cheap
   `obj_count` when in doubt.
2. **Save by path only:** `app_save_document(<PcbDoc>)` and `proj_save`.
   Never `app_save_all`.
3. **No unattended modals.** `proj_sync_pcb` (ECO) and
   `pcb_run_drc(allow_modal=True)` block the bridge until a human clicks
   (plain `pcb_run_drc()` is headless). Use the headless routes below, and
   use the modal ones only when the user is at the screen and has agreed.
4. **Checkpoint before each high-risk stage** (netlist transfer, routing,
   pours): `app_checkpoints(action="make", args={"label": ...})`. The job tools checkpoint by
   default; save the board first so the checkpoint holds it.
5. `pcb_set_text_visibility` once hung the script loop. Move designators
   with `obj_modify(items=[...])` X/Y instead.

**Project files.** Altium documents stay where Altium keeps them. Every
other file you write (the board spec, review renders, reports, fab notes)
goes in one folder, `<proj dir>\Design Notes\`, so an engineer opening the
project sees normal Altium files plus one clearly named notes folder. The
board spec is two files there: `Board spec.md` for people (the agreed
answers, the constraints table with sources, the decisions) and
`board_spec.json` for later runs. Older projects may have
`<proj>.board.json` and `<proj>.plan.json` next to the project: read them
from there and write new files to `Design Notes\`. The engine's own
`<proj>.canvas.json` stays where the engine puts it.

Durable progress: a layout run is long. At the start, call
`design_session_start(requirement)`. After each stage, log it with
`design_session_log(event="stage_result", stage=..., status="ok", data=<audit numbers>)`.
After a context reset, `design_session_resume` says where you are, and
`design_next_action` checks the measured gates for you.

## 1. Board intake (gate 1: board spec)

Follow [board-intake.md](board-intake.md):

1. Read what the schematic run left: the plan (`Design Notes\schematic_plan.json`,
   or `<proj>.plan.json` in older projects), its
   blocks, net roles and BOM, and the open items in its report.
2. Ask the board questions in **one message**, numbered, each with a
   default: fab house, layer count and copper weight, board size and
   shape, mounting holes, fixed connector and part positions, enclosure or
   heatsink constraints, assembly sides, and anything high-speed. Skip
   what you already know.
3. **Derive the electrical constraints** in one table: per net class, the
   current → track width (`pcb_calc(kind="trace_width_for_current")`), the voltage
   → clearance and creepage (from the cited standard), and the impedance
   targets. Mark each ✅ / ⚠ against the fab's limits.
4. Get the user's OK on the spec and the constraints table.

## 2. Preflight

1. `app_ping` (the SKILL.md preflight; repeat it when a run resumes).
   Fix it as in [first-run.md](first-run.md).
2. `proj_open(project_path)`, then `proj_compile`, then `design_validate`.
   **Do not lay out a board whose schematic has ERC errors.** Go back to
   the schematic part ([schematic.md](schematic.md)) instead.
3. **Every part has a footprint:** read the BOM (`proj_get_bom`). A part
   without a footprint, or with one not checked against its datasheet, is
   fixed in the library first (phase 3 of [schematic.md](schematic.md)).
4. `proj_list_open`. Name any other open projects, especially ones with a
   PcbDoc, and ask the user to close them. If they stay open, rule 1 above
   is mandatory on every call.
5. `app_checkpoints(action="make", args={"label": "before boardwright layout"})`.

## 3. Board, stackup and rules

Follow [rules-stackup.md](rules-stackup.md):

1. Create the board if none exists:
   `app_create_document(kind="PCB", file_path="<proj dir>\\<proj>.PcbDoc")`,
   then `pcb_focus_board`.
2. **Fab profile** from the fab's capability page, fetched and cited in
   `source`, never from memory. Check the fab-profile store first
   (`%USERPROFILE%\Boardwright\fab_profiles\`). Validate it with
   `design_load_fab_profile`.
3. `design_synthesize_rules(profile, plan_json, options)` gives the rules
   and stackup ops. Create the net classes it names
   (`pcb_create_net_class`), then apply each rule
   (`pcb_create_design_rule`) and stackup op (`pcb_modify_layer`).
4. Add what synthesis does not cover: **high-voltage clearance rules per
   class**, `vias_under_smd` (allowed=False unless the fab fills and caps
   vias), tented vias, and current-class widths.
5. Board outline (`pcb_set_board_shape`), mounting holes and their
   keep-outs, and the fixed parts from the spec.

## 4. Netlist to board (no ECO dialog)

Follow [sch-to-pcb.md](sch-to-pcb.md):

1. Read each schematic part's `UniqueId` (`obj_query`, `eSchComponent`)
   and its pad nets (`proj_get_connectivity_many`).
2. `pcb_place_components(placements=[...synced: unique_id + pad_nets...], board_path=...)`
   drops every footprint, outside the outline for now, in one call.
3. `pcb_build_from_project()` creates the nets and binds every pad.
4. **Exit gate:** `proj_compare_sch_pcb` reports `in_sync: true`, with
   matching part and net counts. Save the board.

If the user prefers Altium's own ECO and is at the screen,
`proj_sync_pcb` is the alternative (they click Execute Changes).

## 5. Placement (gate 2: placement)

Follow [placement.md](placement.md):

1. **Floorplan first:** the fixed skeleton (outline, holes, connectors at
   their edges, heatsinks), then the corridors for critical and
   high-current paths, then one rectangle per functional block in
   signal-flow order (the plan's blocks; rooms via `pcb_create_room`).
   For high voltage, separate the domains with the creepage distance
   between them.
2. **Place each block to a pattern:** the key part at the centre, with its
   pads facing what they connect to, and decoupling and loop parts
   closest. Use `pcb_plan_placement` (`engine="construct"` for an empty
   board, `"refine"` afterwards) with `edge_parts`, `keepout_groups`,
   `critical_nets` and `plan_json`, or the `pcb_autoplace` job. Always run
   a dry run first, then apply.
3. **Read the legaliser:** a part pushed more than about 2 mm means the
   floorplan is wrong there, so fix the floorplan.
4. **Exit gate (measured):** `pcb_layout_audit(checks=["placement_audit","loop_audit"])`
   gives 0 overlaps, 0 pad gaps below the rule, 0 parts on keep-outs,
   holes or off the board, with the loop audit's worst loops listed. Then
   one `design_visual_review` render.
5. **Show the user the render and the numbers, and wait for their OK.**
   Moving a part now is cheap; after routing it is expensive.

## 6. Routing

Follow [routing.md](routing.md):

1. `pcb_focus_board`, save, checkpoint.
2. Route **in stages, critical first:** differential pairs, then sense and
   gate-drive loops, then **power paths as copper** (polygons or wide
   tracks sized in phase 1), then plane fan-out, then buses, then the rest.
   Copper from an earlier stage is fixed for the later ones.
3. Use the in-house router as a job:
   `pcb_autoroute(expect_file, nets=..., pad_vias="bga" for fabs that do not fill vias)`,
   then `design_job_result`, then read `unreached` and `via_in_pad`, then
   `pcb_autoroute_apply`. Place critical copper yourself with
   `pcb_place_tracks` and `pcb_place_vias` where the router should not
   decide.
4. A pad the router cannot reach is a **placement** problem at that pad.
   Fix the placement and do not re-run the router blindly.
5. **Exit gate (measured):** `pcb_layout_audit` shows
   `connectivity_summary` routed == nets, `drc` violations == 0 and
   `corner_audit` sharper_than_45 == 0. Also `pcb_get_unrouted_nets`
   (reanalyze=True) shows none.

## 7. Pours, stitching and verification

1. Pours: ground (and power) polygons by net and layer
   (`pcb_place_polygon_rect` or the polygon tools), repour
   (`pcb_repour_polygons`), stitching vias (`pcb_place_stitching_vias`,
   dry run first), and thermal vias under power pads
   (`pcb_calc(kind="thermal_vias")`).
2. **Measured gate:** `pcb_layout_audit` (all checks): plane_region_audit
   islands == 0, drc == 0, placement and routing numbers still pass, and
   return-via exceptions listed. `pcb_smart_drc` covers spacing of noisy
   and sensitive nets, which the board rules leave out.
3. Silkscreen: `pcb_autoplace_silkscreen`. Keep the board name, revision,
   connector functions, pin-1 marks and polarity marks. On a dense board,
   move designators to the assembly layer (`pcb_copy_designators_to_mech`).
4. **Altium's own DRC:** `pcb_run_drc()` runs Altium's batch check with
   no dialog and no focus change. Then `pcb_get_clearance_violations`.
   Tick the rules for batch checking first; a rule left out is not
   checked. Loop at most **3 rounds** of fixes, as
   in [routing.md](routing.md).
5. Re-check sync and ERC: `proj_compare_sch_pcb` in_sync and
   `proj_run_erc` at 0.

## 8. Final review and outputs (gate 3)

Follow [outputs.md](outputs.md):

1. One `design_visual_review` render and the numbers table (placement,
   routing, pours, DRC, ERC, sync). **Wait for the user's OK.**
2. Fab package from an OutJob based on Altium's Fabrication template:
   Gerber RS-274X, NC drill (PTH/NPTH split), IPC-356, pick-and-place,
   BOM, assembly drawings, and STEP on request. Use
   `proj_generate_fab_package`. If it writes nothing (seen on AD23), ask
   the user to click **Generate content** in the OutJob, then list the
   files.
3. Report: the board size and stackup, the rules applied (with their
   source), the measured numbers, the fab notes (vias in pads, HV
   clearance classes, tented vias), the open items, and the output
   folder. Offer `design_session_report` for a full design report.

Save only by explicit path, never with `app_save_all`.
