function P = hr_config()
%HR_CONFIG  Master parameter set for the "Heat Route to Firm Green Hydrogen" model.
% =========================================================================
% PROJECT : The Heat Route to Firm Green Hydrogen
%           Spatially-explicit techno-economic comparison of
%             A) CSP + two-tank molten-salt TES + Rankine + high-T SOEC   (heat route)
%             B) PV/Wind + Li-ion battery + low-T PEM/alkaline electrolyzer (electricity route)
%             C) Co-optimized hybrid  PV + CSP/TES + SOEC                  (storage-medium split)
%
% PURPOSE : Returns a single immutable structure P that gathers every
%           universal constant, technology parameter, cost figure, financial
%           assumption and numerical setting used by the model. Centralising
%           them here guarantees scientific reproducibility (one source of truth).
%
% AUTHOR  : <AUTHOR PLACEHOLDER>            (generated for Prof. H. S. S. AbdelMeguid)
% DATE    : <DATE PLACEHOLDER>
% VERSION : 1.0
%
% INPUTS  : none
% OUTPUTS : P  (struct)  - nested parameter structure, fields documented inline
%
% ASSUMPTIONS:
%   * Values are representative literature figures / Monte-Carlo priors taken
%     from the model document (Sections 2-12); physical constants are fixed.
%   * SI units throughout unless a field name states otherwise
%     (powers kW, energies kWh, thermal energies kWh_th, money constant USD).
%
% REFERENCES (keyed to the Mathematical-Model document):
%   [1] Millet (2015); RSC Mater.Adv. 2022   [2] NREL/CP-550-47302 (2010)
%   [3] Mueller et al., Chem.Ing.Tech. 2024  [4] J.Phys.Energy 2025
%   [7] Energy 2024 (CSP-SOEC)               [9] Solar Energy 2013 (two-tank TES)
%   [10] J.Energy Storage 2024               [11] Energy 2014 (trough optics)
%   [12] Duffie & Beckman (2013)             [13] Sandia PVPMC NOCT
%   [14] Renewable Energy 2020 (wind)        [15] NREL ATB 2025
%   [17,18] Monte-Carlo LCOH studies         [19] Applied Energy 2025 (electrolyzers)
%   [20] Nat.Commun. 2023 (land/water)       [22] Petela (2003)
% =========================================================================

P = struct();
P.meta.title    = "The Heat Route to Firm Green Hydrogen";
P.meta.version  = "1.0";
P.meta.created  = datetime("now");

% -------------------------------------------------------------------------
% 1. Time discretization (Section 1.1)
%    Dispatch uses 12 monthly typical days at hourly resolution (288 h).
%    This representative-day reduction captures the diurnal storage cycle that
%    governs FIRM (24-h) output and the seasonal worst-month that sizes the
%    plant, at ~30x lower cost than a full 8760-h run, and is a standard,
%    citable TMY-day reduction. Annual quantities scale typical-day results by
%    days-per-month.
% -------------------------------------------------------------------------
P.time.dt_h        = 1;                                   % time-step length [h]  (Delta t)
P.time.hours       = (0:23)';                             % hour-of-day vector [h]
P.time.nHour       = 24;                                  % hours per representative day
P.time.monthDays   = [31 28 31 30 31 30 31 31 30 31 30 31]'; % days per month
P.time.monthMid    = cumsum(P.time.monthDays) - P.time.monthDays/2; % mid-month day-of-year n
P.time.nMonth      = 12;
P.time.hoursPerYr  = 8760;

