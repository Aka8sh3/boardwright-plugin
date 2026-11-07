# Design checks: does the circuit work at the agreed numbers?

ERC 0 only proves that the wiring is consistent. It says nothing about
whether the circuit can meet its spec. These checks run in phase 1,
**after** the user's answers and **before** the rating table is shown, so
an error such as a turns ratio that cannot reach the output is caught
before any part is sourced. (In the first full run the user caught this
error, not the skill: n = 1:10 with V_in,min = 25 V gives 250 V, below a
358 V grid peak, and a PSFB-SR cannot boost.)

## How to run them

1. Pick the rows below that match the blocks named in phase 1. Always run
   the **general** rows.
2. Work each check at its **worst case**: minimum input for gain and
   duty, maximum input for blocking voltage, maximum load and temperature
   for current and loss. Write the numbers, not only the verdict.
3. Show one table above the rating table:

| # | Check | Formula | Numbers (worst case) | Result |
|---|---|---|---|---|
| 1 | Gain reaches output | n·V_in,min·M_max ≥ V_out,pk·1.05 | 16·25·1.0 = 400 ≥ 376 | ✅ |

4. A ❌ is never passed on silently. Propose the smallest fix (change n,
   narrow the input range, add a stage, change the device class), apply
   it if the user agrees, and re-run the affected checks.
   A ⚠ (marginal, or a value that depends on the layout or magnetics
   design) goes into `open_questions` and the final report.
5. If a check needs a value nobody has given (for example the gain range
   of the tank), state the assumption in the Numbers column.

Keep it short: one line per check, about 5–12 checks for a power stage
and 3–6 for small-signal or digital circuits. Do not derive textbook
theory in the chat.

## General (every circuit)

| Check | Rule |
|---|---|
| Supply range | Every IC's supply pin stays inside its recommended range over the whole input range, including start-up and the case where a rail is missing |
| Defined states | Every input pin (gate, enable, reset, boot, control input) has a defined state when the driving side is unplugged or unpowered: pull-up/down or a strap |
| Power and temperature | P_loss of each power part × θ (from the card) + T_amb ≤ T_j,max − 25 °C. Flag a part that needs a heatsink |
| Insulation and creepage | Above 60 V DC or 30 V AC, or across an isolation barrier: name the voltage class and the creepage needed (IEC 62368/60664 working values). Flag pin pitches that are too small (2.54 mm headers next to > 150 V nets) |
| Grounds | Isolated domains stay separate nets; anything that ties them is named and intended |
| Start-up and fault | Inrush (bulk capacitors from a stiff source), reverse polarity, and what happens with no load |

## Isolated DC/DC (PSFB, LLC, SRC, DAB, half/full-bridge, forward, flyback)

| Check | Rule |
|---|---|
| Gain at minimum input | n·V_in,min·M_max ≥ V_out,max (+ diode and resistive drops, about 5 %). M_max is about 1 for a PSFB, SRC or forward at full duty; LLC uses the tank's M_max at f_sw,min |
| Gain at maximum input | n·V_in,max·M_min ≤ V_out,min, i.e. the controller can still reduce the gain (phase shift, frequency, duty) at light load |
| Secondary voltage stress | Rectifier reverse voltage: the clamping rail for a capacitor-clamped bridge; 2·n·V_in for a centre tap; n·V_in,max + V_out for a flyback secondary |
| Primary switch stress | V_in,max (bridge); V_in,max + n·V_out + spike (flyback); 2·V_in,max (push-pull, forward with reset winding) |
| Resonant tank | f_r = 1/(2π√(L_r·C_r)), with f_sw on the intended side of f_r; V_Cr,pk = I_pk/(2π·f·C_r) is inside the C_r rating; LLC L_m/L_r is between 3 and 10 |
| ZVS energy | ½·L·I² at turn-off ≥ ½·(2·C_oss,eq)·V² across the load range that must be soft-switched; otherwise flag hard switching at light load |
| Magnetics | Transformer volt-seconds V_in,max·D/f_sw within the core's B_sat with margin (a ⚠ placeholder until the magnetics are designed); inductor I_sat ≥ I_pk |

## Inverter, unfolder, grid-tied

