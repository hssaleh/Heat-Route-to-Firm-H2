function R = hr_solve_cell(P, res, WACC, costMult, opt)
%HR_SOLVE_CELL  Least-cost firm-hydrogen design for one grid cell, 3 routes.
% =========================================================================
% PURPOSE : For a single location (resource struct res), size and dispatch
%           each architecture to deliver FIRM hydrogen at minimum levelized
%           cost (LCOH), implementing the governing equations of Sections
%           3-9 of the model document. Returns rich per-architecture results
%           (sizing, hourly flows, energy balances, economics).
%
%   A - heat route        : CSP field + molten-salt TES + Rankine block + SOEC
%   B - electricity route : PV(+wind) + Li-ion battery + LT (PEM/alkaline) EL
%   C - hybrid frontier   : f_th sweep splitting overnight energy between the
%                           thermal (TES) and electrical (battery) media; the
%                           cost-optimal split is the "storage-medium split".
%
% DESIGN BASIS (firmness): firm output => electrolyzer runs at a CONSTANT
%   hydrogen rate every hour (Eq 44-45). This fixes its electrical and (for
%   SOEC) thermal demand as constant 24/7 loads, which the supply chain + TES
%   /battery must meet on every representative-day hour. Two reusable least-
%   cost "supply sizers" are composed into the three architectures.
%
% INPUTS :
%   P        - parameters (hr_config)
%   res      - resource struct (hr_resource), [24x12] hourly typical-day fields
%   WACC     - weighted average cost of capital for this cell [-]
%   costMult - 1x7 capital-cost multipliers [c_CSP c_TES c_SOEC c_PV c_wind c_battE c_LT]
%   opt      - (struct) options: .wantHourly (keep profiles), .doC (solve hybrid),
%              .i_soec (override current density), .allowWind
%
% OUTPUT : R struct with fields .A .B .C (each a route result) and .res
%
% ASSUMPTIONS / NOTES:
%   * Representative-day dispatch (12 monthly days, hourly), periodic diurnal
%     storage; the binding (worst) day sizes the plant -> guarantees firmness.
%   * SOEC current density fixed at opt.i_soec for sizing (swept separately
%     for V-i / efficiency figures).
% =========================================================================

if nargin<4 || isempty(costMult), costMult = ones(1,7); end
if nargin<5, opt = struct(); end
if ~isfield(opt,'wantHourly'), opt.wantHourly=false; end
if ~isfield(opt,'doC'),        opt.doC=true;          end
if ~isfield(opt,'i_soec'),     opt.i_soec=0.40;       end
if ~isfield(opt,'allowWind'),  opt.allowWind=(res.lat~=0); end

cst = scaleCosts(P.econ, costMult);          % apply scenario/MC multipliers
mdot_firm_kgph = P.firm.CF_firm*P.firm.mdot_H2;     % constant firm H2 [kg/h]
mdot_firm_kgs  = mdot_firm_kgph/3600;               % [kg/s]
H2_kg_yr       = mdot_firm_kgph*P.time.hoursPerYr;  % annual firm H2 [kg/yr]

% ---- SOEC operating point (per-cell electrochemistry, Eqs 23-37) ----------
sp = soecPoint(P, opt.i_soec);
N_cells   = mdot_firm_kgs/sp.mdotH2_cell;            % stack scale to hit firm H2
P_SOEC_kW = sp.Pcell*N_cells/1000;                  % constant SOEC power [kW]
Q_heat_kW = sp.Qcell*N_cells/1000;                  % constant SOEC heat demand [kW_th]
P_aux_S   = P.firm.f_aux*P_SOEC_kW;                  % BoP/auxiliary [kW]
L_el_S    = P_SOEC_kW + P_aux_S;                     % firm electrical load (SOEC route) [kW]

% ---- LT electrolyzer operating point (Eqs 40-43) --------------------------
P_LT_kW   = mdot_firm_kgph*P.lt.SEC_rated;           % rated, load=1 [kW]
P_aux_L   = P.firm.f_aux*P_LT_kW;
L_el_B    = P_LT_kW + P_aux_L;                       % firm electrical load (LT route) [kW]

% ---- annualized electrolyzer-side costs (passed to sizers for true LCOH) ---
crfL = crf(WACC,P.econ.life);
capex_soec = cst.c_SOEC*P_SOEC_kW;
Cann_soec  = crfL*capex_soec + P.econ.opex_fix*capex_soec + replCost(P,WACC,cst,P_SOEC_kW);
capex_lt   = cst.c_LT*P_LT_kW;
Cann_lt    = crfL*capex_lt + P.econ.opex_fix*capex_lt;

% =========================================================================
% ARCHITECTURE A : pure heat route
%   All SOEC electricity via the Rankine block; CSP/TES supplies all heat.
% =========================================================================
ths = sizeThermalSupply(P,res,WACC,cst, Q_heat_kW, L_el_S, opt, Cann_soec, H2_kg_yr);
A = assembleHeat(P,cst,WACC,ths,P_SOEC_kW,Q_heat_kW,N_cells,sp,H2_kg_yr,L_el_S,opt);
A.arch = "A"; A.label = "Heat route (CSP+TES+SOEC)";

% =========================================================================
% ARCHITECTURE B : pure electricity route
% =========================================================================
els = sizeElecSupply(P,res,WACC,cst, L_el_B, opt.allowWind, opt, Cann_lt, H2_kg_yr);
B = assembleElec(P,cst,WACC,els,P_LT_kW,H2_kg_yr,L_el_B,opt);
B.arch = "B"; B.label = "Electricity route (PV/Wind+Batt+LT-EL)";

