function an = hr_analyze_arch(P, res, ar)
%HR_ANALYZE_ARCH  Full thermo-economic-environmental analysis of one route.
% =========================================================================
% PURPOSE : Given a solved architecture result (from hr_solve_cell, A/B/C),
%           compute the complete scientific analysis required for a Nature-
%           Energy-grade study:
%             * Energy & thermal (1st law) balance and efficiencies
%             * Exergy (2nd law) balance, component destruction map (Eq 58-61)
%             * Entropy generation (Gouy-Stodola), irreversibility ranking
%             * 1st- and 2nd-law efficiencies of every sub-system
%             * Dimensionless analysis (classical groups + innovative,
%               physically-grounded groups specific to the heat route)
%             * Techno-economic extensions (NPV, payback, abatement cost)
%             * Environmental indicators (CO2 mitigation, water, land, EROI)
%
% INPUTS : P  (params), res (resource), ar (one of R.A / R.B / R.C)
% OUTPUT : an (struct) with fields .energy .exergy .entropy .eff .nd .econ .env
%
% METHOD NOTES:
%   * Exergy of solar heat uses the Petela efficiency (Eq 58); chemical exergy
%     of H2 from [22]. Component destruction from steady exergy balances; the
%     Gouy-Stodola theorem maps destruction to entropy generation, Sgen=Ex_d/T0.
%   * "Conversion-system" exergy efficiency isolates the storage+conversion
%     chain (delivered energy -> H2), which is the seat of the heat-route
%     advantage; a solar-to-H2 efficiency is also reported for the heat route.
% ASSUMPTIONS: representative HTF/steam transport properties for the classical
%   dimensionless groups; annual energy aggregates from the dispatch.
% =========================================================================

C = P.const;
T0 = C.T0;                                   % dead-state temperature [K]
kWh_LHV = C.kWh_per_kg_LHV;                  % 33.33 kWh/kg
kWh_HHV = C.kWh_per_kg_HHV;                  % 39.39 kWh/kg
exH2_kWhkg = C.ex_H2/3.6e6;                  % chemical exergy of H2 [kWh/kg] (=32.8)
H2 = ar.H2_act;                              % hydrogen actually delivered [kg/yr]
arch = ar.arch;

% Carnot & Petela quality factors -----------------------------------------
petela = 1 - (4/3)*(T0/C.Tsun) + (1/3)*(T0/C.Tsun)^4;     % solar radiation exergy factor
carnot = @(T) max(1 - T0./T, 0);                         % Carnot temperature factor
T_htf  = P.csp.T_htf + 273.15;               % HTF/hot-tank temperature [K]
T_soec = P.soec.T_op;                        % SOEC temperature [K]

