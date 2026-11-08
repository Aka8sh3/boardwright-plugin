# Schematic part: idea → parts → library → sheet → ERC

Read this when the job includes a schematic, a library part or an
ERC fix. The tool rules and the preflight in SKILL.md come first and
still apply.

You drive Altium Designer through the `boardwright` MCP server. The
user describes a circuit, often only as a picture from a paper or a block
diagram and one line of text. You deliver a saved project whose schematic
compiles with **ERC 0 errors**, built from **real, orderable parts**, each
from a library that you checked or wrote against its datasheet.

Work through the phases in order. At each phase, report one short line to
the user saying what you did and what the tool returned. There are three
approval gates where you stop and wait: the **spec** (phase 1), the **BOM**
(phase 3) and the **preview** (phase 4). Demo mode shows them and does not
wait.

### Mode: full (default) or quick

If the request contains **`quick`**, **`draft`** or **`sketch`**, run
**quick mode**, a cheap concept capture:

- Phase 1: recognise the circuit and name its blocks, but ask **only for
  the project path**. Use the picture's labels as values. Keep the circuit
  as drawn, including sources, L_m and load models as generic symbols, so
  the sheet matches the figure.
- Phase 3: no web search, no `part_search`, no datasheets, no BOM gate.
  Make generic symbols with `lib_create_passive_symbol` (kinds such as
  nmos, diode, inductor, capacitor) and `lib_create_symbol` for sources
  and transformers, **without footprints**. Set `value` to the label from
  the figure and `mpn` to `"GENERIC"`.
- Phases 4–7 as normal: the preview gate, the ERC to 0 errors, and the
  report. The report says it is a quick draft with no real parts.
  Atomic-part warnings from `design_validate` (missing MPN, footprint or
  datasheet) are expected in quick mode. List them as one line; do not
  fix them.

To upgrade a quick draft later, the user asks for the full run on the same
project. Run phases 1 and 3 in full, then change the parts' `lib_ref`,
`mpn` and footprint in the plan (`design_edit_plan`), keep the template
positions, and redraw each block on a fresh sheet with
`sch_draw_template`.

### Mode: demo (hands-free)

If the request contains **`demo`**, **`hands-free`** or **`no questions`**,
run the full mode **without stopping**. The user is recording and will not
answer, so the run must finish on its own:

- **No gates and no questions.** Take every answer from the request, the
  picture and the defaults in the references. Still **show** the spec with
  the design-check table, the BOM and the preview summary as status
  messages, then go on at once. A ❌ check gets its proposed fix applied,
  and the report names the fix.
- **Parts:** the verified store first. For a part not in the store, take
  the first candidate that meets the rating and has a datasheet that can
  be fetched; do not hold a shortlist for the user.
- **Narrate for the viewer.** Start each phase with one line
  `▶ Phase n/7: <name>` and end it with one line of numbers (parts found,
  nets, ERC errors). No long tables in between.
- **No modal dialogs:** no `proj_export_pdf`, no menu or dialog tools, no
  `app_save_all`.
- **Preflight that fails stops the run** with one clear line (open Altium,
  start StartMCPServer). Do not run terminal commands in demo mode.
- After ERC 0, promote the new parts to the verified store without asking.
- If the request also contains **`quick`**, run quick mode without
  stopping, with the same narration.

Otherwise run the **full mode** below. When the request is ambiguous
(for example "just show me what it looks like"), ask which mode in one
line.

### Token economy (both modes)

- `design_get_discipline` is about 18k tokens. Call it **once per
  conversation**, keep the schema and the rules you need, and do not call
  it again.
- Open a reference file only when its phase starts, and only once.
- Do not take screenshots or render SVGs to look at them unless the user
  asks or a check needs it. Judge the result from tool data
  (`design_validate_plan`, `proj_get_nets`), not from pictures.
- **Datasheet PDFs are the biggest cost** (about 4–5k tokens per page,
  re-sent on every later turn). Read them in sub-agents that return only
  the card, and never read a whole PDF. See
  [datasheet-analysis.md](datasheet-analysis.md) §0.
