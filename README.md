# The Heat Route to Firm Green Hydrogen

A spatially-explicit, firmness-resolved **techno-economic, thermodynamic and
environmental** model that compares three architectures for firm (24-hour) green
hydrogen, and maps **where** each one is the least-cost choice:

| Arch. | Name | Configuration | Storage medium |
|------|------|---------------|----------------|
| **A** | Heat route | CSP field → two-tank molten-salt TES → Rankine block → **SOEC** | Thermal |
| **B** | Electricity route | PV (+ wind) → Li-ion battery → low-temperature (PEM/alkaline) electrolyzer | Electrical |
| **C** | Hybrid | PV + CSP/TES + SOEC, co-optimized | Thermal + electrical (the *split*) |

The MATLAB pipeline solves the full model (71 equations), runs every analysis
layer (energy, exergy, entropy, 1st/2nd-law efficiency, dimensionless, economic,
environmental, uncertainty, sensitivity, machine-learning), and writes
**42 figures** (21 core + 13 + 8 extension) and **26 tables** (15 core + 11
extension), an Excel workbook of all figure data, a native-Word
equations document, and a reproducible `.mat` results archive.

> See `METHODOLOGY.md`, `EXTENSIONS.md` and `EXTENSIONS2.md` for the full
> scientific documentation of the model, figures and tables.

---

## 1. System requirements

### MATLAB version
- **Developed and tested on:** MATLAB **R2025b** (Update 5).
- **Minimum recommended:** MATLAB **R2024a** or newer.
  The code uses `tiledlayout`/`nexttile`, `exportgraphics`, string arrays and the
  `fitrnet` regression network, so R2021a is the absolute floor; R2024a+ is
  recommended for full compatibility and styling.

### Required toolboxes
The pipeline is deliberately lean. Only **one** add-on toolbox is required:

| Toolbox | Why it is needed | Functions used |
|---------|------------------|----------------|
| **Statistics and Machine Learning Toolbox** | Monte-Carlo / uncertainty sampling, percentiles, and all ML surrogates | `lhsdesign`, `prctile`, `cvpartition`, `corr`, `perfcurve`, `fitlm`, `fitrtree`, `fitrensemble`, `fitrgp`, `fitrnet`, `fitcensemble`, `oobPermutedPredictorImportance` |

Everything else runs on **base MATLAB**: `scatteredInterpolant` (resource
interpolation), `tiledlayout`/`yyaxis` (figures), `polyfit` (correlations),
`savefig`/`openfig` (figure export), `writetable`/`writecell` (Excel export), and
the built-in sample data `topo` (land mask) and `coastlines` (coastline overlay).

> **Not required:** Mapping, Optimization, Global Optimization, Curve Fitting,
> Deep Learning, Parallel Computing or Symbolic Math toolboxes. The supply sizers
> use a deterministic grid-plus-refine search (no `fmincon`/`ga`), and the maps
> are drawn with base graphics, so the model is portable across MATLAB licences.

### Operating system
- **Tested on:** Microsoft **Windows 11 Pro**, Version 10.0 (Build 26200).
- **Cross-platform:** all paths are built with `fullfile`, so the code also runs
  on macOS and Linux without modification.

### Python (optional — only for re-fetching data or rebuilding the equations doc)
- **Python 3.x**, **standard library only** (`urllib`, `csv`, `json`, `zipfile`,
  `concurrent.futures`). **No `pip` packages are required.**
- Needed *only* if you want to (a) re-download the NASA POWER climatology, or
  (b) regenerate the native-Word equations document. The repository already ships
  the cached data and the generated `.docx`, so Python is **not** needed for a
  normal run.

---

## 2. Quick start

1. Open MATLAB and set this folder as the current directory:
   ```matlab
   cd('D:\MATLAB_codes\ClaudeCodeWS\HeatRouteFirmH2')
   ```
2. Run the master driver:
   ```matlab
   HeatRoute_FirmH2_Main
   ```
   This solves the global model, runs every core analysis, self-validates
   (20/20 checks), and writes the 21 core figures, the figure-data workbook and
   `HeatRoute_FirmH2_Results.mat` into `output/`. Runtime ≈ **5 minutes** on a
   modern workstation (fixed RNG seed → fully reproducible).