% =========================================================================
% ARCHITECTURE C : hybrid storage-medium split (f_th sweep)
%   Overnight SOEC electricity split f_th via thermal path (CSP block+TES)
%   and (1-f_th) via electrical path (PV+battery). Heat always thermal.
% =========================================================================
C = struct('arch',"C",'label',"Hybrid (PV+CSP/TES+SOEC)");
if opt.doC
    C = sizeHybrid(P,res,WACC,cst, L_el_S, Q_heat_kW, P_SOEC_kW, N_cells, sp, H2_kg_yr, opt);
    C.arch="C"; C.label="Hybrid (PV+CSP/TES+SOEC)";
end

% ---- firmness premium (Section 3.1): firm LCOH over conventional ANNUAL-
%   AVERAGE LCOH, where the annual-average design lets the electrolyzer follow
%   the resource with NO storage (the prevailing literature convention).
A.LCOH_avg = nonFirmFollow(P,res,WACC,cst,'A',Q_heat_kW,L_el_S,P_SOEC_kW,Cann_soec,mdot_firm_kgph);
B.LCOH_avg = nonFirmFollow(P,res,WACC,cst,'B',0,L_el_B,P_LT_kW,Cann_lt,mdot_firm_kgph);
A.firmPremium = (A.LCOH - A.LCOH_avg)/A.LCOH_avg;
B.firmPremium = (B.LCOH - B.LCOH_avg)/B.LCOH_avg;

R = struct('A',A,'B',B,'C',C,'res',res,'WACC',WACC, ...
           'H2_kg_yr',H2_kg_yr,'mdot_firm_kgph',mdot_firm_kgph, ...
           'dLCOH', B.LCOH - A.LCOH);          % Eq 67 (heat route vs electricity)
end
% =========================================================================
% ====================== LOCAL FUNCTIONS ==================================
% =========================================================================

function cst = scaleCosts(E, m)
% Apply multipliers [c_CSP c_TES c_SOEC c_PV c_wind c_battE c_LT].
cst = E;
cst.c_field = E.c_field*m(1);   cst.c_block = E.c_block*m(1);
cst.c_CSP   = E.c_CSP  *m(1);   cst.c_TES   = E.c_TES  *m(2);
cst.c_SOEC  = E.c_SOEC *m(3);   cst.c_PV    = E.c_PV   *m(4);
cst.c_wind  = E.c_wind *m(5);   cst.c_battE = E.c_battE*m(6);
cst.c_battP = E.c_battP*m(6);   cst.c_LT    = E.c_LT   *m(7);
end

% -------------------------------------------------------------------------
function sp = soecPoint(P, i_Acm2)
% SOEC cell operating point at current density i [A/cm^2]. Eqs 23-37.
C=P.const; S=P.soec; T=S.T_op;
% Steam-electrolysis thermodynamics (T-dependent dG,dH for H2O(g) splitting)
dH_T = 248.0e3;                         % J/mol  (-> V_tn ~1.285 V at 1073 K)
dS_T = 60.0;                            % J/mol/K
dG_T = dH_T - T*dS_T;                   % Gibbs energy at T
% Eq 23: reversible (Nernst) voltage
Vrev = dG_T/(C.z*C.F) + (C.Rgas*T/(C.z*C.F))*log(S.p_H2*sqrt(S.p_O2)/S.p_H2O);
% Eq 32: thermoneutral voltage
Vtn  = dH_T/(C.z*C.F);
% Eq 24-25: activation overpotentials (Butler-Volmer, asinh form)
i_Am2 = i_Acm2*1e4;                     % A/cm^2 -> A/m^2
i0_an = S.gamma_an *exp(-S.Eact_an /(C.Rgas*T));
i0_cat= S.gamma_cat*exp(-S.Eact_cat/(C.Rgas*T));
eta_an = (C.Rgas*T/(S.alpha_an *C.z*C.F))*asinh(i_Am2/(2*i0_an));
eta_cat= (C.Rgas*T/(S.alpha_cat*C.z*C.F))*asinh(i_Am2/(2*i0_cat));
% Eq 26-27: ohmic (electrolyte conduction) + lumped contact/electrode ASR
sigma  = S.sigma0*exp(-S.Esigma/(C.Rgas*T));      % S/m
ASR_el = S.delta_el/sigma;                        % Ohm*m^2
ASR_contact = 0.22e-4;                            % Ohm*m^2 (~0.22 Ohm*cm^2 electrodes/IC)
ASR_tot = ASR_el + ASR_contact;                   % Ohm*m^2
eta_ohm = i_Am2*ASR_tot;                          % V  (=i[A/m2]*ASR[Ohm m2])
% Eq 28: concentration overpotential (utilization-based partial-pressure shift)
U = S.util;
eta_conc = (C.Rgas*T/(C.z*C.F))*( log(1/(1-U)) + 0.5*log(1/(1-U)) );
% Eq 29: cell voltage
Vcell = Vrev + eta_an + eta_cat + eta_ohm + eta_conc;
% Per-cell electrical & H2 (Eqs 30-31)
Icell = i_Acm2*S.A_cell;                          % A  (A_cell in cm^2)
mdotH2_cell = S.eta_F*Icell/(C.z*C.F)*C.M_H2;     % kg/s
Pcell = Vcell*Icell;                              % W
% Heat demand (Eqs 33-35): reaction (endothermic below Vtn) + steam raising
Q_rxn  = max(0, Icell*(Vtn - Vcell));             % W
mdotH2O_cell = mdotH2_cell*(C.M_H2O/C.M_H2);      % kg/s water
Q_steam = mdotH2O_cell*1000*( S.cp_liq*(S.T_boil-S.T_feed) ...
            + S.dh_vap + S.cp_vap*(T-273.15-S.T_boil) );  % W (cp in kJ/kg/K, mdot kg/s ->*1000)