- Read the `sch_preview_template` PNG once per approved change, not
  once per experiment. Each image costs context on every later turn.

## 1. Understand the circuit and ask (gate 1: spec)

Never copy a picture symbol for symbol. Papers draw ideal sources,
parasitics and load models that are not parts, and they leave out
ratings. Follow [circuit-intake.md](circuit-intake.md):

1. **Recognise** the topology and name its blocks in signal-flow order.
   Sort every element into real parts, ideal or model elements (sources
   become connectors, loads become connectors, parasitics such as L_m are
   absorbed into their part) and implied parts that are not drawn (gate
   drivers, sensing, auxiliary supply).
2. **Ask** the basic questions in one message, numbered, each with a
   suggested default: project path, input, output, switching frequency,
   scope (power stage with headers, or with drivers), mounting, plus the
   topology-specific ones. Skip what the user already said. Then wait for
   the answers.
3. **Check the design** with [design-checks.md](design-checks.md):
   run the checks for each block (gain at minimum input, switch and diode
   stress, resonant tank, ripple, gate-drive supply, insulation, ...) at
   worst case, and show one table with the numbers and ✅/⚠/❌. A ❌ gets
   a proposed fix and is never passed on silently. ERC cannot catch these
   errors.
4. **Rate**: turn the answers into a stress → required-rating table
   (default derating in the reference) and get the user's OK on the
   checks and the ratings together.

Do this even when the request is one line. Skip only the questions the
user's message already answers. Gate 1 can run before Altium is checked,
so the user can answer while you do the preflight.

## 2. Project set-up

The SKILL.md preflight (`boardwright_info`, `app_ping`) is done.

1. `design_get_discipline`, called once per conversation. The result holds
   the hard rules and the DesignPlan JSON schema that the drawing tools
   enforce. Follow it. It is large, so take the schema and the rules and
   skip the PCB sections.
2. Use the **project path** agreed in phase 1. Default:
   `<user's chosen folder>\<name>\<name>.PrjPcb`. If the path does not
   exist, `proj_create(project_path)` creates it. If the project exists,
   `proj_open` it and then `app_checkpoints(action="make", args={"label": "before boardwright schematic run"})`.
3. **Other open projects.** Call `proj_list_open`. If other projects are
   open (the user keeps real work open next to experiments), name them and
   take two precautions throughout: pass explicit paths to every tool that
   accepts one, and never call `app_save_all`. `sch_draw_template`
   does not save, and `proj_get_nets(force_recompile=true)` saves only
   the target project. If an Altium "Error" modal appears anyway,
   dismiss it with `app_press_dialog_button`, then save by path.

## 3. Parts: source, check, then create (gate 2: BOM)

Follow [part-sourcing.md](part-sourcing.md). For
every real part in the rating table, in this order:

0. **The verified store first:** read
   `%USERPROFILE%\Boardwright\verified\index.md`
   ([verified-parts.md](verified-parts.md)). A stored
   part that meets the rating comes with its card, symbol and footprint,
   so it needs no web search, no PDF and no new library work. Mark it
   "verified" in the BOM.
1. **The user's libraries:** `lib_get_installed_libraries`, then
   `design_snapshot_inventory(library_paths=[...])`. Match on function,
   value, package and rating, not on name strings. A matching part becomes
   `status="existing"` in the plan.
2. **Web search (main route, no key needed):** search manufacturer
   pages and parametric selectors by category + rating + package, and
   shortlist two or three real candidates per part. Cross-check on
   distributor pages where they load. Then run `part_search(query="<MPN>")`
   on the shortlist: without keys it still finds ready symbols and
   footprints (KiCad libraries, CERN/PartReel); with Mouser/DigiKey keys it
   adds stock and price. Never offer an MPN you did not see in this
   conversation.