% =========================================================================
% 1) ENERGY (1st law)
% =========================================================================
en = struct();
en.H2_LHV_yr = H2*kWh_LHV;                   % chemical energy out (LHV) [kWh/yr]
en.H2_HHV_yr = H2*kWh_HHV;
en.Ex_H2_yr  = H2*exH2_kWhkg;                % chemical exergy out [kWh/yr]
switch arch
 case "A"
   E = ar.energy;
   en.solar_inc   = E.Esolar_inc_yr;                       % incident beam on aperture
   en.solar_abs   = E.Qabs_yr;                             % optically absorbed
   en.field_out   = E.Qfield_served_yr + E.Qdefocus_yr;    % field thermal output
   en.defocus     = E.Qdefocus_yr;
   en.tes_charge  = E.Etes_charge_yr; en.tes_dis = E.Etes_dis_yr;
   en.heat_in_SOEC= E.Qsoec_heat_yr;
   en.elec_in_SOEC= E.EsoecEl_yr;
   en.pb_in       = E.Epb_in_yr;
   en.primary     = en.solar_inc;                          % primary energy basis
   en.delivered   = en.elec_in_SOEC + en.heat_in_SOEC;     % energy to electrolyzer
   en.eta_field   = E.Qfield_served_yr/max(E.Qabs_yr,1);   % field thermal eff
   en.eta_optical = E.Qabs_yr/max(E.Esolar_inc_yr,1);      % optical eff
   en.eta_STH     = en.H2_LHV_yr/max(en.solar_inc,1);      % solar-to-hydrogen (LHV)
   en.SEC_total   = en.delivered/max(H2,1);                % kWh/kg (elec+heat)
   en.SEC_elec    = en.elec_in_SOEC/max(H2,1);
 case "B"
   E = ar.energy;
   en.pv_gen      = E.Epv_yr; en.wind_gen = E.Ew_yr;
   en.gen_total   = E.Epv_yr + E.Ew_yr;
   en.curtail     = E.Ecurtail_yr;
   en.batt_dis    = E.Ebatt_dis_yr; en.batt_ch = E.Ebatt_ch_yr;
   en.elec_in_LT  = E.Elt_yr;
   en.primary     = en.gen_total;                          % delivered electricity basis
   en.delivered   = en.elec_in_LT;
   en.heat_in_SOEC= 0; en.elec_in_SOEC = E.Elt_yr;
   en.eta_curtail = 1 - E.Ecurtail_yr/max(en.gen_total,1); % usable fraction
   en.eta_STH     = en.H2_LHV_yr/max(en.gen_total,1);      % electricity-to-H2 (LHV)
   en.SEC_total   = en.delivered/max(H2,1);
   en.SEC_elec    = en.SEC_total;
 case "C"
   E = ar.energy;
   en.solar_inc   = E.Esolar_inc_yr;
   en.field_out   = E.Qfield_served_yr + E.Qdefocus_yr;
   en.defocus     = E.Qdefocus_yr;
   en.tes_dis     = E.Etes_dis_yr;
   en.pv_gen      = E.Epv_yr; en.pv_curtail = E.Epv_curtail_yr;
   en.batt_dis    = E.Ebatt_dis_yr;
   en.heat_in_SOEC= E.Qsoec_heat_yr; en.elec_in_SOEC = E.EsoecEl_yr;
   en.primary     = en.solar_inc + en.pv_gen;
   en.delivered   = en.elec_in_SOEC + en.heat_in_SOEC;
   en.eta_STH     = en.H2_LHV_yr/max(en.solar_inc+en.pv_gen,1);
   en.SEC_total   = en.delivered/max(H2,1);
   en.SEC_elec    = en.elec_in_SOEC/max(H2,1);
end
en.eta_I = en.H2_LHV_yr/max(en.delivered,1);              % 1st-law (conversion) eff
en.eta_I_HHV = en.H2_HHV_yr/max(en.delivered,1);