% -------------------------------------------------------------------------
% 2. Universal constants & hydrogen thermodynamics (Section 2, Eqs 1-2)
% -------------------------------------------------------------------------
C = struct();
C.F        = 96485;        % Faraday constant [C/mol]                         [1]
C.Rgas     = 8.314;        % universal gas constant [J/mol/K]                 [2]
C.z        = 2;            % electrons per H2 molecule [-]                    [1]
C.M_H2     = 2.016e-3;     % molar mass H2 [kg/mol]                           [1]
C.M_H2O    = 18.015e-3;    % molar mass H2O [kg/mol]                          [1]
C.dH0      = 285.8e3;      % enthalpy of splitting (liq,298K) [J/mol]         [1,2]
C.dG0      = 237.2e3;      % Gibbs energy of splitting (298K) [J/mol]         [1,2]
C.TdS0     = 48.6e3;       % reaction heat term TdS0 (298K) [J/mol]           [1,2]
C.HHV_H2   = 141.8e6;      % higher heating value [J/kg]  (39.4 kWh/kg)       [1]
C.LHV_H2   = 120.0e6;      % lower heating value  [J/kg]  (33.33 kWh/kg)      [1]
C.ex_H2    = 118.0e6;      % specific chemical exergy of H2 [J/kg] (236.1 kJ/mol) [22]
C.T0       = 288.15;       % reference (dead-state) temperature [K]           [22]
C.p0       = 101325;       % reference (dead-state) pressure [Pa]
C.Tsun     = 5777;         % apparent sun radiation temperature [K]           [22]
C.g        = 9.81;         % gravitational acceleration [m/s^2]
C.sigmaSB  = 5.670374e-8;  % Stefan-Boltzmann constant [W/m^2/K^4]
% derived reference voltages (Eqs 1-2)
C.Vrev0    = C.dG0/(C.z*C.F);   % 1.229 V
C.Vtn0     = C.dH0/(C.z*C.F);   % 1.481 V
% convenient kWh conversions
C.kWh_per_kg_HHV = C.HHV_H2/3.6e6;   % 39.39
C.kWh_per_kg_LHV = C.LHV_H2/3.6e6;   % 33.33
P.const = C;

% -------------------------------------------------------------------------
% 3.2 Photovoltaic parameters (Eqs 7-8)              [13]
% -------------------------------------------------------------------------
P.pv.Gstc      = 1000;     % irradiance at STC [W/m^2]
P.pv.NOCT      = 45;       % nominal operating cell temperature [degC]
P.pv.gamma     = 0.0040;   % power temperature coefficient [1/degC]
P.pv.eta_sys   = 0.80;     % system / derate efficiency (performance ratio) [-]
P.pv.Tref      = 25;       % reference cell temperature [degC]

% -------------------------------------------------------------------------
% 3.3 Wind parameters (Eqs 9-11)                     [14]
% -------------------------------------------------------------------------
P.wind.v_in    = 3.0;      % cut-in wind speed [m/s]
P.wind.v_r     = 12.0;     % rated wind speed [m/s]
P.wind.v_out   = 25.0;     % cut-out wind speed [m/s]
P.wind.rho0    = 1.225;    % reference air density [kg/m^3]

% -------------------------------------------------------------------------
% 4. CSP solar field (Eqs 12-16)                     [11,12]
% -------------------------------------------------------------------------
P.csp.eta_opt0 = 0.75;     % peak optical efficiency [-]
P.csp.b1       = 2.2e-4;   % IAM linear coefficient [1/deg]
P.csp.b2       = 3.4e-5;   % IAM quadratic coefficient [1/deg^2]
P.csp.f_avail  = 0.98;     % field availability [-]
P.csp.f_clean  = 0.95;     % mirror cleanliness factor [-]
P.csp.a0       = 0.6;      % thermal-loss const term [W/m^2]
P.csp.a1       = 0.30;     % thermal-loss linear term [W/m^2/K]
P.csp.a2       = 0.0010;   % thermal-loss quadratic term [W/m^2/K^2]
P.csp.T_htf    = 565;      % HTF / receiver temperature [degC] (tower)
P.csp.Arec_per_Aap = 0.011;% receiver/aperture area ratio (sets absolute losses) [-]
P.csp.SM_bounds   = [1.5 4.0];  % solar multiple search bounds [-]

% -------------------------------------------------------------------------
% 5. Two-tank molten-salt TES + Rankine power block (Eqs 17-22)  [9,10]
% -------------------------------------------------------------------------
P.tes.eta_ch   = 0.99;     % charge efficiency [-]
P.tes.eta_dis  = 0.98;     % discharge efficiency [-]
P.tes.phi_sb   = 0.031;    % standby loss rate [%/h]
P.tes.T_cold   = 290;      % cold tank temperature [degC]
P.tes.T_hot    = 565;      % hot tank temperature [degC]
P.tes.cp_salt  = 1.53;     % molten-salt heat capacity [kJ/kg/K]
P.tes.hTES_bounds = [4 24];% storage-hours search bounds [h] (24=full-day bridging)