3. **Datasheet analysis:** follow [datasheet-analysis.md](datasheet-analysis.md).
   **One read per unique MPN**: identical parts (S1–S8 with one MPN) share
   one card. **Hand each MPN to a sub-agent** (the Agent tool) that reads
   the PDF and returns only the card, so the pages never enter this
   conversation. Never read a PDF without `pages`; the budget is 5 pages
   per MPN.
   **Chip resistors and MLCCs are a series, not a part:** one short card
   per series and size (for example Yageo RC0603, Yageo CC0603 X7R)
   covers every value. Build the MPN from the series' ordering code, and
   store the card in the verified store as `series-<series>.md`, so the
   next design needs no web call at all. Spend at most two web calls per
   series. If the maker's site fails twice, take the series PDF from a
   distributor (LCSC, Mouser) or use a different maker's equivalent
   series; do not hunt for one value's spec sheet. (Live run 2026-11-08:
   one 100 Ω resistor and one 100 nF capacitor took 15 web calls.)
   `datasheet_fetch` the manufacturer PDF, read it, and write a
   **datasheet card** per part: ratings, key parameters, recommended use,
   pins, package and lifecycle, each with its page number, plus
   **schematic notes** (required support parts, Kelvin or tab pins,
   unused-pin handling). The card drives the symbol, the footprint, the
   plan parameters and the support parts on the sheet.
4. **BOM gate:** show the BOM table (ref, function, MPN, maker, stress →
   rating, package, lifecycle, stock or "not checked", datasheet), with the
   schematic consequences from the cards below it, and **wait for the
   user's OK** before you create any library part.
