# Changelog

## 1.1.0rc8 (2026-11-09), from the buck-board live run

The second full `/boardwright demo` run (TPS54202 buck + AP2112K LDO, 17
parts, 4 of them built from datasheets) reached Gerbers with Altium's DRC
at 0, and showed where the tools had reported success for work that did
not happen. Engine 0.8.1 (`boardwright-engine`):

- **`design_validate` tells the truth about ERC.** It read the Messages
  panel, which carries no severity, filed "Nets containing floating input
  pins" as info and answered `passed: true` beside a `proj_run_erc` that
  listed it as an error. It now reads the ERC run's own list with Altium's
  levels, and an ERC that could not run (a modal on screen) fails.
- **No ERC markers count on the next ERC.** Altium's ERC ignores a marker
  placed or deleted by script until the sheet is closed and opened again,
  through saves and forced recompiles. `sch_place_no_erc` and the `obj_`
  tools note the sheet, and the next `proj_run_erc`, `run_erc` or
  `design_validate` saves, closes and reopens it first
  (`reopened_sheets`). A save that reads as unwritten inside Altium's
  2-second file-time tick is retried before the close.
- **No board edit outlives its request.** A handler that left a PCB edit
  open kept Altium's transaction open for good (each request zeroed the
  count without closing it), and the next library save raised "A command
  is currently active and save cannot be completed". The request loop now
  closes any edit left open, and a board or library save unwinds an
  abandoned one first.
- **`lib_copy_footprint` into another library** opens it, copies, saves it
  by path and reads the copy back; it is not a success unless the save
  reached the file. Altium had loaded the closed library as a hidden copy
  that no save reaches.
- **`pcb_cleanup_tracks` and `pcb_gloss` are measured and run one at a
  time.** With `expect_file` each compares missing connections, unreached
  pads and clearances between routed copper before and after, and answers
  `ok: false` with `made_worse` when it broke something. A routing lock
  keeps two of them from editing one board at once. Live: a sliver pass
  on the buck board broke 2 connections, and said so.
- **`pcb_run_drc` repours first**, since a stale pour raises a modal
  ("shelved or modified (but not repoured) polygons") and a wrong answer.
- **Silkscreen against the board edge:** `pcb_layout_audit` has
  `silk_audit` (overlay text, designators included, beyond the outline),
  from each text's own box in Altium. The review render now draws
  mirrored bottom text running left from its anchor: drawn the other way,
  the run's on-board text looked off the board.
- A plan may be given as the path of its `.json` file to every
  `plan_json` argument (`design_validate_plan`, `sch_draw_template`,
  ...); `pcb_place_components` takes `Top` / `Bottom` as layers.
- Upkeep: engine 0.8.1 (0.8.0 was tagged), SECURITY.md, no console window
  from the dev proxy, a test that slept now waits on its condition, and a
  dev venv with the `[dev]` extra runs the whole engine suite (8,048
  passed).

Skill: one board edit at a time and tidy-ups measured
(`references/layout.md`), the No ERC reopen and what `design_validate`
now means (`erc-loop.md`), the silk gate (`outputs.md`), and working rules
for Claude Code: load deferred tools first, read large results with Read
or Grep, search only the project folder (`SKILL.md`, `tool-access.md`).

## 1.1.0rc7 (2026-11-09), from the first idea-to-Gerbers live run

The first full `/boardwright demo` run (NMOS board: schematic with the
drafter, ERC, 40 x 35 mm 2-layer board, Gerbers) took 11.1 min, $6.56 and
132 tool calls, against 15.4 min, $11.30 and 194 calls for rc5's
schematic alone. What it showed:

- **Altium's DRC was skipped in demo mode.** The skill still listed
  `pcb_run_drc` as a tool that opens a dialog; it has run headless since
  engine 0.8. Run by hand, it found two silk-to-silk violations the
  measured audits do not check. Demo mode now runs `pcb_run_drc()` like
  every other mode (`references/layout.md`, `outputs.md`).
- **Mirrored parts in templates** (`boardwright-engine` 97a1439): a template part
  takes `"mirrored": true`, reflected left to right after the rotation as
  Altium mirrors. `sch_preview_template` predicts the mirrored pins;
  `sch_draw_template` mirrors the part after placing it and checks every
  pin against the prediction before the first wire. The run's load
  terminal on the right edge had looped its 12 V wire down and back up,
  because at rotation 180 its rail pin is the lower one.
- **The drafter mirrors connectors** where that gives the better pin
  order: a rail's pin on top, ground's at the bottom, otherwise pin 1 on
  top. The order is decided, not searched.
- **The drafter knows each symbol's real outline.** It reads the symbol's
  graphics through the bridge (one batched query per symbol) and scores
  parts whose outlines meet, as `design_audit_schematic` does on the
  drawn sheet: the run's D1 ran 20 mil into J3's box, which the pins
  alone did not show. The outline model reproduces Altium's
  BoundingRectangle on the run's parts exactly.
