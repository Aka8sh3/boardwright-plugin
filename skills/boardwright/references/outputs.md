# Final review and fabrication outputs

## 1. Numbers table for gate 3

| Check | Source | Pass |
|---|---|---|
| Overlaps, pad gaps, keep-outs, holes, off-board | `pcb_layout_audit` placement_audit | all 0 |
| Routed nets | connectivity_summary | routed == nets |
| DRC (offline) | `pcb_layout_audit` drc | 0 |
| DRC (Altium) | `pcb_run_drc(allow_modal=True)` with the user present, or the stored violations | 0 |
| Corners | corner_audit | 0 sharper than 45° |
| Pour islands | plane_region_audit | 0 |
| Return-via exceptions | return_via_audit | listed |
| Worst loops | loop_audit | listed with sizes |
| Sch ↔ PCB | `proj_compare_sch_pcb` | in_sync |
| ERC | `proj_run_erc` | 0 |
| Fab-floor checks without rules | hole-to-hole, mask sliver, silk width | stated |

Add one `design_visual_review` render. Show both and **wait for the
user's OK** before generating outputs.

## 2. OutJob and fab package

1. If the project has no fabrication OutJob, base one on Altium's
   template (`<Altium install>\OutputJobs\Fabrication.OutJob`, for
   example `C:\Program Files\Altium\AD23\OutputJobs\`). Copy it next to
   the project, add it to the project (`proj_add_document`), and point
   its outputs at this board. Containers: **Gerber RS-274X** (inch 2:5 or
   metric 4:6, as the fab asks), **NC Drill** (PTH and NPTH separate,
   slots included), IPC-356 netlist, pick-and-place, BOM, and the assembly
   drawing.
   - The board outline goes on the layer the fab reads (for example a
     KeepOut layer exported as .GKO, or a mechanical layer named in the
     fab notes). Do **not** plot a mechanical layer that holds courtyards.
2. `proj_list_outjob_containers(outjob_path)`, then
   `proj_generate_fab_package(outjob_path, include_step=<asked>)`.
3. **If no files were written** (seen on AD 23: the outputs in an OutJob
   must be enabled by hand, and a script cannot switch them on): ask the
   user to open the OutJob, enable the outputs and click **Generate
   content**. Then list the folder and check each expected file.
4. Fab-specific files: for JLCPCB assembly, a BOM CSV (Comment,
   Designator, Footprint, LCSC part #) and a CPL CSV (Designator, Mid X,
   Mid Y, Layer, Rotation). Rotations differ between Altium and the fab's
   library, so flag them for checking in the fab's viewer.
5. Zip the Gerbers and drills for upload, and list the zip path.

## 3. Report

- Board: size, layers, stackup, copper weight, and the fab profile (with
  its source and date).
- Rules applied: each class with its width and clearance, and where each
  number came from.
- The numbers table above.
- **Fab notes:** vias in pads (from the router's `via_in_pad`), HV
  clearance classes and slots, tented vias, controlled impedance if any,
  and the special stackup.
- Open items: thermal checks to do on the bench, magnetics still to be
  designed, rotations to check in the fab viewer.
- The output folder and the zip.
- Offer `design_session_report` (a full design report from the session
  journal) and a 3D STEP export.
