# First run on a PC, and getting the bridge answering

Boardwright comes as a Claude Code plugin with its own Python and engine,
so the PC needs only **Altium Designer**. There is no setup command: each
time the `boardwright` server starts it creates
`%USERPROFILE%\Boardwright\` (workspace, altium-scripts, verified,
fab_profiles, runs) and deploys the Altium bridge scripts of its own
build to `%USERPROFILE%\Boardwright\altium-scripts\`.
`boardwright_info` shows the folders, the `script_project` path and
`scripts_deployed`, and works even when Altium is closed.

## 1. Register the script project in Altium (once per PC)

The user does this by hand, once:

**Preferences → Scripting System → Global Projects → Install from file**
→ the `script_project` path from `boardwright_info`
(`%USERPROFILE%\Boardwright\altium-scripts\Altium_API.PrjScr`).

Give the user that path and these steps. You cannot click it for them.

## 2. Start the bridge (each Altium session)

Altium Designer must already be open. Ask the user whether you may start
the bridge, then call **`boardwright_start_bridge`**. It hands
`StartMCPServer` to the running Altium the same way Altium's own Run
Script menu does, and does nothing if the bridge already answers. The
**Boardwright - Altium bridge** status window appears in Altium.

If it reports an error, or nothing appears, the user starts it by hand:
**File → Run Script… → Altium_API → Dispatcher.pas → StartMCPServer →
Run**. If Altium shows a script error, step 1 was not done.

## 3. Check

Run `app_ping`. You need `success: true` and `version_match: true`.

- `version_match: false` or `stale_units` not empty: Altium is still
  running the scripts it compiled from an older build. The server has
  already deployed the new ones; the user closes the bridge window and
  closes and reopens the `Altium_API` script project (or restarts
  Altium), then the bridge is started again.
- Still failing: call **`boardwright_doctor`**. It checks the runtime, the
  folders, the deployed scripts, other Altium servers that would fight
  over the bridge (an old `altium` server must be removed: the last
  server started takes the bridge), and the live link, each with the fix.

## Terminal fallback

The same commands exist for a terminal. Get the interpreter from
`boardwright_info` (field `python`) and run `"<python>" -I -m boardwright
doctor`, `relaunch` or `setup` (prepares the PC now and prints the
Altium step). Ask the user before running any of them.

## Things you cannot do

- Start Altium Designer itself or sign in to its licence. The user does
  that.
- Register the script project in Altium (step 1). The user clicks it once.
- Click through Altium's ECO dialog (`proj_sync_pcb`). That is a human
  click by design.
