# The Heat Route to Firm Green Hydrogen — Methodology, Figures and Tables

**A spatially-explicit, firmness-resolved techno-economic, thermodynamic and environmental model comparing three architectures for firm (24-hour) green hydrogen.**

Companion documentation to the MATLAB implementation in `HeatRouteFirmH2/`.
Prepared for Prof. H. S. S. AbdelMeguid.

---

## 1. Overview and research question

The study answers one decision-relevant question, globally and spatially:

> *For firm (constant, 24-hour) green hydrogen, is it cheaper to store sunlight as **heat** (concentrated solar power + molten-salt thermal storage feeding a high-temperature solid-oxide electrolyzer) or as **electricity** (PV/wind + batteries feeding a low-temperature electrolyzer) — and where?*

Three architectures are co-modelled at every location:

| Arch. | Name | Configuration | Storage medium |
|------|------|---------------|----------------|
| **A** | Heat route | CSP field → two-tank molten-salt TES → Rankine block → **SOEC** (electricity + steam) | Thermal |
| **B** | Electricity route | PV (+ wind) → Li-ion battery → low-temperature (PEM/alkaline) electrolyzer | Electrical |
| **C** | Hybrid | PV + CSP/TES + SOEC, co-optimized | Thermal + electrical (the *split*) |

The model is implemented as a modular MATLAB pipeline and produces 21 publication figures, 15 scientific tables, a native-Word equations document, and an Excel workbook of all figure data.

---

## 2. Software architecture and reproducibility

| Module | Role |
|--------|------|
| `hr_config.m` | Single source of truth: all physical constants, technology and cost parameters (model Sections 2–12), the grid, the named archetype sites, scenario cost multipliers, figure styling. |
| `fetch_nasa_power.py` / `fetch_nasa_regional.py` / `fill_missing_nasa.py` | Download NASA POWER monthly climatology (point and regional endpoints) to per-parameter CSV caches. |
| `hr_load_nasa.m` | Read the cached measured climatology and interpolate **each parameter on its own native grid** onto the model grid. |
| `hr_resource.m` | Solar geometry (Eqs 3–6) + 12 monthly typical-day hourly profiles (DNI, GHI, incidence/IAM, wind, ambient temperature), measured-anchored or synthetic. |
| `hr_solve_cell.m` | Physics core: component models (Eqs 7–43), reusable least-cost **supply sizers** (thermal/electrical/hybrid), firmness dispatch, economics (Eqs 51–57). |
| `hr_analyze_arch.m` | Energy, exergy (58–61), entropy (Gouy–Stodola), 1st/2nd-law efficiencies, dimensionless groups, environmental indicators. |
| `hr_montecarlo.m`, `hr_dominance_map.m`, `hr_tornado.m`, `hr_uncertainty.m` | Uncertainty propagation, dominance-probability map, tornado sensitivity, comprehensive uncertainty of all results. |
| `hr_make_figures.m`, `hr_export_excel.m`, `hr_make_tables.m`, `hr_make_tables_doc.m`, `hr_validate.m` | Figures, Excel export (one sheet/figure), scientific tables (Excel + Word), validation. |
| `HeatRoute_FirmH2_Main.m` | Master driver orchestrating the whole study. |

A single run (`HeatRoute_FirmH2_Main.m`) is fully reproducible (fixed RNG seed), self-validates (20/20 checks), and writes all deliverables to `output/`.

---

## 3. Resource data — measured NASA POWER climatology at 1°

- **Source.** NASA Langley POWER long-term **monthly climatology** (community *RE*): `ALLSKY_SFC_SW_DNI` (DNI), `ALLSKY_SFC_SW_DWN` (GHI), `T2M` (air temperature), `WS50M` (50-m wind).
- **Native 1° fetch.** The **regional** endpoint returns up to 100 points per call over a 10°×10° box (one parameter per call). The inhabited band (lat −58…58, lon −180…180) is tiled in 10°×10° boxes restricted to land-overlapping tiles; a throttle-tolerant worker pool with exponential backoff completes the fetch in ~8 min/pass.
- **Per-parameter grids (key subtlety).** NASA POWER serves **solar** parameters (DNI, GHI) on a ~1° grid but **meteorology** (T2M, WS50M) on the finer MERRA-2 grid, so the four parameters do **not** share coordinates. Each parameter is therefore cached separately (`data/nasa_param_{DNI,GHI,T,W}.csv`: 27,500 DNI/GHI points; 88,937 T/W points) and **interpolated independently** onto the model grid (`scatteredInterpolant`, natural + nearest extrapolation).
- **Grid.** 1° lat/lon (361×117), land mask from the built-in 1° global topography (`load topo`, land = elevation > 0); **11,284 land cells**. Maps overlay the built-in global coastline (`coastlines.mat`) on an ocean-blue background.
- **Synthetic fallback.** Where measured data are absent, a physically-based clear-sky (Hottel) × climatological-clearness field is used, keeping the pipeline robust and the data interface identical.

