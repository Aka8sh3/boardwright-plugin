# Compile and ERC loop

## Run

```
proj_compile(project_path=...)
proj_run_erc()                 # compiles first, then ERC on the focused project
proj_get_erc_violations()      # structured list: description, detail, related_objects[]
```

`design_validate(project_path=...)` reports ERC, unconnected pins and
atomic-part warnings together. It is the quickest pass/fail check.

Confirm that the focused project is the right one (`proj_get_focused`)
before you trust the result, since ERC runs on whatever project has focus.

## Read connectivity from the netlist

`proj_get_nets`, `proj_get_unconnected_pins`, `proj_get_connectivity_many`
and `obj_crossref_net` show what is actually connected. A render shows
layout only. A wire that looks joined in a PNG may not share a net.

## Usual violations and their fixes

| Violation | Usual cause | Fix |
|---|---|---|
| Floating input / unconnected pin | The pin is in no net | If it should be connected, add it to the right net in the plan and the template, and redraw. If it is intentionally unused (NC, an unused gate input that the datasheet says may float), place `sch_place_no_erc` on that pin and tell the user |
| Net with only one pin | A typo in a net name or pin id | Correct the plan. Every net needs at least 2 pins |
| Duplicate designator | Hand edits or two plans merged | `proj_annotate`, or renumber in the plan |
| Nets with multiple names | One net carries two labels or ports | Merge the nets in the plan (`design_edit_plan`) |
| Output pin to output pin / power pin conflict | Wrong `electrical_type` on an authored pin, or two drivers really are connected | Check the datasheet. If the symbol is wrong, fix the pin type in **your** library and re-place it. If the circuit is wrong, fix the plan |
| Missing simulation model (warning) | No SPICE model attached | Expected for schematic capture. Report it and leave it |
| Power object not connected | A port placed with no pin | Re-run the plan. Do not patch by hand |

To place a NoERC marker you need the pin's location. Find it from the
violation's `related_objects[].cross_probe`, or query it with
`obj_query(object_type="eSchPin", ...)` (ask `tool_guide` for the exact
filter). Then call `sch_place_no_erc(x, y)` with that location in mils.
Never place a marker on a pin that the datasheet says must be connected.

## Bounds

- At most **3 fix rounds**. If it has not converged, stop and report each
  remaining violation with its cause and your proposed fix.
- After every fix: redraw the block, save (`app_save_document` +
  `proj_save`), compile, and run ERC again.
- Done means **0 errors**. Every warning that is left has a one-line
  reason in the final report.
