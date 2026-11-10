# Circuit intake: from a picture or short request to an agreed spec

A picture from a paper, a block diagram or a one-line request is an
**idea**, not a buildable circuit. Papers draw ideal sources, parasitic
elements and load models that are not parts on a board, and they leave
out ratings. Copying such a picture symbol for symbol gives a sheet with a
voltage source, a magnetising inductor, a DBD model and floating gates,
none of which can be ordered. This file turns the idea into a spec that
the user has agreed to before any part is searched.

## 1. Recognise the circuit

Read the picture, or the text, and write back in **three to six lines**:

- the topology name and its blocks, in signal-flow order. For example:
  *"Phase-shifted full bridge (S1–S4) → transformer Np:Ns → series
  resonant Lr–Cr → diode bridge D1–D4 → unfolding bridge S5–S8 → LC
  filter → grid vg. A single-stage DC/AC (PSFB-SR + unfolder) inverter."*
- every element, split into three groups:

| Group | Typical members | What goes on the sheet |
|---|---|---|
| **Real parts** | MOSFETs, diodes, capacitors, inductors, transformers, ICs | A part with an MPN |
| **Ideal / model elements** | V_dc, v_g, I sources, magnetising L_m, leakage L_lk, ESR, junction capacitance, load models (DBD Cd/Cg/Rg, resistor "load") | **Not a part.** A source becomes an input connector; a load becomes an output connector; a parasitic is absorbed into the part that has it (L_m and L_lk into the transformer) |
| **Implied but not drawn** | gate drivers and their supplies, bootstrap, snubbers, current and voltage sensing, controller, auxiliary supply, fuses, bleeder resistors, test points | Ask whether to include it, or bring it out on a header |

A parasitic that the design deliberately makes into a real component
(for example a discrete resonant inductor L_r that is larger than the
leakage) is a real part. When the picture does not say which, ask.

If the topology cannot be recognised, describe what you see block by
block and ask the user to name it. Do not invent a name.

## 2. Ask the questions, all at once

Ask **one message** with numbered questions and a **suggested default**
for each, so the user can answer "defaults" or change only a few. Take
the defaults from anything the user already said and from the picture
labels. Skip a question the user already answered. Keep it to the
questions that change part selection; nine is a reasonable maximum.

Always ask:

1. **Project path** (default `C:\Users\Public\Documents\Altium\<name>\<name>.PrjPcb`).
2. **Input**: voltage range (min/nom/max) and type (DC bus, mains AC, battery).
3. **Output**: voltage, current or power, and type (DC, AC grid, pulsed, HV).
4. **Switching frequency** (power converters) or the key signal bandwidth (analog).
5. **Scope**: power stage only with gates and sensing on headers (default),
   or include gate drivers / controller / auxiliary supply.
6. **Mounting preference**: SMD or through-hole for power parts; any
   preferred makers or a stock distributor.

Then add the topology-specific questions:

| Circuit family | Extra questions |
|---|---|
| Bridge / half-bridge / PSFB / LLC / DAB | device technology (Si, SiC, GaN); turns ratio and whether the transformer is custom (custom = make a symbol, footprint is a placeholder or the bobbin's pin pattern); resonant L and C values; isolation between primary and secondary grounds (default: separate nets) |
| Rectifier stage | diode type (fast recovery, SiC Schottky, HV stack); or synchronous rectification |
| Unfolding / inverter / grid-tied | grid voltage and frequency; filter L and C values; whether the unfolder switches need isolated gate drive |
| Buck / boost / buck-boost / flyback | controller IC or discrete; ripple targets; inductor current |
| Pulsed power / HV (DBD, pulser, Marx) | peak voltage and pulse width; repetition rate; load capacitance; creepage and clearance class; whether one switch must be a series stack or a module |
| Linear / LDO / reference | dropout, output current, noise |
| Op-amp / analog front end | supply rails, gain, bandwidth, input range |
| MCU / digital | the MCU or family, interfaces, connectors, programming header |

## 3. Check the design, then turn the answers into ratings

First run [design-checks.md](design-checks.md) on the answers. Its fixes
can change the operating point (turns ratio, rail voltage, device class),
and the ratings below must use the corrected values.

For each real part, write the electrical stress and the rating to search
for. Apply these derating defaults unless the user gives their own:

| Quantity | Search for at least |
|---|---|
| MOSFET / IGBT V_DS | 1.25 × the highest voltage it blocks (1.5 × in pulsed or HV) |
| Diode V_RRM | 1.25 × peak reverse voltage (1.5 × for HV) |
| Switch and diode current | 1.5 × RMS, and check the peak |
| Capacitor voltage | 1.25 × the highest DC plus ripple peak (film or ceramic C0G for resonant or AC) |
| Inductor / transformer current | 1.3 × peak below saturation |
| Resistor power | 2 × dissipation |

Show the result as a table (block, ref, function, stress, required
rating) and ask the user to confirm it **before** searching. This is the
first approval gate. A short request whose answers came back as
"defaults" still gets this table.

## 4. What the confirmed spec feeds

- The rating table drives [part-sourcing.md](part-sourcing.md).
- The block order becomes `sheets[].blocks` and the left-to-right layout
  order in the DesignPlan.
- Connectors for sources and loads, and headers for gates and sensing,
  give every net at least two pins, which keeps ERC clean without
  `No ERC` markers.
- Separate grounds (PGND, HV_RTN, SGND) stay separate nets unless the user
  says to tie them, and then with a named net tie.
