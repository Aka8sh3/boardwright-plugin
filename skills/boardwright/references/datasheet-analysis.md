# Datasheet analysis: from the PDF to the schematic

The datasheet is the only source for ratings, pins, package dimensions
and the support parts a device needs. Library metadata, distributor
summaries and memory are not sources. This step turns each datasheet into
a **datasheet card**, and the card drives the library part, the plan and
the BOM.

## 0. Token budget: read once, read little

Datasheets are the largest token cost of a run. A PDF page read into the
conversation costs about **4–5k tokens** (page image plus text), and
everything read stays in context and is re-sent on every later turn. In
the first full run (45 parts), PDF pages took about 400k of 590k message
tokens, and four PDFs were read whole. So:

- **Read datasheets in a sub-agent when the client has one** (the Agent
  / Task tool in Claude Code, a sub-agent in Copilot). Give it one MPN
  (or a short list), the URL, the rating row and the card template from
  section 2. Tell it to `datasheet_fetch`, read only the pages it needs,
  and **return only the card**. The PDF pages then stay in the
  sub-agent's context, and the main conversation receives about 500
  tokens per part. Run the sub-agents for different MPNs in parallel.
  Without a sub-agent tool, read inline under the rules below.
- **Never read a PDF without `pages`.** The first read is
  `pages: "1-2"` (features, absolute maximum, pinout, often the page
  index). Then read only the named pages: package drawing, land pattern,
  application circuit. **Budget: at most 5 pages per MPN** (3 for a
  diode, a capacitor or a connector). Go over it only to answer a named
  question, and say why.

- **One card per unique MPN.** Group the BOM by MPN first. Eight switches
  with one part number get one card, which every ref then uses.
- **Shortlist on the first page.** Use the first page (or the maker's
  product page) to drop candidates that miss the rating. Read the rest
  only for the part you choose.
- **Targeted pages, not the whole PDF.** Read page 1–2 (features,
  absolute maximum, pinout). Find the package and application pages from
  the table of contents or the page numbers named on page 1, and read
  only those. Stop when the card is complete.
- **Short cards for commodity parts.** Standard resistors, ceramic
  capacitors and generic headers get a short card from the **series**
  datasheet (one card per series, not per value): rating, tolerance,
  dielectric, package dimensions. The pins are trivial.
- **Do not re-read.** `datasheet_fetch` caches the PDF, and the card stays
  in the conversation. Later phases (library, plan, ERC) use the card,
  not the PDF. Open the PDF again only to answer a question the card does
  not cover.
- **Imported library parts still need the card,** but only the pin and
  package lines, to check the import.

## 1. Get the PDF

1. Find the **manufacturer's** datasheet URL (maker product page, or the
   distributor's link to the maker PDF). Prefer the latest revision.
2. `datasheet_fetch(url, part_number)` downloads it into the workspace
   (cached and hashed) and returns `path` and `pages`. It refuses
   non-PDF replies, such as login pages; then try another URL or ask the
   user to download it.
3. Read the PDF from `path`, always with `pages` (see the budget in
   section 0): `pages: "1-2"` first, then only the pages named there. In
   Copilot, fetch the URL as text when the client cannot open PDFs.
   Do not render package drawings or previews to PNG to look at them
   unless a dimension cannot be read from the text.

If no datasheet can be obtained, stop for that part and ask the user.
Never fill a card from memory.

Sites known to block automated PDF fetches: Murata, Yageo, Molex, TDK and
Phoenix Contact. Do not retry them. Try RS Components document links,
the KEMET content server, or an LCSC/szlcsc copy of the same revision. For
commodity parts (chip R/C, standard headers), the short card from
distributor data is acceptable when the user agrees; mark it "datasheet
not checked".

## 2. Build the datasheet card

Write each card into the conversation in this shape, with the **page
number** for every value:

```
<MPN> — <maker> — <title>, rev <x>, <url>
Ratings (abs max):   V_DS 1200 V (p1) · I_D 30 A @25 °C (p2) · V_GS −8/+19 V (p2) · T_j 175 °C
Key electrical:      R_DS(on) 75 mΩ @15 V (p3) · Q_g 51 nC · C_oss 58 pF · t_rr / Q_rr of body diode
Recommended use:     V_GS(op) −4/+15 V (p2) · gate resistor range · required support parts
Pins:                1 = G, 2 = D, 3 = S (power), 4 = S (Kelvin) · tab = D (p11)
Package:             TO-247-4, drawing p11, dims min/nom/max · land pattern if given
Lifecycle:           active / NRND (source)
Schematic notes:     what the sheet must do because of this part
```

What to collect, by part type:

| Part type | Must read |
|---|---|
| MOSFET / IGBT / GaN | V_DS, I_D at the real case temperature, V_GS max and recommended drive levels, R_DS(on) at the drive voltage, Q_g, body diode t_rr/Q_rr, Kelvin source pin, tab connection |
| Diode | V_RRM, I_F(AV), I_FSM, V_F, t_rr / Q_rr (or "zero recovery" for SiC Schottky), cathode-band to pin mapping |
| Capacitor | rated voltage (DC and AC), dielectric, ripple current, ESR, lead spacing; derating with DC bias for ceramics |
| Inductor / transformer | inductance at the operating current, I_sat, I_rms, DCR, pin numbering, dot (polarity) marking, isolation rating |
| IC (driver, controller, amplifier) | supply range, every pin's function and electrical type, exposed pad, and the **typical application circuit**: every capacitor, resistor and pull-up it shows, with values |
| Connector | current per contact, voltage, pitch, pin 1 position, mating part |

## 3. Use the card in the schematic

The card is not only for the BOM. Carry each item into the design:

- **Symbol:** pin numbers and names exactly as the pin table gives them.
  Check them against the symbol with `lib_get_pin_list`. For an imported
  KiCad/CERN symbol, compare its pin map with the card and fix any
  difference.
- **Footprint:** package dimensions into `footprint_check_package` →
  `lib_create_footprint_from_package`. If the datasheet gives a land
  pattern, audit the result with `lib_audit_footprint_vs_datasheet`.
  Do the same for an imported footprint.
- **Plan parameters:** fill `manufacturer`, `mpn`, `footprint`, `value` and
  `datasheet_url` on every part (discipline rule: required for parts the
  plan creates), so that they land in the component parameters and the
  BOM. Where the rating matters, put it into `value`, for example
  `10u 1100V` or `C3M0075120K`.
- **Support parts:** add every part the datasheet requires and the user's
  scope includes, such as decoupling at the stated values, gate
  resistors, bootstrap diode and capacitor, pull-downs, snubbers and
  enable pull-ups. Use `design_list_circuit_blocks` blocks where they
  exist. If the user chose "power stage only", bring the pins out to a
  header and list the support parts as open items instead.
- **Connectivity rules:** Kelvin source to the driver return (not the
  power source), tab-connected pins on the same net, exposed pad to the
  pin the datasheet says, unused pins handled the way the datasheet says
  (tie, float or pull). A pin that must stay open gets a `No ERC` marker,
  and the card names the page that says so.
- **Notes:** any limit the layout must respect (creepage, thermal, gate
  loop) goes into the plan's `open_questions` or a sheet note.

## 4. Before the BOM gate

Each approved part has a card, a URL and page citations. The BOM table
quotes the card's ratings, and the "schematic consequences" list under it
comes from the cards' **Schematic notes**.
