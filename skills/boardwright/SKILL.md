---
name: boardwright
description: Design electronics in Altium Designer end to end with Boardwright - from a picture, block diagram or one-line request to an ERC-clean schematic with real, datasheet-checked parts (sourcing, SchLib symbols, PcbLib footprints, DesignPlan, hand template, ERC loop), then to a placed, routed, DRC-clean PCB with a fabrication package (board questions, fab-profile rules and stackup, netlist transfer without the ECO dialog, staged routing, pours, measured audits, Gerbers). Use when the user asks to create, draw, design, build or capture a schematic or circuit in Altium (including "build this" with an attached image), make a schematic symbol or footprint/library part, run or fix ERC or DRC, lay out, place or route a PCB, take a schematic to PCB, or produce Gerbers/fab outputs in Altium. Add "quick" for a cheap draft, or "demo" for a hands-free run with no questions or approval stops. Requires Altium Designer open; the skill starts the Boardwright bridge itself.
argument-hint: "[quick|demo] [what to design, a picture, an MPN or a project path]"
---

# Boardwright: idea → schematic → board → fab package

You drive Altium Designer through the `boardwright` MCP server, which
comes with this plugin. The design procedure is split into two parts that
you load when the job needs them:

| Part | File | Delivers |
|---|---|---|
| Schematic | [references/schematic.md](references/schematic.md) | a saved project with **ERC 0**, real parts, checked libraries |
| Layout | [references/layout.md](references/layout.md) | a routed board with **DRC 0**, measured audits passed, fab package |

## 1. Work out the job

Read the request and pick the route. Say the route in one line before you
start ("Schematic, then layout" or "Layout of <project>").

| The user wants... | Route |
|---|---|
| a circuit, a schematic, "build this" + picture | schematic part, then offer layout |
| a whole board from an idea ("design a board that...") | schematic part, then layout part |
| a symbol, a footprint or a library part only | schematic part, phase 3 only |
| ERC fixed on an existing project | schematic part, phases 2 and 6 |
| a board from an existing ERC-clean project | layout part |
| DRC fixed, placement or routing on an existing board | layout part, from the phase that applies |
| Gerbers or fab outputs only | layout part, phase 8 (after its preflight) |

Open a part file once, when its work starts, and follow it. When the
schematic part finishes and the user wants the board, open the layout
part; do not reload what is already in context (`design_get_discipline`
is loaded once per conversation for both parts).

**Modes** apply to both parts: **`quick`** (`draft`, `sketch`) gives a
cheap draft; **`demo`** (`hands-free`, `no questions`) runs without
questions or approval stops while still showing every result. Each part
file says what changes in its phases. A request that is unclear about
the mode ("just show me what it looks like") gets one question.

## 2. How to call the tools

- **Full toolset** (Claude Code): tools such as `app_ping` and
  `sch_draw_template` appear directly, with a plugin prefix
  (`mcp__plugin_boardwright_boardwright__app_ping`). The part files write
  the bare name. Tool families are folded behind one tool with an
  `action`, `how` or `kind` argument, for example
  `app_checkpoints(action="make", args={...})` and
  `pcb_calc(kind="trace_width_for_current", args={...})`.
- **Short tool list** (GitHub Copilot and other clients): only
  Boardwright's own tools plus `tool_guide`, `tool_catalog` and
  `tool_invoke` appear. Run every other tool as
  `tool_invoke(name="<tool>", arguments={...})`, and fetch its argument
  names first with `tool_catalog(query="<tool>", with_schema=true)`.
  Never guess argument names. See
  [references/tool-access.md](references/tool-access.md).
- **Either way:** load a deferred tool with ToolSearch before calling it;
  read a large saved result with Read (`offset`, `limit`) or Grep, never a
  shell; search only the project folder, never the home folder; and never
  run two edits to one board or library in the same turn. Details in
  tool-access.md, "Working rules".

Coordinates are in **mils**. Paths are absolute Windows paths with
backslashes. If no step covers what you need, ask
`tool_guide(task="...")` before you conclude that something cannot be
done. Do not drive Altium menus or dialogs (`app_menu`, `app_ui`) unless
the user agrees: doing so has crashed Altium.

## 3. Rules for every call

Each comes from a real incident:

1. **Save by path only:** `app_save_document(file_path=...)` and
   `proj_save`. Never `app_save_all`: it writes the user's other open
   projects and can raise a modal dialog that blocks the bridge.
2. **Focus the target before editing.** Board and library tools act on
   the active document. With other projects open, a board edit once
   landed on the user's thesis board. Pass explicit paths wherever a tool
   takes one, and `pcb_focus_board(board_path)` before board edits.
3. **No unattended modals.** Tools that open a dialog block the bridge
   until a human clicks. Use the headless routes the part files give.
   When a call reports a dialog on screen: `app_list_open_dialogs`. If its
   text is unreadable, `app_send_keys("ctrl+c")` while it is focused, then
   `app_get_clipboard` (both work while the bridge is blocked). Press a
   button only when you know what the dialog asks AND it concerns only the
   target project. A dialog you still cannot read gets no button, in demo
   mode too: stop and ask the user to read it (demo mode: stop the run and
   report it).
4. **Checkpoint before risky stages:**
   `app_checkpoints(action="make", args={"label": "..."})`.
5. **Judge from data, not pictures.** Netlists, audits and DRC/ERC
   numbers decide; renders are for the user's approval gates only. Each
   image and each datasheet page stays in context and costs tokens on
   every later turn.

## 4. Preflight (once per conversation)

1. `boardwright_info`. It gives the versions, the folders this skill uses
   (verified parts, fab profiles, runs), the `script_project` path and
   `python` for terminal fallbacks. The server prepares the PC by itself
   when it starts (folders, Altium scripts), so there is no setup step.
2. `app_ping`. Continue only when `success` and `version_match` are true.
   Otherwise follow [references/first-run.md](references/first-run.md).
   In short:
   - Altium is not running: ask the user to open Altium Designer. You
     cannot start it.
   - Altium is open but the bridge does not answer: ask the user, then
     `boardwright_start_bridge`. Nothing needs registering in Altium
     (never send the user to Global Projects).
   - A warning to close another `Altium_API.PrjScr`: the bridge works; ask
     the user to close that old copy in the Projects panel and go on.
   - `version_match` is false with `stale_units`: Altium still runs older
     scripts; the user closes and reopens the script project
     (first-run.md §2).
   - Anything else: `boardwright_doctor`.

   Ping again after each fix. In demo mode a failed preflight stops the
   run with one clear line.

The schematic part's first gate (the spec questions) may run before the
preflight, so the user can answer while you check Altium.

## 5. Finish

End with the part file's report. After a schematic, offer the board.
After a board, offer `design_session_report` for a full design report.
Never claim a result you did not measure: quote the ERC, DRC and audit
numbers the tools returned.