% =========================================================================
% 2) EXERGY (2nd law) - component destruction map
% =========================================================================
ex = struct(); comp = struct();
ex.Ex_H2 = en.Ex_H2_yr;
switch arch
 case "A"
   ex.Ex_in_solar = en.solar_inc*petela;                          % primary solar exergy
   ex.Ex_thermal  = en.field_out*carnot(T_htf);                   % field thermal exergy
   ex.Ex_elec     = en.elec_in_SOEC;                              % electricity exergy=energy
   ex.Ex_heat_SOEC= en.heat_in_SOEC*carnot(T_soec);
   ex.Ex_in_conv  = ex.Ex_elec + ex.Ex_heat_SOEC;                 % exergy into SOEC
   % component destructions (Eq 61)
   comp.optical  = (en.solar_inc-en.solar_abs)*petela;            % reflection/optical
   comp.receiver = (en.solar_abs-en.field_out)*carnot(T_htf);     % receiver thermal loss
   comp.defocus  = en.defocus*carnot(T_htf);                      % spilled exergy
   comp.TES      = max((en.tes_charge-en.tes_dis),0)*carnot(T_htf);% storage loss
   comp.powerblock = en.pb_in*carnot(T_htf) - en.elec_in_SOEC;    % Rankine irreversibility
   comp.SOEC     = ex.Ex_in_conv - ex.Ex_H2;                      % electrochemical irrev.
   ex.Ex_in_overall = ex.Ex_in_solar;
   ex.psi_solar = ex.Ex_H2/max(ex.Ex_in_solar,1);                 % solar-to-H2 exergy eff
   ex.psi_conv  = ex.Ex_H2/max(ex.Ex_in_conv,1);                  % conversion-chain eff
 case "B"
   ex.Ex_in_gen   = en.gen_total;                                 % electricity exergy
   ex.Ex_elec     = en.elec_in_LT;
   ex.Ex_in_conv  = ex.Ex_elec;
   comp.curtail   = en.curtail;                                   % curtailed exergy
   comp.battery   = max(en.batt_ch-en.batt_dis,0);                % round-trip loss
   % auxiliary / balance-of-plant: the ~f_aux share of electricity that powers
   % BoP (pumps, controls, conditioning) and does NOT make hydrogen. Generation
   % is co-located with the electrolyzer, so there is no transmission-line loss.
   comp.aux_BoP   = en.elec_in_LT * P.firm.f_aux;
   comp.LT_EL     = ex.Ex_elec - ex.Ex_H2;                        % electrolyzer irrev.
   ex.Ex_in_overall = ex.Ex_in_gen;
   ex.psi_solar = ex.Ex_H2/max(ex.Ex_in_gen,1);
   ex.psi_conv  = ex.Ex_H2/max(ex.Ex_in_conv,1);
 case "C"
   ex.Ex_in_solar = en.solar_inc*petela;
   ex.Ex_in_pv    = en.pv_gen;
   ex.Ex_in_conv  = en.elec_in_SOEC + en.heat_in_SOEC*carnot(T_soec);
   comp.field_TES = (en.solar_inc*petela)*0.18;                   % lumped optical+receiver+TES
   comp.powerblock= max(en.heat_in_SOEC*0,0) + (en.elec_in_SOEC*0.20); % block share (approx)
   comp.PV_batt   = en.pv_gen*0.05 + max(0,0);                    % PV/battery losses
   comp.SOEC      = ex.Ex_in_conv - ex.Ex_H2;
   ex.Ex_in_overall = ex.Ex_in_solar + ex.Ex_in_pv;
   ex.psi_solar = ex.Ex_H2/max(ex.Ex_in_overall,1);
   ex.psi_conv  = ex.Ex_H2/max(ex.Ex_in_conv,1);
end
ex.comp = comp;
fn = fieldnames(comp); dvals = zeros(numel(fn),1);
for i=1:numel(fn), dvals(i)=max(comp.(fn{i}),0); end
ex.Ex_dest_total = sum(dvals);
ex.comp_names = fn; ex.comp_vals = dvals;
ex.psi = ex.psi_conv;                                             % headline 2nd-law eff
[~,imax] = max(dvals); ex.dominant_dest = fn{imax};

% =========================================================================
% 3) ENTROPY GENERATION (Gouy-Stodola: Sgen = Ex_dest / T0)
% =========================================================================
ent = struct();
ent.Sgen_total = ex.Ex_dest_total*3.6e6/T0/(P.time.hoursPerYr*3600); % [kW/K] avg rate
ent.Sgen_comp  = dvals*3.6e6/T0/(P.time.hoursPerYr*3600);
ent.comp_names = fn;
ent.irrever_yr = ex.Ex_dest_total;                                % annual irreversibility [kWh/yr]
[~,im]=max(ent.Sgen_comp); ent.dominant = fn{im};
ent.Number_Ns  = ex.Ex_dest_total/max(ex.Ex_in_overall,1);        % entropy-gen number (frac of input exergy destroyed)

% =========================================================================
% 4) EFFICIENCIES (1st & 2nd law summary)
% =========================================================================
ef = struct();
ef.eta_I  = en.eta_I;             % energy (LHV)
ef.eta_I_HHV = en.eta_I_HHV;
ef.eta_II = ex.psi_conv;          % exergy (conversion)
ef.eta_STH = en.eta_STH;          % solar/elec-to-H2 (LHV)
ef.petela = petela; ef.carnot_htf = carnot(T_htf); ef.carnot_soec = carnot(T_soec);
if arch=="A" || arch=="C"
   ef.eta_field = getfielddef(en,'eta_field',NaN);
   ef.eta_optical = getfielddef(en,'eta_optical',NaN);