### 3.1 Typical-day reduction
Dispatch uses **12 monthly typical days at hourly resolution (288 h)** rather than a full 8760-h series. This captures the diurnal storage cycle that governs firmness and the seasonal worst-month that sizes the plant, at ~30× lower cost, and is a standard, citable TMY-day reduction. Annual quantities scale typical-day results by days-per-month.

### 3.2 Solar geometry and renewable generation (Eqs 3–11)
- Declination (Eq 3), hour angle (Eq 4), zenith angle (Eq 5), single-axis-trough incidence angle (Eq 6).
- Clear-sky beam shape (Hottel) scaled to the **measured monthly daily totals** — "measured monthly total + modelled diurnal shape".
- PV: NOCT cell temperature (Eq 7) and temperature-corrected single-point power (Eq 8).
- Wind: normalized four-region power curve with air-density correction (Eqs 9–11).

---

## 4. Heat route — CSP field, thermal storage and power block (Eqs 12–22)

- **Collector field.** Incidence-angle modifier (Eq 12), absorbed beam power (Eq 13), receiver thermal losses as a quadratic in ΔT (Eq 14), net field output (Eq 15); the **solar multiple** SM oversizes the field for storage charging (Eq 16).
- **Two-tank molten-salt TES.** Energy-balance state of charge with separate charge/discharge efficiencies and a standby loss (Eq 17); capacity from storage-hours h_TES (Eq 18); standby loss (Eq 19); operating limits (Eq 20). The cost decomposition uses a transparent solar-field (USD m⁻²) + Rankine-block (USD kW⁻¹) split rather than the lumped CSP cost.
- **Rankine block.** Gross electrical output with a part-load correction (Eq 21), net of parasitics (Eq 22).

---

## 5. SOEC electrochemical and thermal model (Eqs 23–37)

- **Reversible (Nernst) voltage** for steam electrolysis at the operating temperature (Eq 23), with temperature-dependent ΔG(T), ΔH(T) (→ V_rev ≈ 0.92 V, V_tn ≈ 1.285 V at 1073 K).
- **Overpotentials:** Butler–Volmer activation in inverse-hyperbolic-sine form (Eqs 24–25), Arrhenius ohmic ASR from electrolyte conductivity plus a lumped contact/electrode term (Eqs 26–27), Nernstian concentration (Eq 28).
- **Cell voltage, power, hydrogen** (Eqs 29–31); **reaction + steam-raising heat demand** below thermoneutral, partly recovered (Eqs 32–35) — this heat is supplied by the CSP/TES system, the core of the heat route.
- **Stack scaling.** The stack is sized so that, at the chosen current density, it produces the firm hydrogen rate; its electrical and thermal demands are then constant 24/7 firm loads.

---

## 6. Electricity route — battery and LT electrolyzer (Eqs 38–43)

- **Li-ion battery** state-of-charge balance with charge/discharge efficiencies (Eqs 38–39).
- **Low-temperature electrolyzer** part-load specific-energy-consumption curve (Eqs 40–41) and hydrogen output (Eqs 42–43); all heat supplied electrically and folded into the SEC.

---

## 7. Firmness, dispatch and least-cost sizing (Eqs 44–66)

- **Firmness.** Firm output ⇒ the electrolyzer runs at a **constant hourly hydrogen rate**, converting it into a constant electrical (and, for the SOEC, thermal) load that the supply chain + storage must meet on every typical-day hour.
- **Reliability-floor model.** Rather than forcing each worst-winter day to be self-sufficient with only diurnal storage (which would demand absurd oversizing), a design is **firm-feasible** if it meets the firm output in ≥ 90 % of hours; hydrogen is costed on what is actually delivered, `H2_actual = firm × reliability`. This yields smooth, realistic LCOH-vs-DNI behaviour and a well-defined feasibility frontier.
- **Periodic diurnal dispatch.** A storage-dispatch routine serves load directly from generation, charges surplus, discharges deficits, applies standby loss, and settles a periodic initial state — vectorized over the 12 months.
- **Reusable supply sizers.** `sizeThermalSupply` (CSP+TES+block: decisions SM, h_TES) and `sizeElecSupply` (PV+wind+battery: PV multiple, wind blend, battery hours) each **minimize full LCOH directly** by a deterministic grid-plus-refine search and return both the firm optimum and the unconstrained annual-average optimum in one pass.
- **Architectures composed:** A = thermal supply + SOEC; B = electrical supply + LT; **C = coupled two-storage hybrid** (`sizeHybrid`) where PV powers the SOEC by day, a battery shifts some PV into the evening, and CSP/TES supply heat plus residual electricity via the block; a light tie-break regularization yields a unique, smooth optimum.

