function TBL = hr_make_tables(P, D)
%HR_MAKE_TABLES  Build publication-grade scientific tables + a figure index,
% and export them to output/HeatRoute_FirmH2_Tables.xlsx (one sheet per table).
% =========================================================================
% PURPOSE : Assemble the quantitative tables that support the study - model
%           parameters, headline results, per-site results, optimal sizing,
%           energy/exergy/entropy balances, 1st/2nd-law efficiencies,
%           dimensionless groups, economics, environment, cost scenarios,
%           uncertainty, validation - plus a complete figure index (name,
%           caption, description, data, interpretation).
%
% INPUT  : P (params), D (master results from HeatRoute_FirmH2_Main / .mat)
% OUTPUT : TBL struct of tables; also writes the Excel workbook.
%
% USAGE  : S=load('output/HeatRoute_FirmH2_Results.mat'); D=S.D;
%          hr_make_tables(D.P, D);
% =========================================================================
xlsx = fullfile(P.io.outdir,'HeatRoute_FirmH2_Tables.xlsx');
if exist(xlsx,'file'), delete(xlsx); end
A = D.arch; nA = numel(A);
names = arrayfun(@(s)string(s.name),A);
kx = exemplarIdxT(D);                      % exemplar site (highest-DNI feasible)
ex = A(kx);
TBL = struct();

%% ---- Table 1: Nomenclature ---------------------------------------------
nom = {
 'Symbol','Description','Units';
 'LCOH','Levelized cost of (firm) hydrogen','USD kg^-1';
 'DLCOH','Cost gap, LCOH_B - LCOH_A','USD kg^-1';
 'DNI','Annual direct normal irradiance','kWh m^-2 yr^-1';
 'DNI*','Break-even (crossover) DNI','kWh m^-2 yr^-1';
 'SM','Solar multiple (field oversize)','-';
 'h_TES','Thermal storage duration','h';
 'A_ap','CSP field aperture area','m^2';
 'N_cells','SOEC stack cell count','-';
 'V_cell','SOEC operating cell voltage','V';
 'V_rev','Reversible (Nernst) voltage','V';
 'V_tn','Thermoneutral voltage','V';
 'i','Current density','A cm^-2';
 'SEC','Specific energy consumption','kWh kg^-1';
 'CF_firm','Firm capacity factor','-';
 'eta_I','First-law (energy) efficiency','-';
 'eta_II / psi','Second-law (exergy) efficiency','-';
 'eta_STH','Solar-to-hydrogen efficiency','-';
 'Lambda','Heat-leverage ratio','-';
 'sigma_th','Storage-medium (thermal) share','-';
 'pi_firm','Firmness premium','-';
 'Ex_dest','Exergy destruction','kWh yr^-1';
 'S_gen','Entropy generation rate','kW K^-1';
 'N_s','Entropy-generation number','-';
 'WACC','Weighted average cost of capital','-';
 'CRF','Capital recovery factor','-';
 'CAPEX','Capital expenditure','USD';
 'Petela','Solar-radiation exergy factor','-'};
TBL.T01_Nomenclature = cell2table(nom(2:end,:),'VariableNames',nom(1,:));