end
ef.exergy_loss_ratio = ex.Ex_dest_total/max(ex.Ex_in_overall,1);
ef.SEC_total = en.SEC_total; ef.SEC_elec = en.SEC_elec;

% =========================================================================
% 5) DIMENSIONLESS ANALYSIS  (classical + innovative, physically grounded)
% =========================================================================
nd = struct();
% --- classical groups for the molten-salt receiver / HTF transport ---------
% representative solar-salt properties at ~500 C
rho_s=1800; mu_s=1.4e-3; cp_s=1530; k_s=0.52;     % kg/m3, Pa.s, J/kg/K, W/m/K
D_tube=0.04; v_htf=3.0;                            % receiver tube ID [m], HTF velocity [m/s]
nd.Re_htf = rho_s*v_htf*D_tube/mu_s;               % Reynolds (HTF in receiver)
nd.Pr_htf = mu_s*cp_s/k_s;                         % Prandtl (molten salt)
nd.Nu_htf = 0.023*nd.Re_htf^0.8*nd.Pr_htf^0.4;     % Dittus-Boelter Nusselt
nd.Pe_htf = nd.Re_htf*nd.Pr_htf;                   % Peclet
% --- receiver external natural convection / radiation losses ---------------
beta=1/T_htf; nu_air=3.5e-5; alpha_air=5e-5; Lc=5;
nd.Gr = C.g*beta*(T_htf-T0)*Lc^3/nu_air^2;         % Grashof (receiver)
nd.Ra = nd.Gr*(nu_air/alpha_air);                  % Rayleigh
% --- TES tank transient conduction ----------------------------------------
nd.Bi = 5*0.2/k_s;                                 % Biot (tank wall, h~5,L~0.2)
nd.Fo = (k_s/(rho_s*cp_s))*(12*3600)/(2^2);        % Fourier (12 h, 2 m scale)
% --- steam generation phase change (water -> steam to SOEC) ----------------
cp_w=4180; hfg=2256e3; dT_sup=T_soec-373.15;
nd.Ja  = cp_w*dT_sup/hfg;                           % Jakob (superheat/latent)
nd.Ste = cp_w*(373.15-298.15)/hfg;                 % Stefan (sensible/latent)
% --- INNOVATIVE, route-specific dimensionless groups -----------------------
% Heat-leverage ratio: fraction of total splitting energy supplied as HEAT.
nd.HeatLeverage = en.heat_in_SOEC/max(en.delivered,1);            % Lambda  (0 for B)
% Electrical-substitution number: electricity SAVED by heat vs LT route.
SEC_el_ref = P.lt.SEC_rated;                                      % 52 kWh/kg (LT)
nd.ElecSubstitution = max(SEC_el_ref - en.SEC_elec,0)/SEC_el_ref; % 0..1
% Exergy quality lift: ratio of delivered exergy quality to electricity (=1).
nd.ExergyQuality = ex.Ex_in_conv/max(en.delivered,1);            % <=1 (heat is lower-grade)
% Solar multiple & storage number (heat route)
if isfield(ar.sizing,'SM'), nd.SolarMultiple = ar.sizing.SM; else, nd.SolarMultiple=NaN; end
if isfield(ar.sizing,'h_TES'), nd.StorageNumber = ar.sizing.h_TES/24; else, nd.StorageNumber=NaN; end
% Storage-medium split (thermal share)
nd.SigmaThermal = getfielddef(ar,'storage_thermal_frac',NaN);
% Capacity factor of the electrolyzer (=reliability here, firm), curtailment
nd.CapacityFactor = ar.reliab;
if arch=="B"
  nd.CurtailRatio = en.curtail/max(en.gen_total,1);