---

## 8. Techno-economics and LCOH (Eqs 51–57)

CAPEX by component (Eq 51), capital recovery factor at country WACC (Eq 52), annualized stack replacement (Eq 53), total annualized cost (Eq 54), annual hydrogen (Eq 55), and **levelized cost of hydrogen** LCOH = C_ann / M_H2,ann (Eq 56). One-factor learning curves (Eq 57) drive the 2025/2030/2050 cost scenarios. Extensions: CO₂-abatement cost vs grey (SMR) hydrogen, levelized exergy cost, and per-kg LCOH build-up.

---

## 9. Exergy, entropy and efficiency analysis (Eqs 58–61 + extensions)

- **Solar exergy** via the Petela efficiency (Eq 58); **hydrogen chemical exergy** (Eq 59); **overall second-law efficiency** ψ (Eq 60); **component exergy destruction** from steady balances (Eq 61), giving the per-component destruction map.
- **Entropy generation** via the Gouy–Stodola theorem, S_gen = Ex_dest / T₀, ranked by component; the **entropy-generation number** N_s = ΣEx_dest / Ex_in.
- **Efficiencies:** first-law (energy) η_I, second-law ψ, and the overall solar-to-hydrogen efficiency η_STH, reported per route and per site.

---

## 10. Dimensionless analysis (classical + innovative)

- **Classical:** Reynolds, Prandtl, Nusselt (Dittus–Boelter), Péclet for molten-salt receiver convection; Grashof, Rayleigh for receiver natural-convection/radiation losses; Biot, Fourier for TES transient conduction; Jakob, Stefan for steam raising.
- **Innovative, route-specific (defined in this work):** heat-leverage ratio Λ (heat share of splitting energy), electrical-substitution number (electricity saved vs the LT route), exergy-quality ratio, **storage-medium split σ_th**, solar multiple, storage number, capacity factor, **firmness premium**, and the exergetic sustainability index. These compress the techno-economic mechanism into transferable physical numbers.

---

## 11. Environmental analysis

CO₂ mitigation vs grey (SMR) hydrogen, specific emissions (≈ 0 for green), CO₂-abatement cost, feed-water demand, land use (solar-field aperture or PV area per kg), and a rough energy-return estimate — supporting a water–energy–land-nexus reading.

---

## 12. Spatial application, crossover and uncertainty

- **Global solve.** Every land cell is independently optimized for A and B → maps of LCOH_A, LCOH_B, ΔLCOH and the **feasibility-aware dominance** (the heat route wins only where it is firm-feasible *and* cheaper). The **thermal hydrogen belt** is the ΔLCOH = 0 contour.
- **Crossover law.** A DNI sweep (fine steps) gives ΔLCOH vs DNI with battery- and TES-cost sensitivity bands and the break-even **DNI\***.
- **Storage-medium split frontier.** The hybrid sweep gives σ_th, PV capacity, TES hours and SM vs DNI.
- **Monte-Carlo.** Latin-hypercube sampling over component costs, WACC **and an 8–10 % resource (DNI) error**; the resource error smears the firm-feasibility threshold so the dominance probability is a **smooth S-curve** (0 below the threshold → 100 % across the belt), not a step. A reduced-sample, subsampled-then-interpolated **dominance-probability map** is produced per cell.
- **Comprehensive uncertainty.** `hr_uncertainty.m` propagates the same uncertainty to **every** reported result and reports mean, std, CV, P10/P50/P90 and 95 % CI (Table 13 / Figure 21).

---

## 13. Validation and verification

Twenty independent checks compare model outputs against physical bounds and published benchmarks (SOEC V–i and efficiency, electrolyzer SEC, LCOH ranges, exergy efficiencies, firm reliability, Petela factor, dominance share, measured-DNI ranges, uncertainty magnitude). All **20/20 pass** (Figure 20 / Table 14).

---

## 14. Headline results (native 1° measured run)