P.pb.eta_pb    = 0.40;     % design power-block (Rankine) efficiency [-]
P.pb.fpl_min   = 0.85;     % minimum part-load correction [-]
P.pb.f_par     = 0.10;     % parasitic fraction [-]

% -------------------------------------------------------------------------
% 6. SOEC electrochemical & thermal model (Eqs 23-37)  [3,4,5,6]
% -------------------------------------------------------------------------
S = struct();
S.T_op     = 1073;         % operating temperature [K]
S.i_bounds = [0.3 1.0];    % current-density search bounds [A/cm^2]
S.i_design = 0.5;          % nominal operating current density [A/cm^2]
S.A_cell   = 100;          % active cell area [cm^2]
S.alpha_an = 0.5;          % anode charge-transfer coefficient [-]
S.alpha_cat= 0.5;          % cathode charge-transfer coefficient [-]
S.gamma_an = 1.0e10;       % anode pre-exponential [A/m^2]
S.gamma_cat= 1.0e11;       % cathode pre-exponential [A/m^2]
S.Eact_an  = 1.0e5;        % anode activation energy [J/mol]
S.Eact_cat = 1.2e5;        % cathode activation energy [J/mol]
S.delta_el = 10e-6;        % electrolyte (YSZ) thickness [m]
S.sigma0   = 3.34e4;       % conductivity pre-exponential [S/m]
S.Esigma   = 8.0e4;        % conduction activation energy [J/mol]
S.eta_F    = 0.99;         % Faradaic efficiency [-]
S.dh_vap   = 2256;         % latent heat of water [kJ/kg]
S.cp_liq   = 4.18;         % liquid water heat capacity [kJ/kg/K]
S.cp_vap   = 2.0;          % steam heat capacity [kJ/kg/K]
S.eta_rec  = 0.70;         % steam heat-recovery effectiveness [-]
S.r_deg    = 0.5;          % voltage degradation rate [%/1000h]
S.T_feed   = 25;           % feed-water temperature [degC]
S.T_boil   = 100;          % boiling temperature [degC]
S.p_H2     = 0.50;         % cathode H2 partial pressure [atm]  (Nernst)
S.p_O2     = 0.21;         % anode  O2 partial pressure [atm]
S.p_H2O    = 0.50;         % cathode steam partial pressure [atm]
S.util     = 0.70;         % steam utilization (conc. overpotential) [-]
P.soec = S;

% -------------------------------------------------------------------------
% 7. Battery + low-temperature electrolyzer (Eqs 38-43)  [15,19]
% -------------------------------------------------------------------------
P.batt.eta_bc   = 0.95;    % battery charge efficiency [-]
P.batt.eta_bd   = 0.95;    % battery discharge efficiency [-]
P.batt.SOC_min  = 0.10;    % minimum state of charge [-]
P.batt.hrs_bounds = [4 22];% battery-hours search bounds [h]

P.lt.SEC_rated = 52;       % rated specific energy use [kWh/kg]
P.lt.kappa0    = 0.05;     % part-load penalty coefficient [-]
P.lt.eta_F     = 0.99;     % Faradaic efficiency [-]
P.lt.Vtn       = 1.481;    % thermoneutral voltage (LT, electrically heated) [V]

% -------------------------------------------------------------------------
% 8. Dispatch & firmness (Eqs 44-50)                 [19,20]
% -------------------------------------------------------------------------
P.firm.CF_firm  = 0.95;    % firm capacity factor (sets firm output LEVEL) [-]
P.firm.f_aux    = 0.03;    % auxiliary / BoP load fraction of load [-]
P.firm.mdot_H2  = 100;     % rated H2 production [kg/h] (study design basis)
P.firm.rel_floor= 0.90;    % required annual firm-delivery reliability [-]
% (a design is "firm-feasible" if it meets the firm output >= rel_floor of all
%  hours; diurnal TES/battery bridge the night, a small H2 buffer the seasons.)