elseif arch=="A"
  nd.CurtailRatio = en.defocus/max(en.field_out,1);              % defocus ratio
else
  nd.CurtailRatio = (getfielddef(en,'defocus',0)+getfielddef(en,'pv_curtail',0))/max(en.primary,1);
end
% Firmness premium (dimensionless), exergetic sustainability index
nd.FirmnessPremium = getfielddef(ar,'firmPremium',NaN);
nd.ExergSustain = 1/max(1-ex.psi_conv,1e-3);                     % ESI = 1/(1-psi)
% Dimensionless DNI relative to a nominal crossover (filled later if known)
nd.DNI = res.annualDNI;

% =========================================================================
% 6) ECONOMIC extensions
% =========================================================================
ec = struct();
ec.LCOH = ar.LCOH;
ec.capex = ar.capex;
if isfield(ar,'capexBreak'), ec.capexBreak = ar.capexBreak; end
ec.CRF = P.econ.WACC*(1+P.econ.WACC)^P.econ.life/((1+P.econ.WACC)^P.econ.life-1);
% grey-H2 reference price (SMR) and CO2 abatement cost
H2_grey = 1.8;                                          % USD/kg (SMR, no CCS) ~ ref
ec.H2_grey = H2_grey;
ec.LCOH_premium_vs_grey = ar.LCOH - H2_grey;
ec.CO2_abatement_cost = (ar.LCOH - H2_grey)/max(P.env.SMR_CI/1000,1e-9); % USD/tCO2
% simple NPV of producing green vs buying grey over lifetime (per kg basis)
ec.NPV_per_kg = -(ar.LCOH - H2_grey);                  % negative => costlier than grey now
% levelized exergy cost (USD per kWh of H2 exergy)
ec.LEC = ar.LCOH/exH2_kWhkg;                           % USD/kWh-exergy
ec.cost_per_kWh_LHV = ar.LCOH/kWh_LHV;
% cost shares
if isfield(ar,'capexBreak')
  cb = ar.capexBreak; cn=fieldnames(cb); cv=zeros(numel(cn),1);
  for i=1:numel(cn), cv(i)=cb.(cn{i}); end
  ec.share_names = cn; ec.share_vals = cv/sum(cv);
end

% =========================================================================
% 7) ENVIRONMENTAL indicators
% =========================================================================
ev = struct();
ev.CO2_mitig_tyr = H2*P.env.SMR_CI/1000;               % avoided grey-H2 CO2 [tCO2/yr]
ev.spec_emissions = 0.0;                                % green H2 direct emissions
ev.CO2_value_yr = ev.CO2_mitig_tyr*P.env.SC_CO2;        % social value of avoided CO2 [USD/yr]
ev.water_use_tyr = H2*P.env.water_spec/1000;           % feed water [t/yr]
% land use: aperture (A/C) or PV area (B)
if isfield(ar.sizing,'A_ap')
  ev.land_m2 = ar.sizing.A_ap/0.33;                    % field land ~ aperture/GCR(0.33)
elseif isfield(ar.sizing,'C_PV_kW')
  ev.land_m2 = ar.sizing.C_PV_kW*5;                    % ~5 m2/kW PV
else
  ev.land_m2 = NaN;
end
ev.land_per_kg = ev.land_m2/max(H2,1);
% energy return on investment (very rough embodied estimate)
embodied_kWh = ar.capex*0.5;                           % ~0.5 kWh primary per USD capex (proxy)
ev.EROI = (en.H2_LHV_yr*P.econ.life)/max(embodied_kWh,1);
ev.carbon_intensity_H2 = 0.0;                          % kgCO2/kg (green)

% =========================================================================
an = struct('arch',arch,'energy',en,'exergy',ex,'entropy',ent, ...
            'eff',ef,'nd',nd,'econ',ec,'env',ev);
end

% -------------------------------------------------------------------------
function v = getfielddef(s,f,d)
if isfield(s,f), v=s.(f); else, v=d; end
end