The resource interface is automatic: if the NASA CSV caches are present in
`data/`, the maps use **measured** climatology; otherwise the code falls back to
a physically-based synthetic clear-sky field. No switch needs to be set.

### MATLAB MCP note
This project is run through the **MATLAB MCP interface** (`mcp__matlab__*`). Scripts
can also be launched normally from the MATLAB Editor or Command Window.

---

## 3. Full reproduction (all deliverables)

Run the following in order from the project folder:

```matlab
% --- 1. Core model: figures, figure-data Excel, Results.mat -------------
HeatRoute_FirmH2_Main

% --- 2. Scientific tables (Excel + native Word) ------------------------
P = hr_config();  S = load(P.io.matfile);  D = S.D;
TBL = hr_make_tables(P, D);          % -> HeatRoute_FirmH2_Tables.xlsx
hr_make_tables_doc(P, TBL);          % -> HeatRoute_FirmH2_Tables.docx

% --- 3. Extension layer 1: storage/transport, ML/AI, geo-economics -----
HeatRoute_FirmH2_Extensions          % -> Ext_Figure_*.fig + EXTENSIONS.md

% --- 4. Extension layer 2: rich multi-tile scientific analyses ---------
HeatRoute_FirmH2_Extensions2         % -> Ext2_Figure_*.fig + EXTENSIONS2.md
```

Optional Python utilities (only if regenerating data or equations):

```bash
python fetch_nasa_regional.py   # re-download native 1-deg NASA POWER (throttled, ~8 min/pass)
python fill_missing_nasa.py     # fill any gaps in the cached grid
python make_equations_doc.py    # rebuild HeatRoute_FirmH2_Equations.docx (native Word equations)
```

---

## 4. Input files

All inputs live in **`data/`** and are cached **NASA POWER long-term monthly
climatology** (community *RE*). They are read by `hr_load_nasa.m` and interpolated
onto the model grid. Each solar/meteorology parameter is stored separately because
NASA serves them on different native grids.

| File | Contents | Notes |
|------|----------|-------|
| `data/nasa_param_DNI.csv` | Direct normal irradiance, `ALLSKY_SFC_SW_DNI` | ~27,500 native 1° points |
| `data/nasa_param_GHI.csv` | Global horizontal irradiance, `ALLSKY_SFC_SW_DWN` | ~27,500 native 1° points |
| `data/nasa_param_T.csv` | 2-m air temperature, `T2M` | ~88,937 MERRA-2-grid points |
| `data/nasa_param_W.csv` | 50-m wind speed, `WS50M` | ~88,937 MERRA-2-grid points |
| `data/nasa_power_grid.csv` | Combined coarse grid cache | legacy / fallback |
| `data/nasa_power_grid_4deg.csv` | 4° anchor grid | legacy / fallback |
| `data/nasa_power_arch.csv` | Per-archetype-site measured climatology | the 8 named sites |

All physical, technology and cost parameters (the rest of the "input") are defined
**in code** in `hr_config.m` — the single source of truth for the model.

If `data/` is empty or missing, the pipeline still runs end-to-end using the
synthetic clear-sky resource model (the data interface is identical).

---

## 5. Output files

Everything is written to **`output/`**. Figures are saved **only in MATLAB `.fig`
format** (per project policy).