5. **Author it** for each approved part not already in a library. Use a project-local library that
   you create, never the user's libraries, which are read-only (discipline
   rule 13). Follow [library-authoring.md](library-authoring.md):
   - Get the **manufacturer datasheet** with a web search or fetch. Read
     the pin table and the package drawing from it, and cite the URL.
     Never take pin numbers or dimensions from memory.
   - Symbol: `lib_create_passive_symbol` for discretes (R, C, L, diode,
     LED, MOSFET, BJT, crystal, ...) and `lib_create_ic_symbol` for ICs,
     with the pins grouped by function: inputs, power and control on the
     left; outputs on the right.
   - Footprint: `footprint_check_package`, then
     `lib_create_footprint_from_package` (IPC-7351B lands from the
     datasheet's min/nom/max). `lib_create_standard_footprint` is the
     alternative when the datasheet gives the land pattern directly.
   - `lib_link_footprint(component_name, footprint_name)`.
   - **Save the SchLib and the PcbLib to disk** with
     `app_save_document(file_path=...)`. `sch_draw_template` reads the
     symbols from disk, and an unsaved SchLib makes it fail with an
     unresolved `lib_ref`.

Do not start the plan until every part resolves to a saved library
symbol.

## 4. Plan the circuit and its sheet (gate 3: preview)

A schematic comes from a **DesignPlan** (what the circuit is) plus a
**template** (where every part, wire, port and label goes). Do not place
parts one at a time with `sch_place_components` and connect them with
`sch_place_wires`; that gives a sheet that reads like nothing a person
would draw. Full guidance is in [design-plan.md](design-plan.md),
and a worked plan is in [../examples/nmos_low_side_switch.plan.json](../examples/nmos_low_side_switch.plan.json).

1. Build the plan. For anything bigger than a handful of parts, use
   `design_compose_netlist` with `add_part` / `add_block` / `connect_bus`
   ops rather than writing raw net JSON. Use the blocks from
   `design_list_circuit_blocks`: decoupling, pull-up, divider, crystal,
   LED, filters and switches. Group the parts into the blocks named in
   phase 1, in signal-flow order, so the sheet reads left to right like
   the user's picture.
2. Required: `spec`, `summary`, `sheets`, `parts`, `nets`. None may be
   empty, and **every net needs at least 2 pins**. A single-pin net is an
   ERC error waiting to happen. Rails get `is_power` and ground gets
   `is_ground`. Set `lib_path` on parts from the project-local SchLib.
3. `design_validate_plan(plan_json)` until `ok: true`.
4. Save the plan to `Design Notes\schematic_plan.json`, then
   `boardwright_draft_schematic(plan_path=...)`. It lays the sheet out by
   the drawing conventions (signal left to right, inputs on the left edge,
   shunts hung off their line, decoupling capacitors in a row by their IC,
   no crossings where a route around exists, every net named) and writes
   `Design Notes\schematic_draft.json` and a PNG. Read the PNG. Do not
   write a template from scratch: if something reads badly, edit the
   draft (move a part, turn it, reroute one wire through pin anchors such
   as `U1.EN`) or draft again with another `seed`. Save the result as
   `Design Notes\schematic_template.json`. `sheet_size_needed` in the
   reply means the drawing does not fit the plan's sheet size: change the
   size in the plan or split the sheet. Template rules: [design-plan.md](design-plan.md).
5. `sch_preview_template(template_path=..., plan_json=..., png_path=...)` checks
   the template against the symbols and the plan's nets and renders a PNG
   without drawing anything. It reads the symbols' pins through the
   bridge, so Altium must be up (the preflight). Fix every error and warning first. **Show the
   user the PNG path and the part/net summary, and wait for their OK
   before going on.** This is the approval gate.

## 5. Draw the sheet

1. Set the sheet size first (`sch_set_sheet_size`, from the plan's
   `sheets[].size`).
2. `sch_draw_template(template, document_path=<SchDoc>, plan_json=...)`
   places the parts, reads their real pins back, re-checks the wiring and
   only then draws wires, ports and labels and stamps Value /
   Manufacturer / MPN / Footprint from the plan.
3. Read the result: `stage` says where it stopped ("done" when complete)
   and `errors` why. A pin error means a pin id in the plan or template
   does not match the symbol: check it with `lib_get_pin_list`. A
   `needs_creation` part sends you back to phase 3.
4. Any later change is a **plan + template edit** and a redraw of that
   block on a fresh sheet. `sch_draw_template` refuses a designator that
   is already on the sheet. Do not hand-patch with `sch_*` tools except
   for a glyph the template cannot express.
5. Save the sheet and the project: `app_save_document(file_path=<SchDoc>)`
   and `proj_save`. Then `design_audit_schematic(project_path)` for
   overlaps, wires through bodies and stacked ports.

## 6. Compile and ERC loop

See [erc-loop.md](erc-loop.md).

1. `proj_compile(project_path)`.
2. `proj_run_erc`, then `proj_get_erc_violations`. Alternatively,
   `design_validate(project_path)` gives ERC, unconnected pins and
   atomic-part warnings in one report.
3. Judge connectivity from the **netlist** (`proj_get_nets`,
   `proj_get_unconnected_pins`, `proj_get_connectivity_many`), never from
   the picture.
4. Fix the cause in the plan, the template or the library, redraw, and
   re-check.
   Place a `sch_place_no_erc` marker only on a pin that is meant to be
   unconnected and is named in a violation's `related_objects`, and tell
   the user about each one. A marker placed by guesswork hides a real
   fault.
5. Stop after **3 rounds** that do not converge. Report the remaining
   violations and do not keep going.

## 7. Finish

**Promote new parts** to the verified store (full mode only, after ERC 0,
and only parts with a full datasheet card). Ask before the first time in
a conversation. See [verified-parts.md](verified-parts.md).

Report:
- the project path, the sheet, and the libraries created (symbol and
  footprint names)
- the approved BOM (MPN, maker, distributor stock as seen)
- the part count and the net list summary (`proj_get_nets`)
- the ERC result as errors/warnings, with each remaining warning
  explained (for example, a missing simulation model is expected)
- the datasheet URLs used, and any assumptions or `open_questions`

Save only by explicit path (`app_save_document`, `proj_save`), never with
`app_save_all`. Board work (netlist to PCB, placement, routing, DRC, fab
outputs) is the layout part of this skill, [layout.md](layout.md). Offer
it as the next step ("lay out the board for <project path>"). Before
offering it, point out any open design items that change the board
(custom magnetics not yet designed, heatsinking, creepage for high
voltage).
