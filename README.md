# Boardwright

**AI design assistant for Altium Designer.** You describe a circuit in
chat, or attach a picture or block diagram, and Boardwright builds it in
Altium: real parts checked against their datasheets, an ERC-clean
schematic, then a routed, DRC-clean board and the fab package. It stops
for your approval at each important step.

It is a **Claude Code plugin** (CLI or the VS Code extension), and GitHub
Copilot Chat in VS Code can use the same plugin. It brings its own Python
and engine, so the PC needs only Altium Designer. Nothing has to be
registered inside Altium.

## Install (once per PC)

You need: Windows 10/11, **Altium Designer** (licensed), **Claude Code**
(the VS Code extension or the CLI), and read access to this repository
(ask for it).

**With the installer (recommended).** Save `Install-Boardwright.ps1` from
this repository, then in PowerShell:
```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\Install-Boardwright.ps1"
```
It checks Altium, Git and Claude Code, installs the plugin, makes GitHub
Copilot Chat in VS Code load it too, removes an older eda-agent set-up
(listed in `%USERPROFILE%\Boardwright\old-setup-removed.json`), prepares
the Altium scripts and puts a **Start Boardwright in Altium** shortcut on
the desktop. Git may open a browser once to sign you in to GitHub.
Options: `-NoCopilot`, `-KeepOld`, `-NoShortcut`, `-Yes`, `-Uninstall`.
Restart VS Code afterwards.

**By hand, in Claude Code:**
```
/plugin marketplace add https://github.com/Aka8sh3/boardwright-plugin.git
/plugin install boardwright@boardwright
```
Use the full https address: the short `Aka8sh3/boardwright-plugin` form
clones over SSH, which needs a GitHub SSH key. Restart Claude Code; the
first start prepares `%USERPROFILE%\Boardwright\` and the Altium scripts.

## Starting the bridge in Altium

Open Altium Designer, then either let Boardwright start the bridge (it
asks first), or double-click **Start Boardwright in Altium** on the
desktop. The **Boardwright - Altium bridge** window appears in Altium.
Without the shortcut: **File → Open…** →
`%USERPROFILE%\Boardwright\altium-scripts\Altium_API.PrjScr`, then **File
→ Run Script… → Altium_API → Dispatcher.pas → StartMCPServer**.

## Use

One skill does the whole flow and picks the part it needs. Claude Code
lists it as `/boardwright:boardwright` (type `/boardwright` and pick it).
In GitHub Copilot Chat use Agent mode and type `/boardwright`. The
examples below write it short:

- Attach a circuit picture and type `/boardwright build this`. Boardwright
  names the topology, asks the key questions with defaults, runs
  worst-case design checks, finds real parts, reads each datasheet into a
  cited card, and shows the BOM before it builds. Stops: **spec → BOM →
  preview**.
- `/boardwright NMOS low-side switch, 3.3 V logic driving a 12 V load, project C:\Altium\nmos_switch`
- `/boardwright lay out C:\Altium\nmos_switch\nmos_switch.PrjPcb`. Stops:
  **board spec → placement → final board**.
- `/boardwright design a 24 V to 5 V 2 A buck board` runs both parts.
- Add **`quick`** for a fast draft or **`demo`** for a hands-free run.

You can also just ask in plain words ("draw this circuit in Altium"); the
skill starts by itself. Examples to try: `examples\block-diagrams\`.

## Your data

Everything Boardwright learns stays on your PC in
`%USERPROFILE%\Boardwright\`: `verified\` (parts that passed a full run,
reused first next time), `fab_profiles\` (fab-house capabilities with
their source), `runs\` (reports), and `altium-scripts\` + `workspace\`
(the Altium bridge). Updating or uninstalling the plugin keeps it.

## Part search keys (optional)

Without keys, parts are found by web search on manufacturer sites. For
stock and price, set user environment variables and restart Claude Code:
`MOUSER_API_KEY`, or `DIGIKEY_CLIENT_ID` + `DIGIKEY_CLIENT_SECRET`.

## Update and uninstall

- **Update:** run the installer again, or `/plugin marketplace update
  boardwright` in Claude Code; then restart VS Code. The new Altium
  scripts are deployed on the next start: in Altium, close the
  *Altium_API* script project (Projects panel → right-click → Close
  Project) and start the bridge again so Altium recompiles it.
- **Uninstall:** run the installer with `-Uninstall`, or
  `/plugin uninstall boardwright@boardwright`. Your data folder stays.

## Troubleshooting

Ask the AI to run **`boardwright_doctor`**: it checks the whole set-up
and names each fix.

| Symptom | Fix |
|---|---|
| "Close the other Altium_API.PrjScr …" | An older copy of the script project is open too. Projects panel → right-click it → **Close Project** |
| `version_match: false` with `stale_units` | Close the *Altium_API* script project in Altium and start the bridge again |
| Doctor warns that `altium` is also registered, or about old skill links | An older eda-agent set-up is still configured (only one server may drive Altium): run the installer again, or `"<python>" -I -m boardwright setup --clean-old` |
| Copilot does not show `/boardwright` | Check that **Chat › Plugins: Enabled** is on in VS Code settings and that **Chat: Plugin Locations** lists the Boardwright folder; run the installer again |
| Updating says a file is in use | VS Code's Copilot is running Boardwright from that folder: close VS Code, then update |

## Before using it on company designs

Boardwright sends the design content you work on (schematics, part lists,
your prompts) to the AI service behind Claude Code, or behind GitHub
Copilot when you use it there. Use it on company
designs only where your company's AI and data policy allows that service.
Altium itself and your files stay on your PC.

## Credits and licence

Boardwright is licensed under Apache-2.0 (`LICENSE`, `NOTICE`). Its
engine, which connects to Altium, is a modified version of
[eda-agent](https://github.com/salitronic/eda-agent) by George Saliba
(Apache-2.0, `LICENSES/eda-agent/`). The bundled Python and libraries keep
their own licences in `runtime\`.