Q_heat_cell = Q_rxn + Q_steam*(1-S.eta_rec);      % W (recover part of steam heat)
% Efficiencies
SEC_el_kWhkg  = (Pcell/mdotH2_cell)/3.6e6;        % electrical specific energy [kWh/kg]
SEC_tot_kWhkg = ((Pcell+Q_heat_cell)/mdotH2_cell)/3.6e6;
sp = struct('Vrev',Vrev,'Vtn',Vtn,'eta_act',eta_an+eta_cat,'eta_an',eta_an, ...
    'eta_cat',eta_cat,'eta_ohm',eta_ohm,'eta_conc',eta_conc,'Vcell',Vcell, ...
    'i',i_Acm2,'Icell',Icell,'Pcell',Pcell,'Qcell',Q_heat_cell, ...
    'Qrxn_cell',Q_rxn,'Qsteam_cell',Q_steam*(1-S.eta_rec), ...
    'mdotH2_cell',mdotH2_cell,'ASR',ASR_tot*1e4, ...
    'SEC_el',SEC_el_kWhkg,'SEC_tot',SEC_tot_kWhkg, ...
    'eta_el',Vtn/Vcell,'eta_LHV',(P.const.kWh_per_kg_LHV)/SEC_tot_kWhkg);
end

% -------------------------------------------------------------------------
function Q = cspField(P,res,A_ap)
% CSP field thermal output [kW_th], [24x12]. Eqs 13-15.
Qabs = res.Gb.*A_ap.*P.csp.eta_opt0.*res.IAM.*P.csp.f_avail.*P.csp.f_clean; % W
A_rec = P.csp.Arec_per_Aap*A_ap;
dT = (P.csp.T_htf - res.Tamb);
Qloss = A_rec.*( P.csp.a0 + P.csp.a1.*dT + P.csp.a2.*dT.^2 );               % W
Q = max(0, Qabs - Qloss)/1000;                                             % kW_th
end

function Qabs = cspAbsorbed(P,res,A_ap)
Qabs = res.Gb.*A_ap.*P.csp.eta_opt0.*res.IAM.*P.csp.f_avail.*P.csp.f_clean/1000; % kW
end

% -------------------------------------------------------------------------
function Pkw = pvPower(P,res,Cpv)
% PV power [kW], [24x12]. Eqs 7-8.
Tcell = res.Tamb + (P.pv.NOCT-20)/800.*res.G;
Pkw = Cpv.*(res.G./P.pv.Gstc).*(1 - P.pv.gamma.*(Tcell-P.pv.Tref)).*P.pv.eta_sys;
Pkw = max(Pkw,0);
end

function Pkw = windPower(P,res,Cw)
% Wind power [kW], [24x12]. Eqs 9-11.
v=res.v; rho=res.rho;
Pkw = zeros(size(v));
reg2 = v>=P.wind.v_in & v<P.wind.v_r;
reg3 = v>=P.wind.v_r & v<=P.wind.v_out;
Pkw(reg2) = Cw.*(rho(reg2)/P.wind.rho0).*(v(reg2).^3 - P.wind.v_in^3)/(P.wind.v_r^3 - P.wind.v_in^3);
Pkw(reg3) = Cw;
Pkw = max(min(Pkw,Cw),0);
end

% -------------------------------------------------------------------------
function D = dispatchStore(gen, load, Emax, etac, etad, phi_sb)
% Periodic diurnal storage dispatch. gen,load:[24x12] kW; Emax kWh (scalar);
% etac/etad round-trip split; phi_sb standby loss [%/h]. Direct gen->load is
% lossless; surplus charges, deficit discharges. Returns annualised aggregates.
[nH,nM]=size(gen); dt=1;
soc = 0.5*Emax*ones(1,nM);
unmet=zeros(nH,nM); spill=zeros(nH,nM); dischg=zeros(nH,nM); chg=zeros(nH,nM);
direct=zeros(nH,nM); socTrace=zeros(nH,nM);
for pass=1:2                                   % settle periodic initial SOC
  unmet(:)=0; spill(:)=0; dischg(:)=0; chg(:)=0; direct(:)=0;
  for h=1:nH
    g=gen(h,:); L=load(h,:);
    d=min(g,L); direct(h,:)=d;                 % direct service (lossless)
    surplus=g-d; resid=L-d;
    % charge
    canStore=max(Emax-soc,0);
    into=min(surplus, canStore./etac);
    soc=soc+into.*etac; chg(h,:)=into;
    spill(h,:)=surplus-into;
    % discharge to residual load
    avail=soc.*etad;
    out=min(resid, avail);
    soc=soc-out./etad; dischg(h,:)=out;
    unmet(h,:)=resid-out;
    % standby loss
    soc=soc.*(1-phi_sb/100);
    socTrace(h,:)=soc;
  end
end
wm = ones(nH,1)*reshapeMonthW(gen);            % month-day weights broadcast
ann=@(X) sum(sum(X.*wm));                       % kWh/yr (kW * h * days)
D=struct();
D.unmet_kWh   = ann(unmet);
D.spill_kWh   = ann(spill);
D.charge_kWh  = ann(chg);
D.discharge_kWh=ann(dischg);
D.direct_kWh  = ann(direct);
D.served_kWh  = ann(direct+dischg);
D.load_kWh    = ann(load);
D.socTrace    = socTrace;
D.Emax        = Emax;
D.feasible    = D.unmet_kWh < 1e-3*max(D.load_kWh,1);
% hourly fields [24x12] for chaining (e.g. hybrid two-storage dispatch)
D.unmet_h = unmet; D.discharge_h = dischg; D.direct_h = direct; D.charge_h = chg; D.spill_h = spill;
end

