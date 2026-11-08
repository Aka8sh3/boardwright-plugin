# Calling Boardwright tools in either toolset

The `boardwright` MCP server registers about 570 tools (tool families
are folded behind one tool with an `action`, `how` or `kind` argument).
Claude Code is shown all of them. Every other client (GitHub Copilot in
VS Code caps a request at 128 tools) is shown a short list: Boardwright's
own tools (`boardwright_info`, `boardwright_start_bridge`,
`boardwright_doctor`, `boardwright_draft_schematic`), `tool_guide` and the
two meta-tools `tool_catalog`
and `tool_invoke`, which reach all the others. Below, "minimal" means that
short list.

In Claude Code the plugin's tools carry a prefix, for example
`mcp__plugin_boardwright_boardwright__app_ping`. This skill writes the bare
name (`app_ping`); call the tool that ends in it.

| You see... | Mode | How to call `proj_compile` |
|---|---|---|
| `app_ping`, `proj_compile`, `sch_draw_template`, ... | full | `proj_compile(project_path="C:\\...\\x.PrjPcb")` |
| `boardwright_*`, `tool_guide`, `tool_catalog`, `tool_invoke` only | minimal | `tool_invoke(name="proj_compile", arguments={"project_path": "C:\\...\\x.PrjPcb"})` |

The server picks the list from the client's name when it connects;
Claude Code (CLI and VS Code extension) gets the full list.

## Minimal-mode routine

1. Look up the argument names once per tool:
   `tool_catalog(query="lib_create_ic_symbol", with_schema=true)`.
   The `parameters` and `required` fields it returns are the contract.
2. Call the tool:
   `tool_invoke(name="lib_create_ic_symbol", arguments={...})`.
3. A wrong argument comes back as the tool's own error, because nothing
   validates it beforehand. Re-read the schema and do not guess again.

Use `tool_catalog(category="design", with_description=true)` to browse a
whole category. The categories are core, application, project, library,
schematic, design, audit and parts. Add `interaction="modal"` to find the
tools that open a blocking dialog, and avoid them while running unattended.

## Server-side helpers worth knowing

- `tool_guide(task="...")` names the right tool for a task and lists what
  is impossible. Ask it before you decide a capability is missing.
- `design_get_discipline` returns the hard rules and the DesignPlan schema.
- `design_list_circuit_blocks` returns the exact parameter names of every
  canonical block. A mistyped optional key is dropped silently.

## Tools the schematic part uses

| Phase | Tools |
|---|---|
| Preflight | `boardwright_info`, `app_ping`, `boardwright_start_bridge`, `boardwright_doctor`, `design_get_discipline`, `proj_list_open`, `proj_create`, `proj_open`, `app_checkpoints` |
| Library | `lib_get_installed_libraries`, `design_snapshot_inventory`, `part_search`, `app_create_document`, `app_set_active_document`, `lib_create_passive_symbol`, `lib_create_ic_symbol`, `footprint_check_package`, `lib_create_footprint_from_package`, `lib_create_standard_footprint`, `lib_link_footprint`, `lib_get_pin_list`, `app_save_document` |
| Plan | `design_list_circuit_blocks`, `design_compose_netlist`, `design_add_part`, `design_add_circuit_block`, `design_edit_plan`, `design_validate_plan`, `boardwright_draft_schematic`, `sch_preview_template` |
| Draw | `sch_set_sheet_size`, `sch_draw_template`, `app_save_document`, `proj_save`, `design_audit_schematic` |
| ERC | `proj_compile`, `proj_run_erc`, `proj_get_erc_violations`, `design_validate`, `proj_get_nets`, `proj_get_unconnected_pins`, `proj_get_connectivity_many`, `sch_place_no_erc` |
