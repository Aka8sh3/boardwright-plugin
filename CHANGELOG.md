# Changelog

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