function wm = reshapeMonthW(~)
% Helper returns the month-day weight row vector (days per month) for annualising.
md=[31 28 31 30 31 30 31 31 30 31 30 31];
wm = md;   % 1x12
end

% -------------------------------------------------------------------------
function S = sizeThermalSupply(P,res,WACC,cst, Qheat_kW, Eel_kW, opt, Cann_el, H2firm)
% Least-cost CSP field + TES (+ Rankine block) to deliver constant heat Qheat
% and constant electricity Eel (via block). Minimises full LCOH directly and
% returns BOTH the firm optimum (reliability >= floor) and the unconstrained
% annual-average optimum (the firmness-premium baseline). Decision: SM, h_TES.
if nargin<8, Cann_el=0; end
if nargin<9, H2firm=1; end
[nG,nR]=optRes(P,opt);
eta_pb_net = P.pb.eta_pb*(1-P.pb.f_par);
Qpb_in = Eel_kW/max(eta_pb_net,1e-6);            % thermal for the block [kW_th]
Lth = Qheat_kW + Qpb_in;                          % total constant thermal load [kW_th]
SMg = linspace(P.csp.SM_bounds(1),P.csp.SM_bounds(2),nG);
hTg = linspace(P.tes.hTES_bounds(1),P.tes.hTES_bounds(2),nG);
crfL = crf(WACC,P.econ.life);
best.LCOH=inf; bestNF.LCOH=inf;
for refine=1:2
 for SM=SMg
  A_ap = SM*Lth*1000/(cst.Gb_design*P.csp.eta_opt0*P.csp.f_avail*P.csp.f_clean); % m^2
  Qfield = cspField(P,res,A_ap);
  for hT=hTg
    Emax = hT*Lth;                                % kWh_th
    D = dispatchStore(Qfield, Lth*ones(size(Qfield)), Emax, ...
                      P.tes.eta_ch, P.tes.eta_dis, P.tes.phi_sb);
    reli  = D.served_kWh/max(D.load_kWh,1e-9);     % firm-delivery reliability
    capex = cst.c_field*A_ap + cst.c_block*Eel_kW + cst.c_TES*Emax;
    Cann  = crfL*capex + P.econ.opex_fix*capex;
    H2act = H2firm*reli;
    LCOH  = (Cann + Cann_el)/max(H2act,1) + P.econ.c_water;
    if LCOH < bestNF.LCOH                          % unconstrained (annual-average)
      bestNF.LCOH=LCOH; bestNF.reliab=reli;
    end
    if reli>=P.firm.rel_floor && LCOH < best.LCOH  % firm optimum
      best.LCOH=LCOH; best.SM=SM; best.hT=hT; best.A_ap=A_ap; best.Emax=Emax;
      best.capex=capex; best.Cann=Cann; best.D=D; best.Lth=Lth; best.Qpb_in=Qpb_in;
      best.Qfield=Qfield; best.reliab=reli; best.feasible=true;
    end
  end
 end
 dSM=(P.csp.SM_bounds(2)-P.csp.SM_bounds(1))/nG;
 dhT=(P.tes.hTES_bounds(2)-P.tes.hTES_bounds(1))/nG;
 if ~isfield(best,'SM')   % no firm-feasible design found: take max-reliability point
    [best,bestNF] = thermalFallback(P,res,WACC,cst,Lth,Qheat_kW,Eel_kW,Cann_el,H2firm,crfL);
    break;
 end
 SMg=linspace(max(P.csp.SM_bounds(1),best.SM-dSM),min(P.csp.SM_bounds(2),best.SM+dSM),nR);
 hTg=linspace(max(P.tes.hTES_bounds(1),best.hT-dhT),min(P.tes.hTES_bounds(2),best.hT+dhT),nR);
end
S=best; S.Qheat_kW=Qheat_kW; S.Eel_kW=Eel_kW; S.LCOH_nonfirm=bestNF.LCOH;
wmY = ones(24,1)*reshapeMonthW(res.Gb);                       % [24x12] day weights
S.Esolar_inc_yr = sum(sum( (res.Gb.*S.A_ap/1000) .* wmY ));   % incident beam on aperture [kWh/yr]
S.Qabs_yr       = sum(sum( cspAbsorbed(P,res,S.A_ap) .* wmY ));% optically absorbed [kWh/yr]
end

% -------------------------------------------------------------------------
function [best,bestNF] = thermalFallback(P,res,WACC,cst,Lth,Qheat_kW,Eel_kW,Cann_el,H2firm,crfL)
% Max-reliability CSP/TES design when the firm floor is unreachable (low DNI).
SM=P.csp.SM_bounds(2); hT=P.tes.hTES_bounds(2);
A_ap = SM*Lth*1000/(cst.Gb_design*P.csp.eta_opt0*P.csp.f_avail*P.csp.f_clean);
Qfield=cspField(P,res,A_ap); Emax=hT*Lth;
D=dispatchStore(Qfield, Lth*ones(size(Qfield)), Emax, P.tes.eta_ch,P.tes.eta_dis,P.tes.phi_sb);
reli=D.served_kWh/max(D.load_kWh,1e-9);
capex=cst.c_field*A_ap+cst.c_block*Eel_kW+cst.c_TES*Emax;
Cann=crfL*capex+P.econ.opex_fix*capex;
LCOH=(Cann+Cann_el)/max(H2firm*reli,1)+P.econ.c_water;
best=struct('LCOH',LCOH,'SM',SM,'hT',hT,'A_ap',A_ap,'Emax',Emax,'capex',capex, ...
   'Cann',Cann,'D',D,'Lth',Lth,'Qpb_in',Lth-Qheat_kW,'Qfield',Qfield,'reliab',reli,'feasible',false);