- Live check on a scratch project: drafted with outlines read live, drawn
  with J3 mirrored, pins read back as predicted, audit 0 overlaps, ERC
  passed.

## 1.1.0rc6 (2026-11-08), the schematic drafter

- **`boardwright_draft_schematic`**: a DesignPlan in, a sheet drawn by the
  conventions out, as a template for `sch_preview_template` /
  `sch_draw_template` plus a picture. It reads the circuit the way an
  engineer does (rails, ground, signals; series parts in the path, shunts
  hung off the line they load, decoupling capacitors by their IC; input
  connectors left, outputs right, other connectors by their pins), then
  searches placements, routes each one with a schematic maze router (no
  touching another net's pin or wire end, crossings only at right angles,
  no four-way joins, power and ground symbols, net labels where a wire
  would run long) and scores it with the engine's own template checker.
  `src/boardwright/layout/`.
- Measured on the first live run's NMOS switch, same plan and library:
  the agent's hand-written template had 10.5 in of wire over 8.9 sq in;
  the draft has 2.5 in over 3.0 sq in, no crossings and no warnings, and
  the engine's `sch_preview_template` passes it against the plan pin by
  pin with the pins read live from Altium.
- In the short tool list Copilot sees.
- **Engine** (`boardwright-engine` b83b346): the template checker no
  longer reports every power port's name as overlapping its own symbol.
- **Skill:** the schematic phase drafts first and reviews, instead of
  writing a template from nothing; connectors get a `role`.

## 1.1.0rc5 (2026-11-08), fixes from the first live design run

The first full `/boardwright` run on AD23 (NMOS low-side switch, demo
mode) reached ERC 0 and a netlist matching the plan pin for pin, and took
15.4 min, $11.30 and 194 tool calls. What it ran into:

- **Engine** (`boardwright-engine` 85d2e78):
  - `force_recompile` saved every open document (8 other projects were
    open) and raised a Yes/No Warning that blocked the bridge; it now
    saves only the target project.
  - Tools that build on "the current component" (`lib_create_passive_symbol`,
    `lib_copy_footprint`, the footprint creators) run their `items` in
    order; gathered, all pins landed on one symbol and copies wrote nothing.
  - `design_audit_schematic` no longer audits the project's `.SchLib` as a
    sheet (false overlaps).
  - Diode symbols name their pins A and K and take `pin_map`
    (`{"K":"1","A":"2"}` for cathode-1 rectifiers).
  - `app_get_clipboard` reads through Windows, so a blocking dialog's text
    (Ctrl+C) can be read.
- **Runtime:** matplotlib and Pillow are bundled (the engine's `render`
  extra): the schematic preview PNG and `app_screenshot` work. 309 MB.
- **Skill:**
  - A dialog it cannot read gets no button press, in demo mode too: read
    it via Ctrl+C + `app_get_clipboard`, otherwise stop and ask.
  - Chip resistors and MLCCs get one card per series (`series-*.md` in the
    verified store), at most two web calls per series; the run spent 15 on
    one resistor and one capacitor.
  - `footprint_check_package` takes `pins` (the reference said
    `pin_count`); diode `pin_map` documented.

## 1.1.0rc4 (2026-11-08), first start within Claude Code's limit

From the first headless live run of rc3: the plugin's server did not
connect, because Claude Code gives an MCP server 30 s to start and a
fresh plugin copy compiled ~1000 Python modules first (29.1 s measured on
a fresh copy, over the limit in the real run).

- **The plugin ships compiled bytecode** (`compileall --invalidation-mode
  unchecked-hash`, valid after a git clone resets file dates): first
  start 11.8 s, later starts 2.6 s. +44 MB.
- **Installer updates an installed plugin:** `plugin install` left rc2 in
  place; the installer now runs `plugin update` too and prints the
  version that is active.
- **Copilot loads the installed version folder, not the marketplace
  copy.** With VS Code open, its watch on the marketplace folder made
  `marketplace update` fail (EPERM on rename). The server moves Copilot to
  each new version at start; the installer frees an rc3 entry before it
  updates and retries while VS Code lets go.

## 1.1.0rc3 (2026-11-07), installer, Copilot, no Altium registration

From the first live test of rc2 on AD23 (plugin installed from GitHub,
bridge up, doctor live checks passing):

- **Nothing to register in Altium.** The bridge is started by the script
  project's full path, which AD23 accepted without a Global Projects
  entry (that preferences page is not in current Altium versions). The
  doctor reports the engine's "script registration" check as not needed;
  README and skill no longer send anyone to Global Projects.
- **`Install-Boardwright.ps1`:** one PowerShell run checks Altium, Git and
  Claude Code (offers to install the last two), installs the plugin,
  registers it for GitHub Copilot, removes an older eda-agent set-up
  (saved to `old-setup-removed.json`), prepares the PC, adds a desktop
  shortcut "Start Boardwright in Altium", optionally starts the bridge
  and runs the doctor. `-Uninstall` undoes it (data stays).