%% ---- Table 2: Key parameters -------------------------------------------
E=P.econ;
par = {
 'Parameter','Value','Units','Source';
 'Firm H2 output (rated)',P.firm.mdot_H2,'kg h^-1','design';
 'Firm capacity factor',P.firm.CF_firm,'-','[20]';
 'SOEC operating temperature',P.soec.T_op,'K','[3,4]';
 'SOEC active cell area',P.soec.A_cell,'cm^2','[4]';
 'SOEC Faradaic efficiency',P.soec.eta_F,'-','[3]';
 'Electrolyte thickness (YSZ)',P.soec.delta_el*1e6,'um','[3]';
 'CSP peak optical efficiency',P.csp.eta_opt0,'-','[11]';
 'HTF / receiver temperature',P.csp.T_htf,'degC','[10,11]';
 'TES charge / discharge eff.',P.tes.eta_ch*100,'% / 98%','[9,10]';
 'Power-block efficiency',P.pb.eta_pb,'-','[7,10]';
 'PV system performance ratio',P.pv.eta_sys,'-','[13]';
 'Battery round-trip efficiency',P.batt.eta_bc*P.batt.eta_bd,'-','[15]';
 'LT electrolyzer SEC (rated)',P.lt.SEC_rated,'kWh kg^-1','[19]';
 'CSP field cost',E.c_field,'USD m^-2','[7]';
 'Power-block cost',E.c_block,'USD kW^-1','[7]';
 'TES cost',E.c_TES,'USD kWh_th^-1','[7,10]';
 'SOEC cost',E.c_SOEC,'USD kW^-1','[3,19]';
 'PV cost',E.c_PV,'USD kW^-1','[15]';
 'Battery energy cost',E.c_battE,'USD kWh^-1','[15]';
 'LT electrolyzer cost',E.c_LT,'USD kW^-1','[19]';
 'WACC (central)',E.WACC,'-','[17,18]';
 'Project lifetime',E.life,'yr','[15,16]'};
TBL.T02_Parameters = cell2table(par(2:end,:),'VariableNames',{'Parameter','Value','Units','Source'});

%% ---- Table 3: Headline results -----------------------------------------
U=D.uncertainty; mt=U.metrics;
g=@(nm) mt(mt.Metric==nm,:);
res = {
 'Result','Value','Uncertainty (P10-P90)','Note';
 'R1 Heat/hybrid dominance share',sprintf('%.1f%%',100*D.result.dominanceShare),'-','cos-lat weighted, feasible land';
 'R2 Break-even DNI*',sprintf('%.0f kWh/m2/yr',D.result.DNIstar),sprintf('%.0f-%.0f',pick(g("Crossover DNI* (kWh/m2/yr)"),'P10'),pick(g("Crossover DNI* (kWh/m2/yr)"),'P90')),'heat route feasible & cheaper';
 'R3 Firmness premium, heat route',sprintf('%+.0f%%',100*mean(arrayfun(@(s)s.R.A.firmPremium,A))),'-','vs annual-average LCOH';
 'R3 Firmness premium, elec route',sprintf('%+.0f%%',100*mean(arrayfun(@(s)s.R.B.firmPremium,A))),'-','reversal vs heat route';
 'R4 Storage-medium split range',sprintf('%.2f - %.2f',min(D.sweep.sigma),max(D.sweep.sigma)),'-','thermal share vs DNI';
 'R5 Pr[heat route wins]',sprintf('%.0f%%',100*mean(D.mc.Pwin)),'-','Monte-Carlo, high-DNI ladder';
 'Cost gap dLCOH (exemplar)',sprintf('%.2f USD/kg',mt.Mean(mt.Metric=="Cost gap dLCOH (USD/kg)")),sprintf('%.2f-%.2f',pick(g("Cost gap dLCOH (USD/kg)"),'P10'),pick(g("Cost gap dLCOH (USD/kg)"),'P90')),'2700 kWh/m2/yr reference'};
TBL.T03_Headline_Results = cell2table(res(2:end,:),'VariableNames',{'Result','Value','Uncertainty','Note'});

%% ---- Table 4: Per-site results -----------------------------------------
lat=arrayfun(@(s)s.res.lat,A); lon=arrayfun(@(k)P.arch(k).lon,1:nA);
DNI=arrayfun(@(s)s.res.annualDNI,A);
LA=arrayfun(@(s)s.R.A.LCOH,A); LB=arrayfun(@(s)s.R.B.LCOH,A); LC=arrayfun(@(s)s.R.C.LCOH,A);
dL=arrayfun(@(s)s.R.dLCOH,A); rA=arrayfun(@(s)s.R.A.reliab,A); rB=arrayfun(@(s)s.R.B.reliab,A);
win=strings(nA,1);
for i=1:nA, if (rA(i)>=P.firm.rel_floor)&&(LA(i)<=LB(i)), win(i)="Heat (A)"; else, win(i)="Electricity (B)"; end; end
TBL.T04_Site_Results = table(names(:),lat(:),lon(:),round(DNI(:)),round2(LA),round2(LB),round2(LC), ...
    round2(dL),round2(rA),round2(rB),win,'VariableNames', ...
    {'Site','Lat_deg','Lon_deg','DNI_kWhm2yr','LCOH_A','LCOH_B','LCOH_C','dLCOH','Reliab_A','Reliab_B','Winner'});