bestNF=struct('LCOH',LCOH,'reliab',reli);
end

% -------------------------------------------------------------------------
function S = sizeElecSupply(P,res,WACC,cst, Lel_kW, allowWind, opt, Cann_el, H2firm)
% Least-cost PV(+wind)+battery to deliver constant electricity Lel. Minimises
% full LCOH directly; returns firm and annual-average (non-firm) optima.
% Decision: PV multiple (relative to load), wind share, battery hours.
if nargin<8, Cann_el=0; end
if nargin<9, H2firm=1; end
[nG,nR]=optRes(P,opt);
PVmult = linspace(1.5,6.5,nG);          % PV nameplate / load ratio
hBg    = linspace(P.batt.hrs_bounds(1),P.batt.hrs_bounds(2),nG);
windFrac = 0; if allowWind, windFrac = 0.35; end  % modest wind blend if available
crfL = crf(WACC,P.econ.life);
best.LCOH=inf; bestNF.LCOH=inf;
for refine=1:2
 for pm=PVmult
   Cpv = pm*Lel_kW;
   Ppv = pvPower(P,res,Cpv);
   if windFrac>0
     Cw = windFrac*pm*Lel_kW; Pw = windPower(P,res,Cw);
   else
     Cw = 0; Pw = zeros(size(Ppv));
   end
   gen = Ppv+Pw;
   for hB=hBg
     Emax=hB*Lel_kW; Pbatt=Lel_kW;               % battery power ~ load
     D=dispatchStore(gen, Lel_kW*ones(size(gen)), Emax, ...
                     P.batt.eta_bc, P.batt.eta_bd, 0.0);
     reli  = D.served_kWh/max(D.load_kWh,1e-9);
     capex = cst.c_PV*Cpv + cst.c_wind*Cw + cst.c_battE*Emax + cst.c_battP*Pbatt;
     Cann  = crfL*capex + P.econ.opex_fix*capex;
     LCOH  = (Cann+Cann_el)/max(H2firm*reli,1) + P.econ.c_water;
     if LCOH < bestNF.LCOH, bestNF.LCOH=LCOH; bestNF.reliab=reli; end
     if reli>=P.firm.rel_floor && LCOH<best.LCOH
       best.LCOH=LCOH; best.PVmult=pm; best.Cpv=Cpv; best.Cw=Cw; best.hB=hB;
       best.Emax=Emax; best.Pbatt=Pbatt; best.capex=capex; best.Cann=Cann;
       best.D=D; best.gen=gen; best.Ppv=Ppv; best.Pw=Pw; best.reliab=reli; best.feasible=true;
     end
   end
 end
 dpm=(6.5-1.5)/nG; dhB=(P.batt.hrs_bounds(2)-P.batt.hrs_bounds(1))/nG;
 if ~isfield(best,'PVmult')   % no firm design: max-oversize fallback
    [best,bestNF]=elecFallback(P,res,WACC,cst,Lel_kW,windFrac,Cann_el,H2firm,crfL);
    break;
 end
 PVmult=linspace(max(1.2,best.PVmult-dpm),min(9,best.PVmult+dpm),nR);
 hBg=linspace(max(P.batt.hrs_bounds(1),best.hB-dhB),min(P.batt.hrs_bounds(2),best.hB+dhB),nR);
end
S=best; S.Lel_kW=Lel_kW; S.LCOH_nonfirm=bestNF.LCOH;
S.Epv_yr = sum(sum(S.Ppv.*(ones(24,1)*reshapeMonthW(res.Gb))));
S.Ew_yr  = sum(sum(S.Pw .*(ones(24,1)*reshapeMonthW(res.Gb))));
end

% -------------------------------------------------------------------------
function [best,bestNF]=elecFallback(P,res,WACC,cst,Lel_kW,windFrac,Cann_el,H2firm,crfL)
% Max-oversize PV(+wind)+battery when the firm floor is unreachable.
pm=9; hB=P.batt.hrs_bounds(2);
Cpv=pm*Lel_kW; Ppv=pvPower(P,res,Cpv);
if windFrac>0, Cw=windFrac*pm*Lel_kW; Pw=windPower(P,res,Cw); else, Cw=0; Pw=zeros(size(Ppv)); end
gen=Ppv+Pw; Emax=hB*Lel_kW; Pbatt=Lel_kW;
D=dispatchStore(gen, Lel_kW*ones(size(gen)), Emax, P.batt.eta_bc,P.batt.eta_bd,0.0);
reli=D.served_kWh/max(D.load_kWh,1e-9);
capex=cst.c_PV*Cpv+cst.c_wind*Cw+cst.c_battE*Emax+cst.c_battP*Pbatt;
Cann=crfL*capex+P.econ.opex_fix*capex;
LCOH=(Cann+Cann_el)/max(H2firm*reli,1)+P.econ.c_water;
best=struct('LCOH',LCOH,'PVmult',pm,'Cpv',Cpv,'Cw',Cw,'hB',hB,'Emax',Emax,'Pbatt',Pbatt, ...
   'capex',capex,'Cann',Cann,'D',D,'gen',gen,'Ppv',Ppv,'Pw',Pw,'reliab',reli,'feasible',false);
bestNF=struct('LCOH',LCOH,'reliab',reli);
end