- **GitHub Copilot in VS Code** loads the same plugin folder
  (`boardwright setup --copilot` sets `chat.pluginLocations`; it replaces
  rc2's separate mcp.json server). The server shows Copilot and other
  clients a short tool list (`boardwright_*`, `tool_guide`, `tool_catalog`,
  `tool_invoke`) and Claude Code the full one.
- **Bridge launcher** `%USERPROFILE%\Boardwright\Start Boardwright in
  Altium.cmd`, rewritten by the server whenever the runtime moves.
- `boardwright setup --clean-old` removes an old `altium` server (Claude
  Code and VS Code), the old `altium-schematic` / `altium-pcb-layout`
  skill links and the old plugin.
- **Engine (app_ping):** with two `Altium_API.PrjScr` copies open, the
  check compared the running bridge with the first one listed and called
  a current bridge stale. It now compares with the copy whose stamps the
  running units carry (`bridge_runs_from`) and names the copy to close.
- `boardwright remove --data` refuses a folder that holds a source
  checkout.

## 1.1.0rc2 (2026-11-07), Claude Code plugin, not yet live-tested

- **One plugin, one skill.** Boardwright installs from a Claude Code
  marketplace (`/plugin install boardwright@boardwright`) and brings its
  runtime with it. `Install.cmd` and the release zip are gone.
- **One `/boardwright` skill** replaces `/boardwright-schematic` and
  `/boardwright-layout`. It works out the job, then loads the schematic or
  layout procedure (`references/schematic.md`, `references/layout.md`).
- **No setup step:** the server prepares the PC each time it starts
  (folders, one-time copy of old data, Altium scripts when this build has
  not deployed them yet).
- **New tools** `boardwright_start_bridge` (starts StartMCPServer in the
  running Altium) and `boardwright_doctor` (checks the set-up), so the
  skill needs no terminal commands.
- `boardwright setup` only prepares the PC by hand (`--copilot` registers
  GitHub Copilot); `boardwright remove` and the doctor clean up and flag
  Boardwright 1.0 registrations, an old `altium` server and the old
  `altium-schematic` plugin.

## 1.1.0rc1 (2026-11-07), engine 0.8.0, not yet live-tested

- **Engine moved to eda-agent 0.8.0** (about 570 tools, up from 490):
  branch `boardwright-0.8` with 8 Boardwright commits (see
  `docs/ENGINE.md`). Four 0.7.0 patches were dropped because 0.8.0 fixes
  the same problems itself.
- **Schematics are drawn from a hand template:** the schematic skill now
  goes DesignPlan → template → `sch_preview_template` (PNG, the approval
  gate) → `sch_draw_template`. The automatic layout engine is gone
  upstream.
- **Tool names** updated for 0.8.0's folded families (`app_checkpoints`,
  `pcb_calc(kind=...)`, `obj_*` with `items`, `pcb_place_vias`,
  `app_menu` / `app_ui`). Every tool a skill names was checked to exist.
- **Retired gotchas:** Altium DRC runs without a dialog; the silk-to-mask
  rule gap is written by script.
- The engine's own updater is off in Boardwright (`EDA_AGENT_SELF_UPDATE=0`):
  only a Boardwright release updates the engine.
- Setup deploys the Altium scripts to the Boardwright folder and to every
  folder Altium already loads them from.

## 1.0.0 (2026-11-07)

First Boardwright release. Rebuilt from the earlier altium-agent-plugin
(v2.0.0) as its own product.

- **Name and identity:** the MCP server is `boardwright`; skills are
  `/boardwright-schematic` and `/boardwright-layout`; the Altium status
  window reads "Boardwright - Altium bridge".
- **Boardwright layer** (`src/boardwright`): wraps the engine, adds the
  `boardwright_info` tool, and the `boardwright` command with `setup`,
  `doctor`, `relaunch`, `remove`, `info`.
- **One data folder per user:** `%USERPROFILE%\Boardwright\` (workspace,
  altium-scripts, verified, fab_profiles, runs). Setup copies an existing
  verified store and fab profiles from `%USERPROFILE%\EDA Agent\` once.
- **Installer:** `Install.cmd` installs per user without admin rights and
  registers the server in Claude Code (full toolset) and VS Code Copilot
  (minimal toolset). `Uninstall.cmd` undoes it and keeps your data.
- **Engine as a patch series:** eda-agent 0.7.0 plus nine commits in
  `boardwright-engine` (see `docs/ENGINE.md`), instead of files edited
  inside the bundled runtime.
- **Reproducible release:** `tools/build_runtime.ps1` downloads the
  official Python 3.12.10 embeddable zip, checks its SHA-256 and stamps
  `runtime\BUILD.json` with the commits; `tools/build_release.ps1` writes
  the zip and its SHA-256. The runtime is no longer stored in git.
- Skills: preflight uses `boardwright_info` for the interpreter and folders
  (the old "two folders above SKILL.md" rule broke through skill links).
