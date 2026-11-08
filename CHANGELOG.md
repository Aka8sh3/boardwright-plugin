# Changelog

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
