# Verified parts: reuse what earlier runs already proved

Every full run reads datasheets and builds symbols and footprints. Without
a memory, the next design that uses the same MPN pays for it all again
(about 15–25k tokens per part, plus the library work). The verified store
keeps each part that went through a full run: its datasheet card, its
symbol and its footprint. A later run copies them in for about 500 tokens.

## Where it lives

```
%USERPROFILE%\Boardwright\verified\
├── index.md            one table row per MPN (read this first, it is small)
├── verified.SchLib     the store's symbols (this skill's own library)
├── verified.PcbLib     the store's footprints
└── cards\<MPN>.md      one datasheet card per MPN
```

This library belongs to the skill, so writing to it does not break the
"never write to the user's libraries" rule. Do not put anything else in
it, and never edit or delete an entry the user did not ask about.

`index.md` format:

```
| MPN | Maker | Function | Key ratings | Symbol | Footprint | Card | Added | Used in |
|---|---|---|---|---|---|---|---|---|
| IPZA60R099P7 | Infineon | 600 V SJ MOSFET | 600 V, 99 mΩ, 20 A@100 °C | NMOS_TO247_4 | TO-247-4_INF | cards/IPZA60R099P7.md | 2026-10-25 | inv_full |
```

## Phase 3: look up before you search

1. Read `index.md` once, at the start of phase 3. If the folder does not
   exist, skip this section. The store is created at the end of the first
   full run.
2. For each rating row, a stored part is a **candidate** when its key
   ratings meet the row. Read only its card (`cards\<MPN>.md`); the PDF is
   not needed. The card's lifecycle line may be old: if the card is more
   than 12 months old, run one web search on the MPN for the current
   lifecycle.
3. In the BOM table, mark the part **"verified (used in <project>)"**. Still
   show it at the BOM gate. The user may prefer a different part.
4. To author an approved verified part, copy it instead of creating it:
   ```
   lib_copy_component(source_name=<Symbol>, source_library="<store>\\verified.SchLib",
                      dest_library="<proj>_lib.SchLib")
   lib_copy_footprint(source_name=<Footprint>, source_library="<store>\\verified.PcbLib",
                      dest_library="<proj>_lib.PcbLib")
   lib_link_footprint(component_name=<Symbol>, footprint_name=<Footprint>)
   ```
   Then save both project libraries by path, as for any new part. Run
   `lib_get_pin_list` once to confirm that the pins match the card.

## Phase 7: promote new parts after ERC 0

After the run ends with ERC 0, add each part that is **not yet** in the
store and that meets **all** of these:

- it has a full datasheet card with page citations, not "datasheet not
  checked" and not `GENERIC` (quick-mode parts never enter the store)
- its symbol pins were checked against the card (`lib_get_pin_list`)
- its footprint came from the datasheet drawing or land pattern, or was an
  import checked against it

Steps:

1. If the store does not exist yet, create it:
   `app_create_document(kind="SCHLIB", file_path="<store>\\verified.SchLib", add_to_project=false)`
   and the same for `PCBLIB`.
2. `lib_copy_component(source_name, source_library=<proj SchLib>, dest_library=<store SchLib>)`
   and `lib_copy_footprint(...)` the same way, then link the footprint.
   If the name already exists in the store with another part's geometry,
   copy it under a name with the maker suffix (for example
   `TO-247-4_INF`) instead of overwriting.
3. Save both store libraries **by path** (`app_save_document`), then close
   them (`app_close_document`) so they do not stay in the session.
4. Write `cards\<MPN>.md`: the card exactly as built in phase 3, plus a
   header with the symbol, footprint, datasheet URL, date and project.
5. Add the rows to `index.md`. For a part that was already stored and was
   reused, only add the project to its "Used in" column.
6. In the final report, list what was added to the store.

Ask the user before the first promotion in a conversation ("Add these
N parts to your verified store?"). After that, follow their answer for the
rest of the conversation.
