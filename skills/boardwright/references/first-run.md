# First run on a PC, and getting the bridge answering

Boardwright comes as a plugin with its own Python and engine, so the PC
needs only **Altium Designer**. There is no setup command: each time the
`boardwright` server starts it creates `%USERPROFILE%\Boardwright\`
(workspace, altium-scripts, verified, fab_profiles, runs), deploys the
Altium bridge scripts of its own build to
`%USERPROFILE%\Boardwright\altium-scripts\` and writes the launcher
`Start Boardwright in Altium.cmd` there (the installer puts a desktop
shortcut to it). `boardwright_info` shows the folders, the
`script_project` path and `scripts_deployed`, and works even when Altium
is closed.

**Nothing is registered inside Altium.** Boardwright starts the bridge by
the script project's full path. Do not send the user to Preferences →
Scripting System → Global Projects: current Altium versions do not show
that page, and Boardwright does not need it.

## 1. Start the bridge (each Altium session)

Altium Designer must already be open. Ask the user whether you may start
the bridge, then call **`boardwright_start_bridge`**. It hands
`StartMCPServer` from the `script_project` path to the running Altium and
does nothing if the bridge already answers. The **Boardwright - Altium
bridge** status window appears in Altium.

If it reports an error, or nothing appears, the user starts it by hand:

- double-click **Start Boardwright in Altium** on the desktop, or
- in Altium: **File → Open…** → the `script_project` path, then **File →
  Run Script… → Altium_API → Dispatcher.pas → StartMCPServer → Run**.

## 2. Check

Run `app_ping`. You need `success: true` and `version_match: true`.

- A warning **"Close the other Altium_API.PrjScr …"**: an older copy of the
  script project (for example `EDA Agent\scripts`) is also open in Altium.
  The bridge is fine; ask the user to right-click that other copy in
  Altium's Projects panel → **Close Project**, so later checks compare
  against the right files.
- `version_match: false` with `stale_units` listed: Altium still runs
  scripts it compiled from an older build. The user closes the bridge
  window, right-clicks `Altium_API.PrjScr` in the Projects panel → **Close
  Project**, and the bridge is started again (step 1).
- Still failing: call **`boardwright_doctor`**. It checks the runtime, the
  folders, the deployed scripts, other Altium servers that would fight
  over the bridge (an old `altium` server must go: the last server started
  takes the bridge; the fix is `boardwright setup --clean-old`), and the
  live link, each with the fix.

## Terminal fallback

The same commands exist for a terminal. Get the interpreter from
`boardwright_info` (field `python`) and run `"<python>" -I -m boardwright
doctor`, `relaunch` or `setup`. Ask the user before running any of them.
In PowerShell the line starts with `&`: `& "<python>" -I -m boardwright
relaunch`.

## Things you cannot do

- Start Altium Designer itself or sign in to its licence. The user does
  that.
- Close or open projects in Altium's Projects panel for the user.
- Click through Altium's ECO dialog (`proj_sync_pcb`). That is a human
  click by design.
