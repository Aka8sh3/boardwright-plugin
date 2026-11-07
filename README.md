# Boardwright

**AI design assistant for Altium Designer.** You describe a circuit in
chat, or attach a picture or block diagram, and Boardwright builds it in
Altium: real parts checked against their datasheets, an ERC-clean
schematic, then a routed, DRC-clean board and the fab package. It stops
for your approval at each important step.

It is a **Claude Code plugin** (CLI or the VS Code extension). It brings
its own Python and engine, so the PC needs only Altium Designer.

## Install (once per PC)

You need: Windows 10/11, **Altium Designer** (licensed), **Claude Code**
(CLI or VS Code extension), and read access to this repository.

1. In Claude Code, add the marketplace and install the plugin:
   ```
   /plugin marketplace add Aka8sh3/boardwright-plugin
   /plugin install boardwright@boardwright
   ```
   Restart Claude Code (or reload the VS Code window). The first start
   prepares `%USERPROFILE%\Boardwright\` and the Altium scripts by itself.
2. In **Altium Designer**, once: **Preferences → Scripting System → Global
   Projects → Install from file** →
   `%USERPROFILE%\Boardwright\altium-scripts\Altium_API.PrjScr`.

That's all. Each session, Boardwright starts its bridge in the open Altium
for you (it asks first). By hand it is **File → Run Script… → Altium_API
→ Dispatcher.pas → StartMCPServer**.

## Use

One skill, `/boardwright`, does the whole flow and picks the part it
needs:

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

- **Update:** `/plugin marketplace update boardwright`, then restart
  Claude Code. The new Altium scripts are deployed on the next start;
  close and reopen the script project in Altium so it recompiles.
- **Uninstall:** `/plugin uninstall boardwright@boardwright`, then remove
  *Altium_API* from Altium's Global Projects.

## Troubleshooting

Ask Claude to run **`boardwright_doctor`**: it checks the whole set-up
and names each fix.

| Symptom | Fix |
|---|---|
| Altium shows a script error when the bridge starts | Do install step 2 (Global Projects) |
| `version_match: false` | Close and reopen the *Altium_API* script project in Altium |
| Doctor warns that `altium` is also registered | An older eda-agent setup is still configured: `claude mcp remove altium -s user`. Only one server may drive Altium |
| Doctor warns about old skill links or a second `boardwright` server | Boardwright 1.0 was installed with `Install.cmd`: run its `Uninstall.cmd`, or `<python> -I -m boardwright remove` |

## Before using it on company designs

Boardwright sends the design content you work on (schematics, part lists,
your prompts) to the AI service behind Claude Code. Use it on company
designs only where your company's AI and data policy allows that service.
Altium itself and your files stay on your PC.

## Credits and licence

Boardwright is licensed under Apache-2.0 (`LICENSE`, `NOTICE`). Its
engine, which connects to Altium, is a modified version of
[eda-agent](https://github.com/salitronic/eda-agent) by George Saliba
(Apache-2.0, `LICENSES/eda-agent/`). The bundled Python and libraries keep
their own licences in `runtime\`.