| Check | Rule |
|---|---|
| Rail versus grid | The rectified or DC rail ≥ the grid peak at V_grid,max (1.1 × nominal × √2) |
| Power pulsation | C_bulk ≥ P_avg / (2π·f_line·V_dc·ΔV), where f_line is the grid frequency (the ripple is at 2·f_line). The ripple current rating is taken at 2·f_line, not 100 kHz |
| Unfolder switches | V_DS ≥ rail max with margin; they conduct for a whole half cycle (10 ms), so **bootstrap supplies cannot hold the high side**: flag isolated supplies for the floating switches |
| Filter | f_res = 1/(2π√(L_f·C_f)) between 10·f_line and f_sw/2; L_f keeps enough inductance at the grid-peak current (check the card's L-vs-I curve) |
| Reactive current | The X capacitor's current at the grid voltage, I = 2π·f_line·C·V, is acceptable at no load |

## Non-isolated DC/DC (buck, boost, buck-boost, SEPIC)

| Check | Rule |
|---|---|
| Duty range | D at V_in,min and V_in,max inside the controller's D_min/D_max, and the on-time ≥ t_on,min at the highest f_sw |
| Inductor | Ripple 20–40 % of I_out (buck) or of I_in (boost); I_sat ≥ I_pk = I_avg + ΔI/2 at the hottest corner |
| Boost limits | V_out > V_in,max (a boost cannot buck); the output is not isolated from the input at shutdown |
| Capacitors | Output ripple ΔV ≈ ΔI/(8·f·C) + ΔI·ESR within spec; ripple current inside the rating at f_sw |
| Switch and diode | V ≥ V_in,max (buck) or V_out (boost) + spike; diode reverse recovery acceptable at f_sw (prefer Schottky or SiC) |

## Gate drive (any bridge)

| Check | Rule |
|---|---|
| Drive levels | V_GS(on) and V_GS(off) match the device card (SiC: about +15/−4 V; GaN: within its tight V_GS max) |
| Driver current | I_peak ≈ V_drive/(R_g,int + R_g,ext + R_driver) is within the driver rating; Q_g·f_sw·V_drive is within the driver supply budget |
| High-side supply | Bootstrap only where the duty cycle refreshes it each period; otherwise an isolated supply |
| CMTI | The driver's CMTI exceeds dv/dt = V_rail/t_rise with margin (SiC can exceed 50 V/ns) |
| Dead time | t_dead ≥ the switch-node transition time at the lightest load that must stay soft-switched |

## Pulsed power and HV (DBD, pulsers, Marx, Cockcroft-Walton)

| Check | Rule |
|---|---|
| Output reach | n·V_in (or the stage count × V_stage) ≥ V_peak target with the drops |
| Switch stack | V_stack ≥ 1.5 × V_peak (HV derating); static and dynamic voltage sharing (resistors, RC) for series devices |
| Energy and power | E = ½·C_load·V²; P = E·f_rep is within the supply and switch dissipation |
| Insulation | Creepage and clearance at V_peak (about 5–10 mm/kV on FR-4 surfaces, more in humid environments); flag parts whose pin pitch cannot meet it |
| Discharge | A bleeder discharges every HV capacitor to < 60 V within a stated time |

## Linear regulators and references

| Check | Rule |
|---|---|
| Dropout | V_in,min − V_out ≥ V_dropout at I_max and temperature |
| Dissipation | (V_in,max − V_out)·I_max·θ_JA + T_amb ≤ T_j,max − 25 °C |
| Stability | The output capacitor's type and ESR match the card's stability window |

## Analog front end (op-amp, comparator, ADC driver)

| Check | Rule |
|---|---|
| Bandwidth | GBW ≥ 10 × gain × signal bandwidth |
| Swing and input range | The output swing and input common-mode stay inside the card's limits for the rails used |
| Noise and offset | Offset × gain plus noise in the band are inside the error budget, if the user gave one |
| ADC drive | Settling within the acquisition time; the RC filter's C is at least about 10 × the sampling capacitor |

## MCU and digital

| Check | Rule |
|---|---|
| Power pins | Every VDD/VSS pair has its decoupling at the card's values; analog supplies are filtered as the card shows |
| Boot and reset | Boot pins strapped to the intended mode; reset pull-up and capacitor; programming header with the right pinout |
| Clock | Crystal load capacitors C = 2·(C_L − C_stray), with C_stray about 3–5 pF |
| I/O levels | Every interface's logic levels are compatible, or a level shifter is in the plan |