function S = zeroElec()
S=struct('Cann',0,'capex',0,'Cpv',0,'Cw',0,'Emax',0,'Pbatt',0,'PVmult',0,'hB',0, ...
    'Epv_yr',0,'Ew_yr',0,'Lel_kW',0,'feasible',true,'pen',0,'reliab',1, ...
    'D',struct('served_kWh',0,'spill_kWh',0,'charge_kWh',0,'discharge_kWh',0,'load_kWh',0,'direct_kWh',0,'unmet_kWh',0,'socTrace',zeros(24,12),'Emax',0));
end

% -------------------------------------------------------------------------
function C = sizeHybrid(P,res,WACC,cst, L_el, Q_heat, P_SOEC_kW, N_cells, sp, H2_kg_yr, opt)
% Co-optimised hybrid (Architecture C). PV directly powers the SOEC by day;
% a battery shifts some PV into the evening (ELECTRICAL storage path); CSP +
% molten-salt TES supply all process heat plus the residual electricity via
% the Rankine block (THERMAL storage path). The cost-optimal mix of the two
% storage media is the "storage-medium split" (sigma_th). Decisions:
%   PV capacity, battery hours, solar multiple, TES hours.
eta_pb_net = P.pb.eta_pb*(1-P.pb.f_par);
nG = 5; if isfield(opt,'nGrid')&&~isempty(opt.nGrid), nG=max(opt.nGrid-2,7); end
PVg  = linspace(0, 3.0, nG)*L_el;                 % PV nameplate [kW]
hBg  = [0 2 4 6 8];                               % battery hours
SMg  = linspace(P.csp.SM_bounds(1),P.csp.SM_bounds(2),nG);
hTg  = linspace(P.tes.hTES_bounds(1),P.tes.hTES_bounds(2),max(nG,9)); % finer TES grid (smooth frontier)
wmY  = ones(24,1)*reshapeMonthW(res.Gb);
crfL = crf(WACC,P.econ.life);
capex_soec = cst.c_SOEC*P_SOEC_kW;
ann_soec   = crfL*capex_soec + P.econ.opex_fix*capex_soec + replCost(P,WACC,cst,P_SOEC_kW);
best.cost=inf;
Lel_mat = L_el*ones(24,12);
for Cpv = PVg
  PV = pvPower(P,res,Cpv);
  for hB = hBg
    % electrical path: PV -> SOEC direct, surplus -> battery -> evening
    Ebatt = hB*L_el;
    if Ebatt>0
      Del = dispatchStore(PV, Lel_mat, Ebatt, P.batt.eta_bc, P.batt.eta_bd, 0.0);
      resid_el = Del.unmet_h;                      % electricity still needed [24x12]
      batt_dis = Del.discharge_kWh; pv_curtail = Del.spill_kWh;
    else
      resid_el = max(L_el - PV,0); batt_dis = 0;
      pv_curtail = sum(sum(max(PV-L_el,0).*wmY));
      Del = struct('discharge_kWh',0,'spill_kWh',pv_curtail,'socTrace',zeros(24,12),'charge_kWh',0,'direct_kWh',sum(sum(min(PV,L_el).*wmY)));
    end
    % thermal path: CSP block must cover residual electricity + all heat
    Qpb_in_h = resid_el/eta_pb_net;                % thermal for block [24x12]
    Lth_h = Q_heat + Qpb_in_h;                     % time-varying thermal load
    Eel_block = max(resid_el(:));                  % block power rating (peak residual)
    for SM = SMg
      Lth_design = Q_heat + (max(resid_el(:)))/eta_pb_net + 1e-9;
      A_ap = SM*Lth_design*1000/(cst.Gb_design*P.csp.eta_opt0*P.csp.f_avail*P.csp.f_clean);
      Qfield = cspField(P,res,A_ap);
      for hT = hTg
        Emax = hT*mean(Lth_h(:));
        Dth = dispatchStore(Qfield, Lth_h, Emax, P.tes.eta_ch, P.tes.eta_dis, P.tes.phi_sb);
        reli = Dth.served_kWh/max(Dth.load_kWh,1e-9);
        capex = cst.c_field*A_ap + cst.c_block*Eel_block + cst.c_TES*Emax ...
              + cst.c_PV*Cpv + cst.c_battE*Ebatt + cst.c_battP*(L_el*(hB>0)) + capex_soec;
        Cann = crfL*capex + P.econ.opex_fix*capex + replCost(P,WACC,cst,P_SOEC_kW) ...
             + P.econ.c_water*H2_kg_yr*reli;
        LCOH = Cann/max(H2_kg_yr*reli,1);
        % regularize: among near-tied LCOH designs prefer the SMALLEST system
        % (lowest SM, TES, PV, battery) -> a unique, smooth optimum vs DNI.
        % Small coefficient: only breaks genuine ties, never overrides a real
        % cost difference (so PV is dropped only when it is truly not economic).
        reg = 0.006*(SM/P.csp.SM_bounds(2) + hT/P.tes.hTES_bounds(2) ...
                  + Cpv/max(3*L_el,1) + hB/8);
        if reli>=P.firm.rel_floor, score = LCOH + reg; else, score = 1e6 + (P.firm.rel_floor-reli)*1e6; end
        if score < best.cost
          best.cost=score; best.Cpv=Cpv; best.hB=hB; best.SM=SM; best.hT=hT;
          best.A_ap=A_ap; best.Emax=Emax; best.Ebatt=Ebatt; best.Eel_block=Eel_block;
          best.capex=capex; best.Cann=Cann; best.Dth=Dth; best.Del=Del; best.reliab=reli;
          best.PV=PV; best.Qfield=Qfield; best.Lth_h=Lth_h; best.batt_dis=batt_dis;
          best.feasible=(reli>=P.firm.rel_floor);
        end
      end
    end
  end