% -------------------------------------------------------------------------
% 9. Techno-economic parameters (Eqs 51-57)          [3,6,7,10,15,17,18,19]
%    Central values; ranges (for Monte-Carlo) given as [lo hi].
% -------------------------------------------------------------------------
E = struct();
E.c_CSP    = 4500;  E.c_CSP_rng   = [4000 6000];  % USD/kW   CSP field+block (lumped ref)
% Transparent decomposition of the lumped CSP cost into field (per aperture m^2)
% and Rankine block (per kW_e). Calibrated so a SM=2 all-electric plant ~ c_CSP.
E.c_field  = 290;                                  % solar field+receiver+HTF [USD/m^2]
E.c_block  = 1400;                                 % Rankine power block [USD/kW_e]
E.Gb_design= 900;                                  % CSP field design-point DNI [W/m^2]
E.c_TES    = 25;    E.c_TES_rng   = [20 30];      % USD/kWh_th
E.c_SOEC   = 1500;  E.c_SOEC_rng  = [1000 2500];  % USD/kW
E.c_PV     = 800;   E.c_PV_rng    = [700 1000];   % USD/kW
E.c_wind   = 1400;  E.c_wind_rng  = [1200 1600];  % USD/kW
E.c_battE  = 250;   E.c_battE_rng = [200 350];    % USD/kWh
E.c_battP  = 150;   E.c_battP_rng = [100 250];    % USD/kW  (power conversion)
E.c_LT     = 1100;  E.c_LT_rng    = [800 1500];   % USD/kW
E.WACC     = 0.08;  E.WACC_rng    = [0.05 0.12];  % weighted avg cost of capital [-]
E.life     = 27;    E.life_rng    = [25 30];      % project lifetime [yr]
E.f_repl_soec = 0.5;                               % SOEC replacement cost fraction [-]
E.L_soec   = 7;                                    % SOEC stack life [yr]
E.opex_fix = 0.025; E.opex_fix_rng= [0.02 0.03];  % fixed O&M [fraction CAPEX/yr]
E.opex_var = 0.005;                                % variable O&M [fraction CAPEX/yr]
E.c_water  = 0.003;                                % feed-water cost [USD/kg H2]
% Learning rates [%], for 2030/2050 cost scenarios
E.LR_CSP   = 0.10; E.LR_TES = 0.12; E.LR_SOEC = 0.18;
E.LR_PV    = 0.20; E.LR_wind= 0.10; E.LR_batt = 0.18; E.LR_LT = 0.13;
P.econ = E;

% -------------------------------------------------------------------------
% 9b. Cost scenarios (present / 2030 / 2050) - learning multipliers applied
%     to capital costs (Eq 57). Multipliers are scenario-level factors that
%     emulate cumulative-deployment learning without tracking capacity.
% -------------------------------------------------------------------------
P.scen.names   = ["2025" "2030" "2050"];
% capital-cost multipliers by technology and scenario [tech x scenario]
%             CSP    TES    SOEC   PV     wind   battE  LT
P.scen.mult = [ ...
   1.00   1.00   1.00   1.00   1.00   1.00   1.00 ;   % 2025
   0.88   0.92   0.70   0.82   0.93   0.74   0.80 ;   % 2030
   0.72   0.82   0.45   0.62   0.85   0.50   0.62 ];  % 2050
P.scen.techOrder = ["c_CSP" "c_TES" "c_SOEC" "c_PV" "c_wind" "c_battE" "c_LT"];

% -------------------------------------------------------------------------
% 10. Exergy / environmental references (Eqs 58-61)
% -------------------------------------------------------------------------
P.env.grid_CI    = 0.475;  % grid carbon intensity displaced [kgCO2/kWh] (global avg)
P.env.SMR_CI     = 10.0;   % CO2 intensity of grey H2 via SMR [kgCO2/kg H2]
P.env.NG_price   = 6.0;    % natural-gas reference price [USD/GJ]
P.env.SC_CO2     = 100;    % social cost of carbon [USD/tCO2]
P.env.water_spec = 9.0;    % stoichiometric+process water use [kg H2O/kg H2]