| Output | Count / file | Description |
|--------|--------------|-------------|
| Core figures | `Figure_001…021_*.fig` (21) | Publication figures (maps, mechanism, exergy/entropy, economics, validation, uncertainty). |
| Extension figures (L1) | `Ext_Figure_001…013_*.fig` (13) | Storage/transport value chain, ML/AI surrogates, political-economic analysis. |
| Extension figures (L2) | `Ext2_Figure_001…008_*.fig` (8) | Rich multi-tile analyses (regime surfaces, Pareto, global sensitivity, Taylor diagram, Grassmann/entropy). |
| Figure data | `HeatRoute_FirmH2_FigureData.xlsx` | One sheet per core figure: caption, explanation, interpretation + all plotted numbers. |
| Extension figure data | `HeatRoute_FirmH2_Extensions_FigureData.xlsx`, `…_Extensions2_FigureData.xlsx` | Same, for each extension layer. |
| Tables | `HeatRoute_FirmH2_Tables.xlsx` (15 sheets) + `HeatRoute_FirmH2_Tables.docx` | Nomenclature, parameters, headline results, per-site sizing, energy/exergy, efficiency, dimensionless, economics, environmental, scenarios, uncertainty, validation. |
| Extension tables | `…_Extensions_Tables.xlsx`, `…_Extensions2_Tables.xlsx` | Conditioning/storage, ML performance, risk register, etc. |
| Equations | `HeatRoute_FirmH2_Equations.docx` | All model equations as **native MS-Word equation objects**, with discussion. |
| Results archive | `HeatRoute_FirmH2_Results.mat` | Full `D` struct: every numeric result (reproducible source of all values). |
| Extension archives | `HeatRoute_FirmH2_Extensions.mat`, `…_Extensions2.mat` | Numeric results of each extension layer. |

Companion **documentation** (Markdown, in the project root): `METHODOLOGY.md`,
`EXTENSIONS.md`, `EXTENSIONS2.md`.

---

## 6. Source files

### MATLAB modules
| File | Role |
|------|------|
| `HeatRoute_FirmH2_Main.m` | Master driver — orchestrates the whole study. |
| `hr_config.m` | All physical/technology/cost parameters, the grid, the 8 archetype sites, styling. **Single source of truth.** |
| `hr_load_nasa.m` | Read cached NASA CSVs; interpolate each parameter from its own native grid onto the model grid. |
| `hr_resource.m` | Solar geometry + 12 monthly typical-day hourly profiles (measured-anchored or synthetic). |
| `hr_solve_cell.m` | Physics core: component models (Eqs 7–43), least-cost supply sizers, firmness dispatch, economics. |
| `hr_analyze_arch.m` | Energy, exergy, entropy (Gouy–Stodola), efficiencies, dimensionless groups, environmental indicators. |
| `hr_montecarlo.m`, `hr_dominance_map.m`, `hr_tornado.m`, `hr_uncertainty.m` | Uncertainty propagation, dominance-probability map, tornado sensitivity, comprehensive uncertainty. |
| `hr_make_figures.m`, `hr_export_excel.m` | Build the 21 core figures; export one Excel sheet per figure. |
| `hr_make_tables.m`, `hr_make_tables_doc.m` | Build the 15 scientific tables (Excel + native Word). |
| `hr_validate.m` | 20 independent validation checks against physical bounds and benchmarks. |
| `hr_extensions.m`, `HeatRoute_FirmH2_Extensions.m` | Extension layer 1 (storage/transport, ML/AI, geo-economics). |
| `hr_extensions2.m`, `HeatRoute_FirmH2_Extensions2.m` | Extension layer 2 (rich multi-tile analyses). |

### Python utilities (optional)
| File | Role |
|------|------|
| `fetch_nasa_power.py`, `fetch_nasa_regional.py` | Download NASA POWER climatology (point / native-1° regional endpoints). |
| `fill_missing_nasa.py` | Fill gaps in the cached grid. |
| `make_equations_doc.py` | Generate the native-Word equations document (mini-LaTeX → OMML). |

---

## 7. Reproducibility

- A single `HeatRoute_FirmH2_Main` run is **fully reproducible** (fixed RNG seed).
- The model **self-validates** (20/20 physical/benchmark checks) before figures
  are produced.
- Every numeric value in the figures, tables and documents traces back to
  `output/HeatRoute_FirmH2_Results.mat`.

---

## 8. Contact

**Prof. H. S. S. AbdelMeguid**
Mechanical Power Engineering
Faculty of Engineering, Mansoura University, Egypt
Email: **hssaleh@mans.edu.eg**

---

*Prepared as the README for the Heat-Route Firm Green Hydrogen MATLAB study.
For scientific details, see `METHODOLOGY.md` and the equations document.*