| Result | Value |
|--------|-------|
| Heat/hybrid dominance share | **45.8 %** of feasible land (the thermal hydrogen belt) |
| Break-even DNI\* | **≈ 1700 kWh m⁻² yr⁻¹** (P10–P90 1700–2300) |
| Firmness-premium reversal | heat route **−26 %**, electricity route **+50 %** |
| Storage-medium split σ_th | rises **0.71 → 1.0** with DNI |
| Cost gap ΔLCOH (reference) | **4.20 ± 0.94 USD/kg** (CV 22 %) |
| Heat-route 2nd-law efficiency ψ | **0.87** vs 0.57 (electricity route) |
| Monte-Carlo dominance | ladder-mean **76 %**, **100 %** at high DNI |

---

## 15. Generated figures (21)

All figures are saved as MATLAB `.fig` (`output/Figure_0XX_*.fig`); their full numeric data, caption, description and interpretation are exported one-sheet-per-figure to `output/HeatRoute_FirmH2_FigureData.xlsx`.

| # | Name | Caption | Description | Data (columns) | Interpretation |
|---|------|---------|-------------|----------------|----------------|
| 1 | Concept: storage-medium decision & heat leverage | Fig. 1. The firm-hydrogen storage-medium decision and the heat-leverage mechanism (exemplar: Atacama (Chile)). (a) Per-kg splitting energy supplied as electrical work versus heat for the heat (SOEC) and electricity (LT) routes; (b) optimized firm LCOH of the three architectures; (c) the heat-leverage ratio, electrical-substitution number and second-law efficiencies. | Panel (a) shows that the high-temperature SOEC route meets part of the water-splitting enthalpy as heat (red), lowering the expensive electrical demand relative to the low-temperature route, which supplies all energy as electricity. Panel (b) compares the cost-optimal firm LCOH of the pure heat route (A), the pure electricity route (B) and the co-optimized hybrid (C). Panel (c) quantifies the mechanism through the heat-leverage ratio Lambda (heat share of total splitting energy), the electrical-substitution number (electricity saved versus the LT route) and the exergy efficiencies of both routes. | `Route, SEC_electrical_kWhkg, SEC_heat_kWhkg, LCOH_USDkg` | Supplying ~21% of the splitting energy as cheaply-storable heat lets the heat route substitute ~38% of the electrical work and raises its second-law efficiency from 0.58 (electricity route) to 0.85, which is the physical origin of its lower firm cost (3.32 vs 7.39 USD/kg). |
| 2 | Global firm-LCOH maps (heat vs electricity route) | Fig. 2. Global maps of the levelized cost of firm (24-h) hydrogen for (a) the heat route and (b) the electricity route, on a 1-degree grid; resource field: NASA POWER (measured monthly climatology). | Each land cell is independently size-optimized to deliver firm hydrogen at minimum LCOH (Eqs 51-66). The heat route (a) is cheapest across the high-DNI subtropical arid belts; the electricity route (b) is more uniform but everywhere more expensive where firmness is imposed because battery storage is costly. | `Lat, Lon, LCOH_A_USDkg, LCOH_B_USDkg, DNI_kWhm2yr` | Firm hydrogen is cheap in DIFFERENT places depending on the route: the heat route concentrates low cost in the high-DNI belt (down to ~3.3 USD/kg), whereas the electricity route rarely falls below ~4.3 USD/kg. This is the spatial signature that motivates a storage-medium decision map. |
| 3 | Global dominance map and the thermal hydrogen belt | Fig. 3 (HEADLINE). Global dominance map of the cost difference DeltaLCOH = LCOH_B - LCOH_A. The black line is the thermal-hydrogen belt (DeltaLCOH = 0); the inset bar gives the cos-latitude-weighted share of feasible land won by each route. | Positive DeltaLCOH (warm colours) marks where storing sunlight as heat delivers firm hydrogen more cheaply than storing it as electricity. The zero contour traces a contiguous high-DNI belt across North Africa, Arabia, the US Southwest, the Atacama and Australia. | `Lat, Lon, dLCOH_USDkg, HeatWins, DNI_kWhm2yr` | The heat/hybrid route is the least-cost path to firm hydrogen across 46% of feasible land by area, defining a contiguous thermal hydrogen belt and redrawing the least-cost geography of the hydrogen economy. |
| 4 | Crossover law (Delta LCOH vs DNI) with cost bands | Fig. 4. The crossover law: heat-route cost advantage DeltaLCOH versus annual DNI, with sensitivity bands for battery cost (200-350 USD/kWh) and TES cost (20-30 USD/kWh_th). The break-even DNI* is marked. | The advantage of the heat route grows monotonically with the solar resource. The shaded bands show how the curve shifts when battery and thermal-storage unit costs vary across their literature ranges, indicating the robustness of the ranking. | `DNI_kWhm2yr, dLCOH_central, dLCOH_battLo, dLCOH_battHi, dLCOH_tesLo, dLCOH_tesHi` | A simple, transferable rule of thumb emerges: the heat route is favoured above a break-even DNI of ~1700 kWh/m2/yr, shifting with storage costs. Cheaper batteries move the break-even up; cheaper TES moves it down. |
| 5 | Mechanism: firmness premium, exergy, storage split | Fig. 5. Why the heat route wins. (a) Firmness premium (firm vs annual-average LCOH) for both routes across the archetype sites; (b) component exergy-destruction breakdown (Sahara exemplar); (c) the cost-optimal thermal share of the hybrid versus DNI. | The firmness premium is the cost increment of imposing 24-h firmness. Because thermal storage is cheap and raises SOEC utilization, the heat route can carry a near-zero or negative firmness premium, whereas batteries make the electricity route premium strongly positive. The exergy map locates the irreversibilities; the split panel shows the hybrid optimum. | `Site, FirmPremium_A_pct, FirmPremium_B_pct` | The ranking reverses under firmness: the heat-route premium averages -24% while the electricity-route premium averages +39%. The dominant irreversibility differs by route (heat: solar collection/Rankine; electricity: the electrolyzer), and the optimal thermal share rises toward 100% as DNI increases. |
| 6 | Future cost scenarios and Monte-Carlo robustness | Fig. 6. Robustness and the future. (a) Mean firm LCOH under 2025/2030/2050 cost projections; (b) Monte-Carlo (M=400) median LCOH with P10-P90 bands (left axis) and the probability the heat route wins (right axis) versus DNI; (c) the per-cell dominance-probability map. | Capital-cost learning is applied per technology and scenario; uncertainty is propagated by Latin-hypercube sampling over component costs and WACC. The dominance probability and percentile bands convert the central claim into a probabilistic statement. | `DNI_kWhm2yr, LCOH_A_P50, LCOH_B_P50, Pwin_pct` | The heat-route advantage persists under future cost trajectories and is robust to parameter uncertainty: across the high-DNI ladder the probability the heat route wins reaches up to 100% (mean 76%), supporting a probabilistic dominance claim rather than a point estimate. |
| 7 | SOEC electrochemistry: polarization & efficiency | Fig. 7. SOEC behaviour. (a) Cell voltage versus current density decomposed into reversible, activation, ohmic and concentration contributions (the dotted line is the thermoneutral voltage); (b) electrical and total specific energy consumption (left) and LHV efficiency (right). | The Butler-Volmer activation, Arrhenius ohmic and Nernstian concentration overpotentials (Eqs 23-29) build the polarization curve. Operating below the thermoneutral voltage keeps the cell endothermic, so part of the energy is drawn as heat - exactly the lever exploited by the heat route. | `i_Acm2, Vrev, Vcell, eta_act, eta_ohm, eta_conc, SEC_el, SEC_tot, eta_LHV` | At the chosen operating point the cell needs only ~30 kWh/kg of electricity (vs ~52 for LT electrolysis) at an LHV efficiency near 89%; raising current density increases overpotentials and electrical SEC, defining the efficiency-throughput trade-off. |
| 8 | Energy cascade per kg H2 (both routes) | Fig. 8. Energy cascade per kilogram of hydrogen for (a) the heat route and (b) the electricity route (Atacama (Chile) exemplar). | Bars trace the energy required at each stage, normalized to the delivered hydrogen. Optical/receiver losses dominate the heat-route front end; curtailment and conversion losses shape the electricity-route cascade. | `Stage_A, kWh_per_kg` | The heat route delivers a kilogram of hydrogen from ~143 kWh of incident sunlight; the electricity route needs ~62 kWh of generated electricity. The narrowing of the cascade reveals where useful energy is lost and where each route can be improved. |
| 9 | Exergy destruction map and second-law efficiency | Fig. 9. Exergy analysis (Atacama (Chile) exemplar). (a) Annual exergy destruction by component for the heat and electricity routes; (b) conversion-chain and primary second-law efficiencies of the three architectures. | Component exergy destruction is obtained from steady exergy balances (Eq 61) with solar exergy from the Petela factor. The bars localize irreversibility; psi quantifies how much of the input exergy survives as chemical exergy of hydrogen. | `Component_A, ExergyDestruction_GWhyr` | The heat route attains a higher conversion-chain exergy efficiency (psi=0.85) than the electricity route (psi=0.58); its largest destruction sits in solar collection and the Rankine block, whereas the electricity route loses most exergy in the electrolyzer itself. |
| 10 | Entropy generation by component | Fig. 10. Entropy-generation analysis (Atacama (Chile)). Component entropy-generation rates from the Gouy-Stodola theorem (S_gen = Ex_dest/T0), with the cumulative share for the heat route on the right axis. | Entropy generation is proportional to exergy destruction; ranking components by S_gen identifies the dominant irreversibilities that limit second-law performance and guides where design effort yields the most. | `Component, Sgen_A_kWK, Sgen_B_kWK` | The dominant entropy source is the optical for the heat route and the LT_EL for the electricity route; targeting it offers the largest thermodynamic improvement, while the entropy-generation number quantifies overall irreversibility. |
| 11 | First- vs second-law efficiencies by site | Fig. 11. First-law (energy) and second-law (exergy) conversion efficiencies of the heat and electricity routes across the archetype sites, with the heat-route solar-to-hydrogen efficiency on the right axis. | For each site the four bars give the energy and exergy efficiencies of both routes; the dashed line is the overall solar-to-hydrogen efficiency of the heat route, which folds in the solar-collection step. | `Site, etaI_A, etaII_A, etaI_B, etaII_B, etaSTH_A` | The heat route is consistently superior on both laws (mean eta_I=0.80, eta_II=0.83) versus the electricity route (mean eta_I=0.59, eta_II=0.58); solar-to-hydrogen efficiency rises with site resource quality. |
| 12 | Dimensionless analysis (classical + innovative) | Fig. 12. Dimensionless characterization of the heat route (Atacama (Chile)). (a) Classical transport/thermal groups (Reynolds, Prandtl, Nusselt, Peclet, Grashof, Rayleigh, Biot, Fourier, Jakob, Stefan); (b) innovative route-specific groups defined in this work. | The classical groups characterize molten-salt receiver convection (Re,Pr,Nu,Pe), receiver natural-convection/radiation losses (Gr,Ra), TES transient conduction (Bi,Fo) and steam raising (Ja,Ste). The innovative groups - heat leverage, electrical substitution, exergy quality, storage-medium split, solar multiple, storage number and exergetic sustainability index - compress the techno-economic mechanism into transferable numbers. | `Group, Value` | The receiver operates in the fully-turbulent regime (Re~2e+05), TES is thermally thin (Bi=1.92), and the heat-leverage group Lambda=0.21 together with the electrical-substitution number (0.38) and exergetic sustainability index (6.5) provide a compact, physically-grounded explanation of the heat-route advantage. |
| 13 | Diurnal/seasonal heat-route dispatch (TES) | Fig. 13. Heat-route dispatch (Atacama (Chile)). Hour-by-month heatmaps of (a) CSP field thermal output and (b) molten-salt TES state of charge, with (c) the mean-day balance of field output, firm thermal load and storage. | Thermal energy is collected during the day, charged into the two-tank molten-salt store, and discharged overnight to hold the electrolyzer at a constant firm load - the diurnal storage cycle that underpins firmness. | `Hour, FieldOut_kWth, FirmLoad_kWth, TES_SOC_kWhth` | The TES fills during solar hours and drains overnight, sustaining firm output around the clock; the seasonal heatmaps show how winter days draw the store deeper, which sets the storage-hours sizing. |
| 14 | Economic structure: CAPEX, LCOH build-up, abatement | Fig. 14. Techno-economics (Atacama (Chile)). (a) Capital-cost structure of the two routes; (b) build-up of heat-route LCOH from annualized capital, O&M, stack replacement and water; (c) CO2 abatement cost relative to grey (SMR) hydrogen. | Capital expenditure is decomposed by component (Eq 51); LCOH follows from the capital-recovery factor plus operating, replacement and water costs (Eqs 52-56). Abatement cost compares the green premium with the avoided SMR emissions. | `Component_A, CAPEX_MUSD` | The heat-route capital is dominated by the solar field/block and SOEC, and its lower LCOH translates to a CO2 abatement cost of ~152 USD/tCO2 versus ~559 for the electricity route, a decisive economic and climate advantage. |
| 15 | Environmental indicators by site | Fig. 15. Environmental indicators of the heat route by site: avoided CO2 versus grey hydrogen and feed-water demand (left axis), and land use per kilogram of hydrogen (right axis). | Avoided emissions use the SMR carbon intensity; water is the process+stoichiometric demand; land scales with the solar field aperture. Different ranges are shown on dual axes for legibility. | `Site, CO2_avoided_ktyr, Water_ktyr, Land_m2perkg` | Each plant avoids on the order of 7 ktCO2/yr against grey hydrogen at modest water (6.7 kt/yr) and land (0.19 m2/kg) intensity, situating the heat route favourably on the water-energy-land nexus. |
| 16 | Tornado sensitivity of the heat-route advantage | Fig. 16. Local one-at-a-time sensitivity (tornado) of the heat-route ADVANTAGE DeltaLCOH = LCOH_B - LCOH_A to the principal techno-economic parameters at a high-DNI site (base DeltaLCOH = 4.10 USD/kg). CSP/TES/SOEC costs act through the heat route; PV/wind/battery/LT costs through the electricity route. | Each bar spans the change in the cost gap when a single parameter is moved across its literature range with all others fixed; bars are ranked by influence. Unlike a heat-route-only LCOH tornado, every component cost has an effect because it shifts one of the two competing routes. | `Parameter, dLCOH_low, dLCOH_high, LCOH_A_low, LCOH_A_high, LCOH_B_low, LCOH_B_high` | The heat-route advantage is most sensitive to WACC and the cost of capital; cheaper batteries and electrolyzers narrow the gap (they help the electricity route), while cheaper CSP/TES widen it - all retain a positive advantage across the ranges. |
| 17 | Monte-Carlo LCOH distributions & dominance probability | Fig. 17. Monte-Carlo uncertainty (M=400, Latin-hypercube over costs and WACC). (a) Firm-LCOH distributions for both routes at selected DNI; (b) probability the heat route is firm-feasible AND cheaper (solid) versus merely cheaper ignoring feasibility (dashed), against DNI. | Parameter uncertainty is propagated through the full optimization. The dominance probability is feasibility-aware: at low DNI the heat route cannot hold a firm 24-h output (reliability below the floor) so it cannot win even when its nominal LCOH is lower (dashed line). | `DNI, A_P10, A_P50, A_P90, B_P10, B_P50, B_P90, Pwin_pct` | Dominance probability rises from ~0 below the firm-feasibility threshold (~1700 kWh/m2/yr) to ~100% across the high-DNI belt; the gap between the dashed and solid curves is exactly the firmness constraint biting at low resource. |
| 18 | Storage-medium split frontier and hybrid sizing | Fig. 18. The storage-medium split frontier: cost-optimal thermal share of the hybrid architecture (left axis) and the corresponding PV capacity and TES hours (right axis) versus annual DNI. | At each DNI the hybrid co-optimizes thermal (CSP/TES) and electrical (PV/battery) storage. BELOW the firm-feasibility threshold the CSP field alone cannot hold a 24-h output, so cost-optimal hybrids ADD photovoltaics (daytime electricity) to reach firmness, giving a thermal share below 100%. ABOVE the threshold the heat route is firm-feasible and cheapest on its own, so the optimal PV capacity falls to zero and the thermal share saturates at 100%. The TES duration is the storage needed to bridge the night; it is largest at low DNI (compensating a weaker, more variable resource) and saturates near the night-length requirement (~12 h) at high DNI. | `DNI, SigmaThermal_pct, PV_MW, TES_h, SolarMultiple` | The optimal storage medium shifts with resource: below ~1700 kWh/m2/yr cheap daytime PV is added (thermal share down to ~70%), while above it pure thermal storage is cost-optimal (PV -> 0, sigma_th -> 100%) and the TES duration settles near the overnight requirement. |
| 19 | Heat-leverage exergy mechanism vs DNI | Fig. 19. The heat-leverage mechanism: conversion-chain exergy efficiency of the two routes (left axis) and the resulting cost gap DeltaLCOH (right axis) versus annual DNI. | By supplying part of the splitting energy as high-temperature heat that can be stored cheaply, the heat route attains a higher second-law efficiency; the figure links this thermodynamic advantage directly to the economic cost gap. | `DNI, psi_A, psi_B, dLCOH, FirmFeasible` | The heat route maintains an exergy efficiency of ~80% versus ~57% for the electricity route; this persistent second-law advantage is the physical cause of the cost gap, which widens with the solar resource. |
| 20 | Validation against physical bounds & benchmarks | Fig. 20. Validation panel. Model outputs (markers) against expected physical/literature ranges (grey bars); 20 of 20 checks pass. | Each row checks a model output (SOEC voltage and efficiency, LCOH ranges, exergy efficiencies, reliability, Petela factor, dominance share) against an independent physical bound or published benchmark (Section 13 targets). | `Check, Value, Min, Max, Units, Pass` | 20 of 20 validation checks lie within their expected ranges, supporting the credibility of the model before its new results are interpreted. |
| 21 | Comprehensive uncertainty of all results | Fig. 21. Comprehensive uncertainty analysis (M=400 Latin-hypercube draws over component costs, WACC and an 8% resource-data error). (a) Coefficient of variation of every reported result; (b) firm-LCOH distributions of the three routes at the reference cell; (c) distribution of the crossover DNI* and the cumulative distribution of the cost gap. | Both techno-economic parameters and the satellite resource estimate are perturbed and propagated through the full optimization. The table behind this figure lists mean, standard deviation, CV and P10/P50/P90 with 95%% confidence intervals for each result. | `Metric, Mean, Std, CV_pct, P10, P50, P90, CI95_lo, CI95_hi` | All headline results are robust: the cost gap remains positive in 100% of draws at the reference site, the heat-route LCOH distribution sits clearly below the electricity route, and the crossover DNI* has a P10-P90 spread that still places it within the high-DNI belt. |