% -------------------------------------------------------------------------
% 11. Sizing search resolution (deterministic grid + refine)
% -------------------------------------------------------------------------
P.opt.nGrid     = 7;       % candidates per decision dimension (coarse grid)
P.opt.nRefine   = 5;       % candidates per dimension in refinement pass
P.opt.penalty   = 1e4;     % USD/kg penalty per kg of unmet firm H2 (infeasibility)

% -------------------------------------------------------------------------
% 12. Monte-Carlo settings (Eqs 70-71)
% -------------------------------------------------------------------------
P.mc.M          = 400;     % Monte-Carlo sample size (LHS)
P.mc.seed       = 20260620;% RNG seed for reproducibility

% -------------------------------------------------------------------------
% 13. Spatial grid + named archetype sites
%     Global resource is synthesised from latitude + a climatological
%     clearness index field (Section: hr_resource). Real NASA POWER / ERA5 /
%     Global Solar Atlas hourly data can be substituted at this interface.
% -------------------------------------------------------------------------
P.grid.lon = (-180:1:180);     % longitude grid [deg]  (1-deg; measured anchors interpolated)
P.grid.lat = (-58:1:58);       % latitude grid  [deg]  (main inhabited/land band)
P.grid.res = 1;                % resolution [deg]  (matches built-in 1-deg topography)

% Named archetype sites for deep-dive thermodynamic analysis
% columns: name, lat, lon, annualDNI[kWh/m2/yr], meanWind[m/s], WACC, clearness
A = struct('name',{},'lat',{},'lon',{},'DNI',{},'wind',{},'WACC',{},'KT',{});
A(1) = struct('name',"Atacama (Chile)",     'lat',-23.5,'lon',-68.2,'DNI',3300,'wind',5.5,'WACC',0.075,'KT',0.78);
A(2) = struct('name',"Sahara (Algeria)",    'lat', 27.0,'lon',  2.5,'DNI',2950,'wind',5.0,'WACC',0.095,'KT',0.72);
A(3) = struct('name',"Arabian Pen. (KSA)",  'lat', 24.0,'lon', 45.0,'DNI',2700,'wind',4.5,'WACC',0.070,'KT',0.69);
A(4) = struct('name',"US Southwest (AZ)",   'lat', 33.5,'lon',-112.0,'DNI',2750,'wind',4.0,'WACC',0.055,'KT',0.70);
A(5) = struct('name',"Australia (Pilbara)", 'lat',-22.0,'lon',118.0,'DNI',2850,'wind',6.0,'WACC',0.060,'KT',0.71);
A(6) = struct('name',"S. Spain (Andalusia)",'lat', 37.4,'lon', -5.0,'DNI',2150,'wind',5.0,'WACC',0.065,'KT',0.62);
A(7) = struct('name',"India (Rajasthan)",   'lat', 27.0,'lon', 73.0,'DNI',2200,'wind',4.2,'WACC',0.100,'KT',0.61);
A(8) = struct('name',"N. Germany",          'lat', 53.0,'lon', 10.0,'DNI',1100,'wind',7.5,'WACC',0.050,'KT',0.42);
P.arch = A;

% -------------------------------------------------------------------------
% 14. Output settings
% -------------------------------------------------------------------------
P.io.outdir   = fullfile(fileparts(mfilename('fullpath')),'output');
P.io.xlsx     = fullfile(P.io.outdir,'HeatRoute_FirmH2_FigureData.xlsx');
P.io.matfile  = fullfile(P.io.outdir,'HeatRoute_FirmH2_Results.mat');
if ~exist(P.io.outdir,'dir'); mkdir(P.io.outdir); end

% Publication figure style
P.style.font      = 'Helvetica';
P.style.fontSize  = 12;
P.style.lw        = 1.8;
P.style.cmapSeq   = 'turbo';
% colour-blind-safe categorical palette (Architectures A/B/C)
P.style.colA = [0.84 0.19 0.15];   % heat route  - warm red
P.style.colB = [0.13 0.40 0.67];   % electricity route - cool blue
P.style.colC = [0.20 0.63 0.36];   % hybrid - green
end
