# Authoring a library part (symbol + footprint)

Do this only for parts that are in neither the user's libraries nor a
trusted source. The parts go into a **project-local library** that you
create. Never write to a SchLib or PcbLib that you did not create in this
session (discipline rule 13).

## 1. Datasheet first

Fetch the manufacturer's datasheet (not a distributor page) and note:

- the **pin table**: number, name, function, electrical type
- the **package drawing**: every dimension as min/nom/max, with page and
  figure
- the **recommended land pattern**, if there is one
- the URL, which goes into the plan as `datasheet_url`

Never state a pin number, polarity or dimension from memory. If the
datasheet cannot be fetched, stop and ask the user for it.

## 2. Create the library documents (once per project)

```
app_create_document(kind="SCHLIB", file_path="<proj dir>\\<proj>_lib.SchLib", add_to_project=true)
app_create_document(kind="PCBLIB", file_path="<proj dir>\\<proj>_lib.PcbLib", add_to_project=true)
```

The document just created is the focused one. **`lib_*` symbol tools act on
the active SchLib and footprint tools act on the active PcbLib**, so call
`app_set_active_document(file_path=...)` before each group of calls.

## 3. Symbol

Discretes get the conventional glyph, in one call:

```
lib_create_passive_symbol(name="RES_GEN", kind="resistor")
lib_create_passive_symbol(name="NMOS_SOT23", kind="nmos", pin_map={"G":"1","S":"2","D":"3"})
lib_create_passive_symbol(name="MBRA140T3G", kind="schottky", pin_map={"K":"1","A":"2"})
```

Kinds: resistor, capacitor, polarized_capacitor, inductor, diode, led,
crystal, fuse, zener, schottky, tvs, tvs_bidirectional, switch,
push_button, nmos, pmos, npn, pnp. `pin_map` sets the pin numbers from the
datasheet, so **always check it**:
- Transistors default to the common SOT-23 assignment (G/B = 1).
- One-way diodes (diode, led, zener, tvs, schottky) have pins named A and
  K, default A = 1. Many rectifiers (SMA/SMB, onsemi, Vishay) number the
  cathode 1: pass `{"K":"1","A":"2"}`.

Make one symbol per call: these tools build on "the current component", so
give them no `items` list.

ICs use a rectangle with the pins grouped by function, not in package
order:

```
lib_create_ic_symbol(
  name="TLV9001", designator_prefix="U", description="...",
  left_pins=[{"designator":"3","name":"IN+","electrical_type":"input"},
             {"designator":"4","name":"IN-","electrical_type":"input"},
             {"designator":"5","name":"V+","electrical_type":"power"},
             {"designator":"2","name":"V-","electrical_type":"power"}],
  right_pins=[{"designator":"1","name":"OUT","electrical_type":"output"}])
```

Inputs, power and control go on the LEFT; outputs and status go on the
RIGHT. Op-amps, comparators and current-sense amplifiers come out as a
triangle automatically. Every datasheet pin must appear, including NC and
the exposed pad if it is numbered. If the user has a standard part drawn in
their house style, `lib_copy_component` it into your library and renumber
it instead.

Verify the result with `lib_get_pin_list(component_name=...)`.

## 4. Footprint

From the package drawing (preferred), check first and then create:

```
footprint_check_package(package={ "family":"sot23", "pitch":0.95,
   "lead_span_x":[2.10,2.40,2.64], "body_y":[2.80,2.90,3.04],
   "lead_length":[0.30,0.40,0.50], "lead_width":[0.30,0.40,0.50],
   "pins":3, "source":{"document":"<datasheet>","page":9,"url":"..."} })
lib_create_footprint_from_package(package=<same>, name="SOT-23-3")
```

Families: chip, melf, molded, sod, sot23, sot89, sot223, dpak, soic, son,
qfn, qfp, plcc, bga, lga, crystal2, crystal4, dip, header, radial, axial,
to220, to92, connector, custom. All lengths are in mm. Do not continue
while `footprint_check_package` reports `errors`; a value 25.4× off means
mils were typed as mm.

When the datasheet gives the land pattern itself:
`lib_create_standard_footprint(name, family, pin_count, pitch, pad_w, pad_h, row_span, ...)`
takes **mils**. For example, 0603: `family="chip", pin_count=2, pitch=60, pad_w=35, pad_h=40`.

The result is good only when `ok` is true, which means the pads were read
back and match.

## 5. Link and save

```
app_set_active_document(file_path="<...>.SchLib")
lib_link_footprint(component_name="NMOS_SOT23", footprint_name="SOT-23-3")
app_save_document(file_path="<...>.SchLib")
app_save_document(file_path="<...>.PcbLib")
```

**The save is mandatory.** `sch_draw_template` reads the symbols from the
SchLib file on disk. An unsaved library makes placement fail even though
the symbol is visible in Altium.

In the plan, set `lib_ref` to the symbol name, `lib_path` to the SchLib's
absolute path, and `footprint` to the footprint name.