end
b=best;
H2_act = H2_kg_yr*b.reliab;
C.LCOH = b.Cann/H2_act; C.Cann=b.Cann; C.capex=b.capex; C.feasible=b.feasible;
C.reliab=b.reliab; C.H2_act=H2_act;
% storage-medium split (Section 3.2): thermal-PATH vs electrical-PATH share of
% the total energy delivered to the SOEC. Thermal path = process heat + Rankine-
% block electricity (from CSP field/TES). Electrical path = PV-direct + battery.
yr=P.time.hoursPerYr;
tes_dis = b.Dth.discharge_kWh; batt_dis = b.Del.discharge_kWh;
pv_direct = b.Del.direct_kWh;                          % PV directly to SOEC [kWh/yr]
EsoecEl   = P_SOEC_kW*yr; Qheat_yr = Q_heat*yr;
elecPath  = pv_direct + batt_dis;                      % electricity from PV/battery
elecPath  = min(elecPath, EsoecEl);
blockElec = max(EsoecEl - elecPath, 0);                % electricity from CSP block
thermalPath = Qheat_yr + blockElec;                    % heat + block electricity
C.storage_thermal_frac = thermalPath/max(thermalPath+elecPath,1e-9);
C.sigma_overnight = tes_dis/max(tes_dis+batt_dis,1e-9);% overnight-only thermal share
C.f_th = C.storage_thermal_frac;
C.sizing = struct('C_PV_kW',b.Cpv,'h_batt',b.hB,'E_batt_kWh',b.Ebatt,'SM',b.SM, ...
   'h_TES',b.hT,'A_ap',b.A_ap,'E_TES_kWh',b.Emax,'N_cells',N_cells, ...
   'P_SOEC_kW',P_SOEC_kW,'P_block_kW',b.Eel_block);
C.capexBreak = struct('field',cst.c_field*b.A_ap,'block',cst.c_block*b.Eel_block, ...
   'TES',cst.c_TES*b.Emax,'PV',cst.c_PV*b.Cpv,'battE',cst.c_battE*b.Ebatt,'SOEC',capex_soec);
yr=P.time.hoursPerYr;
C.energy = struct('Qfield_served_yr',b.Dth.served_kWh,'Qdefocus_yr',b.Dth.spill_kWh, ...
   'Etes_dis_yr',tes_dis,'Epv_yr',sum(sum(b.PV.*wmY)),'Ebatt_dis_yr',batt_dis, ...
   'Epv_curtail_yr',b.Del.spill_kWh,'EsoecEl_yr',P_SOEC_kW*yr,'Qsoec_heat_yr',Q_heat*yr, ...
   'Esolar_inc_yr',sum(sum((res.Gb.*b.A_ap/1000).*wmY)));
C.soec=sp; C.H2_kg_yr=H2_kg_yr;
if opt.wantHourly
   C.hourly=struct('PV',b.PV,'Qfield',b.Qfield,'socTES',b.Dth.socTrace,'socBatt',b.Del.socTrace,'Lth',b.Lth_h);
end
end

% -------------------------------------------------------------------------
function A = assembleHeat(P,cst,WACC,ths,P_SOEC_kW,Q_heat_kW,N_cells,sp,H2_kg_yr,L_el_S,opt)
capex_soec = cst.c_SOEC*P_SOEC_kW;
capex = ths.capex + capex_soec;
Cann_capex = crf(WACC,P.econ.life)*capex;
opex = P.econ.opex_fix*capex;
repl = replCost(P,WACC,cst,P_SOEC_kW);
H2_act = H2_kg_yr*ths.reliab;                         % hydrogen actually delivered firm
water= P.econ.c_water*H2_act;
Cann = Cann_capex + opex + repl + water;
A.LCOH = Cann/H2_act;
A.reliab = ths.reliab; A.H2_act = H2_act;
A.sizing = struct('SM',ths.SM,'h_TES',ths.hT,'A_ap',ths.A_ap,'E_TES_kWh',ths.Emax, ...
    'N_cells',N_cells,'P_SOEC_kW',P_SOEC_kW,'Q_heat_kW',Q_heat_kW,'i_soec',sp.i, ...
    'P_block_kW',L_el_S);
A.feasible = ths.feasible;
A.capexBreak = struct('field',cst.c_field*ths.A_ap,'block',cst.c_block*L_el_S, ...
    'TES',cst.c_TES*ths.Emax,'SOEC',capex_soec);
A.capex=capex; A.Cann=Cann; A.Cann_capex=Cann_capex; A.opex=opex; A.repl=repl; A.water=water;
% energy flows (annual) [kWh/yr]
yr=P.time.hoursPerYr;
A.energy = struct( ...
   'Qabs_yr',ths.Qabs_yr, ...
   'Qfield_served_yr',ths.D.served_kWh, ...
   'Qdefocus_yr',ths.D.spill_kWh, ...
   'Etes_charge_yr',ths.D.charge_kWh,'Etes_dis_yr',ths.D.discharge_kWh, ...
   'Lth_yr',ths.D.load_kWh, ...
   'EsoecEl_yr',P_SOEC_kW*yr,'Qsoec_heat_yr',Q_heat_kW*yr, ...
   'Epb_in_yr',ths.Qpb_in*yr,'Eelec_yr',L_el_S*yr, ...
   'Esolar_inc_yr',ths.Esolar_inc_yr);
A.soec=sp; A.thermal=ths; A.H2_kg_yr=H2_kg_yr;
A.storage_thermal_frac = 1.0;     % pure heat route -> overnight 100% thermal
if opt.wantHourly
   A.hourly = struct('Qfield',ths.Qfield,'soc',ths.D.socTrace,'Lth',ths.Lth);
end
end

