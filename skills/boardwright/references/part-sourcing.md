# Part sourcing: web search first, then the datasheet

Input: the rating table the user confirmed in
[circuit-intake.md](circuit-intake.md). Output: a BOM the user approved,
with one real, orderable MPN per part and a datasheet card for each
([datasheet-analysis.md](datasheet-analysis.md)).

No API key is needed for this route. Distributor keys only add live stock
and price.

## 1. Find candidates with web search (the main route)

For each row of the rating table:

1. **The user's libraries first** (`lib_get_installed_libraries`,
   `design_snapshot_inventory`). A part they already use wins if it meets
   the rating.
2. **Web search** with the client's own tools (WebSearch / WebFetch in
   Claude Code, `fetch` / web search in Copilot). Search like an engineer:
   category + key rating + package, and aim at **manufacturer** pages and
   their parametric selectors. For example:
   - `SiC MOSFET 1200 V 30 A TO-247-4 site:wolfspeed.com OR site:infineon.com OR site:onsemi.com`
   - `fast recovery diode 1200 V 30 A TO-247 datasheet`
   - `film capacitor DC link 1100 VDC 10 uF datasheet`

   Shortlist **two or three candidates** per row from different makers.
   Distributor pages (mouser.com, digikey.com, farnell.com, lcsc.com) are
   good for cross-checking that a part is real and sold. They sometimes
   block automated fetches; when they do, rely on the maker page.
3. **`part_search(query="<MPN>")`** on the shortlisted MPNs. Without keys,
   it still searches the KiCad libraries installed on this PC, PartReel
   (CERN) and the public libraries, which give a **ready symbol and
   footprint** (`lib_kicad_import`). With `MOUSER_API_KEY` or
   `DIGIKEY_CLIENT_ID`/`_SECRET` set, it also returns stock and price.
   "unavailable" in `providers` means the key is missing, not that the
   part does not exist. Never stop the run over a missing key.

Reject a candidate that is NRND, obsolete or "not for new designs", or that
misses any number in the rating table. Never offer a part number you have
not seen on a maker or distributor page in this conversation. If no single
part meets a rating (for example an 18 kV switch), say so and offer a
series stack, a module or a clearly labelled generic placeholder.

## 2. Analyse the datasheet

For each shortlisted part, follow
[datasheet-analysis.md](datasheet-analysis.md) and build its datasheet
card. A candidate whose datasheet contradicts the rating table drops out.
Choose one part per row: the one with the best margin, the simplest
package, and the most distributors carrying it.

## 3. BOM approval gate

Show one table and **stop until the user approves it**:

| Ref | Function | MPN | Maker | Stress → part rating | Package | Lifecycle | Where sold / stock | Datasheet |
|---|---|---|---|---|---|---|---|---|

Write "stock not checked" when no key is set, and give the
mouser.com / digikey.com search link so the user can check it. Below the
table, list:

- the placeholders
- the assumptions
- the **schematic consequences** taken from the cards, for example
  "Q1–Q4 are TO-247-4: a Kelvin source pin goes to the gate header" or
  "U1 needs a 100 nF + 1 µF at VDD"

Change parts on request and show the table again. Create library parts
only after the user approves.

## 4. Optional keys (per PC, adds stock and price)

| Provider | Variables | Where to get them (free) |
|---|---|---|
| Mouser | `MOUSER_API_KEY` | mouser.com → My Account → APIs → **Search API** (not Cart API); activate it from the confirmation email |
| DigiKey | `DIGIKEY_CLIENT_ID`, `DIGIKEY_CLIENT_SECRET` | developer.digikey.com → organisation → production app with Product Information v4 |
| Nexar (Octopart) | `NEXAR_CLIENT_ID`, `NEXAR_CLIENT_SECRET` | portal.nexar.com |

Set each one as a **user** environment variable, for example
`[Environment]::SetEnvironmentVariable("MOUSER_API_KEY","<key>","User")`,
then restart VS Code or Claude Code. Never print a key's value.