---

## 16. Generated scientific tables (15)

All tables are in `output/HeatRoute_FirmH2_Tables.xlsx` (one sheet each) and as native Word tables in `output/HeatRoute_FirmH2_Tables.docx`.

| # | Sheet | Contents / description | Interpretation |
|---|-------|------------------------|----------------|
| 1 | `T01_Nomenclature` | Symbols, descriptions and units of all model quantities. | Reference key for the equations and results. |
| 2 | `T02_Parameters` | Principal technology and cost parameters with values, units and literature sources. | Documents every assumption; defensible defaults and Monte-Carlo priors. |
| 3 | `T03_Headline_Results` | The five headline results (R1–R5) with central values and uncertainty ranges. | One-glance summary of the study's claims. |
| 4 | `T04_Site_Results` | Per-archetype lat/lon, measured DNI, WACC, LCOH_A/B/C, ΔLCOH, reliability, winning route. | High-DNI sites are won by the heat route; the low-DNI site (Germany) by the electricity route. |
| 5 | `T05_Sizing_HeatRoute` | Optimal heat-route sizing per site: solar multiple, TES hours, aperture, stack cells, SOEC power, TES energy. | Shows how field and storage shrink as DNI rises. |
| 6 | `T05b_Sizing_ElecRoute` | Optimal electricity-route sizing per site: PV, wind, battery energy/hours, LT power. | Quantifies the large PV oversizing and battery needed to firm the battery route. |
| 7 | `T06_Energy_Exergy` | Energy and exergy balance per route at the exemplar site (inputs, H₂ out, destruction, η_I, ψ, S_gen, N_s). | The heat route preserves more input exergy as hydrogen; dominant irreversibilities identified. |
| 8 | `T07_Efficiency` | First- and second-law efficiencies, solar-to-H₂ and SEC by site and route. | Heat route superior on both laws and in specific energy across all sites. |
| 9 | `T08_Dimensionless` | Classical and innovative dimensionless groups with values and physical meaning. | Compact, transferable physical characterization of the heat route. |
| 10 | `T09_Economics` | CAPEX, annualized cost, per-kg LCOH build-up, CO₂-abatement cost and levelized exergy cost per route. | Heat-route capital is field/block/SOEC-dominated; far lower abatement cost than the battery route. |
| 11 | `T10_Environmental` | Avoided CO₂, water demand, land per kg and EROI by site. | Each plant avoids ~7 ktCO₂/yr at modest water and land intensity. |
| 12 | `T11_Cost_Scenarios` | Firm LCOH for both routes under 2025/2030/2050 cost projections by site. | The heat-route advantage persists and widens under future cost learning. |
| 13 | `T12_Uncertainty` | Mean/std/CV/P10/P50/P90/95 %-CI of every reported result (M = 400 LHS draws). | All headline results are robust to cost, financing and resource uncertainty. |
| 14 | `T13_Validation` | The 20 validation checks (value vs expected min/max, pass/fail). | 20/20 pass, establishing model credibility before interpretation. |
| 15 | `Figure_Index` | Index of all 21 figures (name, caption, description, data columns, interpretation). | Navigation and provenance for every display item. |

---

## 16.1 Limitations and scope

- The comparison fixes the *electricity* storage medium as **batteries** (per the study's framing); hydrogen-buffer firming is a separate lever not considered.
- The 1° maps are driven by NASA POWER **measured monthly climatology** (native 1° solar, MERRA-2 meteorology), interpolated to the integer-degree grid; intra-day shape is modelled from solar geometry.
- Component models are 0-D/representative and benchmarked, not plant-calibrated; SOEC durability and water/land remain real constraints.
- Sizing uses deterministic grid-plus-refine search with light regularization; results are robust but not globally proven optima.

---

*Generated from the MATLAB pipeline outputs; all numeric values trace to `output/HeatRoute_FirmH2_Results.mat` and the Excel workbooks.*