%% ---- Table 5: Optimal sizing (route A & B per site) --------------------
sA=@(f)arrayfun(@(s)s.R.A.sizing.(f),A);
sB=@(f)arrayfun(@(s)s.R.B.sizing.(f),A);
TBL.T05_Sizing_HeatRoute = table(names(:),round2(sA('SM')),round1(sA('h_TES')), ...
    round(sA('A_ap')'),round(sA('N_cells')'),round1(sA('P_SOEC_kW')/1e3), ...
    round(sA('E_TES_kWh')'/1e3),'VariableNames', ...
    {'Site','SolarMultiple','h_TES_h','Aperture_m2','N_cells','P_SOEC_MW','E_TES_MWh'});
TBL.T05b_Sizing_ElecRoute = table(names(:),round1(sB('C_PV_kW')/1e3),round1(sB('C_wind_kW')/1e3), ...
    round1(sB('E_batt_kWh')/1e3),round1(sB('h_batt')),round1(sB('P_LT_kW')/1e3),'VariableNames', ...
    {'Site','PV_MW','Wind_MW','Batt_MWh','h_batt_h','P_LT_MW'});

%% ---- Table 6: Energy & exergy balance (exemplar, per route) ------------
e=@(an,f)an.energy.(f); x=@(an,f)an.exergy.(f);
rowsE={'Primary energy in (GWh/yr)';'Energy to electrolyzer (GWh/yr)';'H2 energy out, LHV (GWh/yr)'; ...
       'Exergy in (GWh/yr)';'Exergy in H2 (GWh/yr)';'Exergy destruction (GWh/yr)'; ...
       'Dominant destruction';'1st-law eff eta_I (-)';'2nd-law eff psi (-)'; ...
       'Solar/elec-to-H2 (-)';'SEC total (kWh/kg)';'Entropy gen (kW/K)';'Entropy-gen number Ns (-)'};
colA=mkbal(ex.anA); colB=mkbal(ex.anB); colC=mkbal(ex.anC);
TBL.T06_Energy_Exergy = table(rowsE,colA,colB,colC,'VariableNames', ...
    {'Quantity_at_exemplar',sprintf('HeatA_%s',clean(ex.name)),'ElecB','HybridC'});
TBL.T06_Energy_Exergy.Properties.Description = char("Exemplar: "+ex.name);

%% ---- Table 7: Efficiency comparison per site --------------------------
e1A=arrayfun(@(s)s.anA.eff.eta_I,A); e2A=arrayfun(@(s)s.anA.eff.eta_II,A);
sthA=arrayfun(@(s)s.anA.eff.eta_STH,A); secA=arrayfun(@(s)s.anA.eff.SEC_total,A);
e1B=arrayfun(@(s)s.anB.eff.eta_I,A); e2B=arrayfun(@(s)s.anB.eff.eta_II,A);
secB=arrayfun(@(s)s.anB.eff.SEC_total,A);
TBL.T07_Efficiency = table(names(:),round2(e1A),round2(e2A),round3(sthA),round1(secA), ...
    round2(e1B),round2(e2B),round1(secB),'VariableNames', ...
    {'Site','etaI_A','etaII_A','etaSTH_A','SEC_A_kWhkg','etaI_B','etaII_B','SEC_B_kWhkg'});

%% ---- Table 8: Dimensionless groups (exemplar) -------------------------
nd=ex.anA.nd;
dim = {
 'Group','Value','Physical meaning';
 'Reynolds Re (HTF)',nd.Re_htf,'Forced-convection regime of molten salt in receiver tubes';
 'Prandtl Pr',nd.Pr_htf,'Momentum-to-thermal diffusivity of the heat-transfer fluid';
 'Nusselt Nu',nd.Nu_htf,'Convective enhancement (Dittus-Boelter)';
 'Peclet Pe',nd.Pe_htf,'Advective-to-diffusive heat transport';
 'Grashof Gr',nd.Gr,'Buoyancy-driven receiver loss tendency';
 'Rayleigh Ra',nd.Ra,'Onset/strength of natural-convection loss';
 'Biot Bi',nd.Bi,'Internal vs surface resistance of the TES tank (thermally thin)';
 'Fourier Fo',nd.Fo,'Dimensionless diurnal conduction time in storage';
 'Jakob Ja',nd.Ja,'Superheat sensible vs latent heat for steam raising';
 'Stefan Ste',nd.Ste,'Sensible vs latent heat in feed preheating';
 'Heat leverage Lambda',nd.HeatLeverage,'Fraction of splitting energy supplied as storable heat';
 'Electrical substitution',nd.ElecSubstitution,'Electricity saved vs the LT route';
 'Exergy quality',nd.ExergyQuality,'Grade of the delivered energy relative to work';
 'Solar multiple SM',nd.SolarMultiple,'Field oversizing for storage charging';
 'Storage number',nd.StorageNumber,'TES hours normalized to a day';
 'Storage-medium share sigma_th',ex.R.C.storage_thermal_frac,'Thermal vs electrical storage split (hybrid)';
 'Capacity factor',nd.CapacityFactor,'Firm-delivery reliability of the electrolyzer';
 'Exergetic sustainability',nd.ExergSustain,'1/(1-psi): robustness of 2nd-law performance'};
TBL.T08_Dimensionless = cell2table(dim(2:end,:),'VariableNames',{'Group','Value','Physical_meaning'});

%% ---- Table 9: Economics (exemplar, per route) -------------------------
RA=ex.R.A; RB=ex.R.B;
H2A=RA.H2_act; H2B=RB.H2_act;
ec = {
 'Metric','Heat route A','Electricity route B','Units';
 'Total CAPEX',RA.capex/1e6,RB.capex/1e6,'million USD';
 'Annualized cost',RA.Cann/1e6,RB.Cann/1e6,'million USD/yr';
 'CRF*CAPEX per kg',RA.Cann_capex/H2A,RB.Cann_capex/H2B,'USD/kg';
 'O&M per kg',RA.opex/H2A,RB.opex/H2B,'USD/kg';
 'Replacement per kg',RA.repl/H2A,RB.repl/H2B,'USD/kg';
 'Water per kg',RA.water/H2A,RB.water/H2B,'USD/kg';
 'Firm LCOH',RA.LCOH,RB.LCOH,'USD/kg';
 'CO2 abatement cost',ex.anA.econ.CO2_abatement_cost,ex.anB.econ.CO2_abatement_cost,'USD/tCO2';
 'Levelized exergy cost',ex.anA.econ.LEC,ex.anB.econ.LEC,'USD/kWh-ex'};
TBL.T09_Economics = cell2table(ec(2:end,:),'VariableNames',{'Metric','HeatRoute_A','ElecRoute_B','Units'});

%% ---- Table 10: Environmental indicators per site ----------------------
co2=arrayfun(@(s)s.anA.env.CO2_mitig_tyr,A); water=arrayfun(@(s)s.anA.env.water_use_tyr,A);
land=arrayfun(@(s)s.anA.env.land_per_kg,A); eroi=arrayfun(@(s)s.anA.env.EROI,A);
TBL.T10_Environmental = table(names(:),round(co2(:)),round1(water'),round3(land),round1(eroi'), ...
    'VariableNames',{'Site','CO2_avoided_tyr','Water_ktyr','Land_m2perkg','EROI'});

%% ---- Table 11: Cost scenarios -----------------------------------------
SC=D.scen;
TBL.T11_Cost_Scenarios = table(names(:), ...
    round2(SC.LCOH_A(:,1)),round2(SC.LCOH_A(:,2)),round2(SC.LCOH_A(:,3)), ...
    round2(SC.LCOH_B(:,1)),round2(SC.LCOH_B(:,2)),round2(SC.LCOH_B(:,3)), ...
    'VariableNames',{'Site','A_2025','A_2030','A_2050','B_2025','B_2030','B_2050'});

%% ---- Table 12 & 13: Uncertainty + Validation (already tables) ---------
TBL.T12_Uncertainty = U.metrics;
TBL.T13_Validation  = D.validation;

%% ---- Figure index ------------------------------------------------------
FIG = hr_make_figures(P, D);             % regenerate to capture caption strings
nF=numel(FIG);
Fnum=strings(nF,1); Fname=strings(nF,1); Fcap=strings(nF,1);
Fdesc=strings(nF,1); Fdata=strings(nF,1); Finterp=strings(nF,1);
for i=1:nF
    f=FIG{i};
    Fnum(i)=sprintf('Figure %d',i); Fname(i)=string(f.name);
    Fcap(i)=string(f.caption); Fdesc(i)=string(f.explanation);
    Finterp(i)=string(f.interpretation);
    if isfield(f,'T')&&~isempty(f.T), Fdata(i)=strjoin(string(f.T.Properties.VariableNames),', ');
    else, Fdata(i)=""; end
end
TBL.Figure_Index = table(Fnum,Fname,Fcap,Fdesc,Fdata,Finterp,'VariableNames', ...
    {'Figure','Name','Caption','Description','Data_columns','Interpretation'});
close all;

%% ---- write all to Excel (one sheet per table) -------------------------
fn=fieldnames(TBL);
for i=1:numel(fn)
    sh=fn{i}; if numel(sh)>31, sh=sh(1:31); end
    writetable(TBL.(fn{i}), xlsx, 'Sheet', sh);
end
fprintf('Wrote %d tables -> %s\n', numel(fn), xlsx);
end

% ----------------------- helpers -----------------------------------------
function v=pick(row,col), v=row.(col); end
function y=round2(x), y=round(x(:),2); end
function y=round1(x), y=round(x(:),1); end
function y=round3(x), y=round(x(:),3); end
function s=clean(str), s=regexprep(char(str),'[^A-Za-z0-9]','_'); if numel(s)>12, s=s(1:12); end, end
function col=mkbal(an)
en=an.energy; ex=an.exergy;
prim=getdef(en,'primary',NaN)/1e6; deliv=en.delivered/1e6; h2=en.H2_LHV_yr/1e6;
exin=getdef(ex,'Ex_in_overall',NaN)/1e6; exh2=ex.Ex_H2/1e6; exd=ex.Ex_dest_total/1e6;
col={sprintf('%.1f',prim);sprintf('%.1f',deliv);sprintf('%.1f',h2);sprintf('%.1f',exin); ...
     sprintf('%.1f',exh2);sprintf('%.1f',exd);char(ex.dominant_dest); ...
     sprintf('%.3f',an.eff.eta_I);sprintf('%.3f',an.exergy.psi_conv);sprintf('%.3f',an.eff.eta_STH); ...
     sprintf('%.1f',an.eff.SEC_total);sprintf('%.1f',an.entropy.Sgen_total);sprintf('%.3f',an.entropy.Number_Ns)};
end
function v=getdef(s,f,d), if isfield(s,f), v=s.(f); else, v=d; end, end
function k=exemplarIdxT(D)
A=D.arch; dni=arrayfun(@(s)s.res.annualDNI,A); feas=arrayfun(@(s)s.R.A.feasible,A);
c=find(feas); if isempty(c), [~,k]=max(dni); else, [~,j]=max(dni(c)); k=c(j); end
end