% -------------------------------------------------------------------------
function B = assembleElec(P,cst,WACC,els,P_LT_kW,H2_kg_yr,L_el_B,opt)
capex_lt = cst.c_LT*P_LT_kW;
capex = els.capex + capex_lt;
Cann_capex = crf(WACC,P.econ.life)*capex;
opex = P.econ.opex_fix*capex;
repl = 0;                                  % LT stack replacement folded into opex_fix here
H2_act = H2_kg_yr*els.reliab;
water= P.econ.c_water*H2_act;
Cann = Cann_capex + opex + repl + water;
B.LCOH = Cann/H2_act;
B.reliab = els.reliab; B.H2_act = H2_act;
B.sizing = struct('C_PV_kW',els.Cpv,'C_wind_kW',els.Cw,'E_batt_kWh',els.Emax, ...
    'P_batt_kW',els.Pbatt,'P_LT_kW',P_LT_kW,'PVmult',els.PVmult,'h_batt',els.hB);
B.feasible = els.feasible;
B.capexBreak = struct('PV',cst.c_PV*els.Cpv,'wind',cst.c_wind*els.Cw, ...
    'battE',cst.c_battE*els.Emax,'battP',cst.c_battP*els.Pbatt,'LT',capex_lt);
B.capex=capex; B.Cann=Cann; B.Cann_capex=Cann_capex; B.opex=opex; B.repl=repl; B.water=water;
yr=P.time.hoursPerYr;
B.energy = struct('Epv_yr',els.Epv_yr,'Ew_yr',els.Ew_yr, ...
   'Ecurtail_yr',els.D.spill_kWh,'Ebatt_ch_yr',els.D.charge_kWh, ...
   'Ebatt_dis_yr',els.D.discharge_kWh,'Elt_yr',P_LT_kW*yr,'Eelec_yr',L_el_B*yr, ...
   'Esolar_inc_yr',els.Epv_yr/max(P.pv.eta_sys,1e-6));
B.elec=els; B.H2_kg_yr=H2_kg_yr;
B.storage_thermal_frac = 0.0;     % pure electricity route -> 0% thermal
if opt.wantHourly
   B.hourly = struct('gen',els.gen,'soc',els.D.socTrace,'Lel',L_el_B,'Ppv',els.Ppv,'Pw',els.Pw);
end
end

% -------------------------------------------------------------------------
function L = nonFirmFollow(P,res,WACC,cst,arch,Qheat_kW,Lel_kW,Prate_kW,Cann_el,mdot_firm)
% Conventional ANNUAL-AVERAGE LCOH: no storage, the electrolyzer follows the
% available resource (variable H2). Renewable field sized to minimise LCOH.
% This is the firmness-premium baseline (Section 3.1).
wm=ones(24,1)*reshapeMonthW(res.Gb); crfL=crf(WACC,P.econ.life);
best=inf;
if arch=='A'
    Lth=Qheat_kW + Lel_kW/(P.pb.eta_pb*(1-P.pb.f_par));
    for SM=linspace(1.0,2.5,7)
        A_ap=SM*Lth*1000/(cst.Gb_design*P.csp.eta_opt0*P.csp.f_avail*P.csp.f_clean);
        Qf=cspField(P,res,A_ap);
        util=min(Qf./Lth,1);                       % hourly load fraction (no TES)
        H2=sum(sum(util*mdot_firm.*wm));
        capex=cst.c_field*A_ap+cst.c_block*Lel_kW;  % SOEC cost is in Cann_el
        Cann=crfL*capex+P.econ.opex_fix*capex+Cann_el+P.econ.c_water*H2;
        best=min(best,Cann/max(H2,1));
    end
else
    for pm=linspace(1.0,3.0,7)
        Cpv=pm*Lel_kW; Ppv=pvPower(P,res,Cpv);
        util=min(Ppv./Lel_kW,1);
        H2=sum(sum(util*mdot_firm.*wm));
        capex=cst.c_PV*Cpv;                          % LT cost is in Cann_el
        Cann=crfL*capex+P.econ.opex_fix*capex+Cann_el+P.econ.c_water*H2;
        best=min(best,Cann/max(H2,1));
    end
end
L=best;
end

% -------------------------------------------------------------------------
function r = replCost(P,WACC,cst,P_SOEC_kW)
% Annualised SOEC stack replacement (Eq 53): one replacement at stack life.
L=P.econ.life; Ls=P.econ.L_soec;
capex_soec = cst.c_SOEC*P_SOEC_kW;
nRepl = floor((L-1)/Ls);
pv=0;
for k=1:nRepl
    pv = pv + P.econ.f_repl_soec*capex_soec/(1+WACC)^(k*Ls);
end
r = crf(WACC,L)*pv;
end

% -------------------------------------------------------------------------
function f = crf(WACC,L)
% Capital recovery factor (Eq 52).
f = WACC.*(1+WACC).^L ./ ((1+WACC).^L - 1);
end

% -------------------------------------------------------------------------
function [nG,nR] = optRes(P,opt)
% Sizing-grid resolution: defaults from P.opt, overridable per call via opt
% (the DNI sweep uses a finer grid to remove quantization wiggle in figures).
nG=P.opt.nGrid; nR=P.opt.nRefine;
if isfield(opt,'nGrid')   && ~isempty(opt.nGrid),   nG=opt.nGrid;   end
if isfield(opt,'nRefine') && ~isempty(opt.nRefine), nR=opt.nRefine; end
end

% -------------------------------------------------------------------------
function s = scoreRel(Cann, reli, floor)
% Lexicographic sizing score: among designs meeting the firm reliability
% floor, minimise annualised cost; otherwise drive reliability up to the floor.
if reli >= floor
    s = Cann;
else
    s = Cann + 1e9*(floor - reli);
end
end
