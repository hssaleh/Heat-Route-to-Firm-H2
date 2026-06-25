%% HEATROUTE_FIRMH2_MAIN  Master driver: "The Heat Route to Firm Green Hydrogen"
% =========================================================================
% PROJECT : Spatially-explicit, firmness-resolved techno-economic comparison
%           of the HEAT route (CSP+TES+SOEC) vs the ELECTRICITY route
%           (PV/Wind+Battery+LT electrolyzer) vs a co-optimized HYBRID, for
%           firm (24-h) green hydrogen, with full energy/exergy/entropy/
%           economic/environmental and dimensionless analysis, designed to
%           Nature-Energy display standards.
%
% PURPOSE : Orchestrates the whole study:
%             1. Build the global resource grid (synthetic, physically based)
%             2. Solve every land cell for Architectures A & B  -> global maps
%             3. DNI sweep for A,B,C -> crossover law & storage-medium split
%             4. Deep thermodynamic analysis of named archetype sites
%             5. Cost-scenario (2025/2030/2050) and Monte-Carlo robustness
%             6. Generate all publication figures (hr_make_figures)
%             7. Export every figure's data+caption+interpretation to Excel
%             8. Validate/verify and save .mat
%
% AUTHOR  : <Hossam AbdelMeguid>     DATE: <2026>     VERSION 1.0
%
% USAGE   : run('HeatRoute_FirmH2_Main.m')
% OUTPUTS : output/HeatRoute_FirmH2_FigureData.xlsx, *.fig, *_Results.mat
%
% NOTE on data: in the absence of measured global geodata files in the
%   workspace, the resource field is synthesised from solar geometry and a
%   climatological clearness model (hr_resource). The grid interface is
%   identical to that required by NASA POWER / ERA5 / Global Solar Atlas, so
%   measured hourly series can be substituted with no change to the analysis.
% =========================================================================
clear; clc; close all;
fprintf('=============================================================\n');
fprintf(' THE HEAT ROUTE TO FIRM GREEN HYDROGEN - master simulation\n');
fprintf('=============================================================\n');
t0=tic;
P = hr_config();
rng(P.mc.seed);                                  % reproducibility

D = struct();                                    % master data container
D.P = P;

%% ------------------------------------------------------------------------
%  STEP 1 - Global resource grid (synthetic, physically-based)
%  ------------------------------------------------------------------------
fprintf('[1] Building global resource grid ...\n');
NASA = hr_load_nasa(P);                            % measured climatology (if cached)
[GRID] = hr_build_grid(P, NASA);
D.grid = GRID; D.nasa = NASA;
fprintf('    %d land cells (of %d) on a %g-deg grid. Resource: %s.\n', ...
        nnz(GRID.land), numel(GRID.land), P.grid.res, GRID.source);

%% ------------------------------------------------------------------------
%  STEP 2 - Solve every land cell for Architectures A & B (global maps)
%  ------------------------------------------------------------------------
fprintf('[2] Solving cell-level least-cost firm hydrogen (A,B) ...\n');
[nLat,nLon] = size(GRID.DNI);
LCOH_A = nan(nLat,nLon); LCOH_B = nan(nLat,nLon);
REL_A  = nan(nLat,nLon); REL_B  = nan(nLat,nLon);
PREM_A = nan(nLat,nLon); PREM_B = nan(nLat,nLon);
ETA2_A = nan(nLat,nLon); ETA2_B = nan(nLat,nLon);
optG = struct('doC',false,'wantHourly',false);
idx = find(GRID.land);
tic;
for q = 1:numel(idx)
    [iy,ix] = ind2sub([nLat,nLon], idx(q));
    meas = cellMeas(GRID,iy,ix);                  % measured monthly (or [] -> synthetic)
    res = hr_resource(P, GRID.LAT(iy,ix), GRID.KT(iy,ix), GRID.WIND(iy,ix), GRID.DNI(iy,ix), meas);
    R = hr_solve_cell(P, res, GRID.WACC(iy,ix), ones(1,7), optG);
    LCOH_A(iy,ix)=R.A.LCOH; LCOH_B(iy,ix)=R.B.LCOH;
    REL_A(iy,ix)=R.A.reliab; REL_B(iy,ix)=R.B.reliab;
    PREM_A(iy,ix)=R.A.firmPremium; PREM_B(iy,ix)=R.B.firmPremium;
end
fprintf('    done in %.1f s.\n', toc);
dLCOH = LCOH_B - LCOH_A;                          % Eq 67  (>0 => heat route cheaper)
% Feasibility-aware winner: the cheaper FIRM-FEASIBLE route wins each cell.
feasA = REL_A>=P.firm.rel_floor; feasB = REL_B>=P.firm.rel_floor;
winHeat = feasA & ( (LCOH_A<=LCOH_B) | ~feasB );  % heat wins (cheaper or only feasible)
dom = nan(nLat,nLon); dom(GRID.land)=0; dom(winHeat & GRID.land)=1;
D.maps = struct('LCOH_A',LCOH_A,'LCOH_B',LCOH_B,'dLCOH',dLCOH,'dom',dom, ...
                'REL_A',REL_A,'REL_B',REL_B,'PREM_A',PREM_A,'PREM_B',PREM_B, ...
                'feasA',feasA,'feasB',feasB);

% Headline dominance share (Result 1): area-weighted (cos-lat) share of
% firm-feasible land where the heat route is the cheaper feasible route.
w = cosd(GRID.LAT); w(~GRID.land)=0;
feasAny = GRID.land & (feasA | feasB);
share_heat = sum(w(feasAny & winHeat),'all')/sum(w(feasAny),'all');
D.result.dominanceShare = share_heat;
fprintf('    Result 1  dominance share (heat/hybrid): %.1f %% of feasible land.\n',100*share_heat);

%% ------------------------------------------------------------------------
%  STEP 3 - DNI sweep (A,B,C): crossover law, storage-medium split, premium
%  ------------------------------------------------------------------------
fprintf('[3] DNI sweep for crossover law and storage-medium split ...\n');
DNIsw = (1000:50:3300)';        % fine DNI sweep -> smooth frontier curves
nS = numel(DNIsw);
sw = struct('DNI',DNIsw,'A',nan(nS,1),'B',nan(nS,1),'C',nan(nS,1), ...
            'sigma',nan(nS,1),'premA',nan(nS,1),'premB',nan(nS,1), ...
            'psiA',nan(nS,1),'psiB',nan(nS,1),'relA',nan(nS,1), ...
            'SM',nan(nS,1),'hTES',nan(nS,1),'PVc',nan(nS,1));
optSweep = struct('doC',true,'wantHourly',false,'nGrid',15,'nRefine',11); % fine grid -> smooth curves
for j=1:nS
    KT = 0.40 + 0.40*(DNIsw(j)-1000)/2300;       % clearer at higher DNI
    res = hr_resource(P, 28, KT, 5.0, DNIsw(j));
    R = hr_solve_cell(P,res,0.08,ones(1,7),optSweep);
    sw.A(j)=R.A.LCOH; sw.B(j)=R.B.LCOH; sw.C(j)=R.C.LCOH;
    sw.sigma(j)=R.C.storage_thermal_frac;
    sw.premA(j)=R.A.firmPremium; sw.premB(j)=R.B.firmPremium;
    sw.relA(j)=R.A.reliab;
    anA=hr_analyze_arch(P,res,R.A); anB=hr_analyze_arch(P,res,R.B);
    sw.psiA(j)=anA.exergy.psi_conv; sw.psiB(j)=anB.exergy.psi_conv;
    sw.SM(j)=R.C.sizing.SM; sw.hTES(j)=R.C.sizing.h_TES; sw.PVc(j)=R.C.sizing.C_PV_kW;
end
% break-even DNI* : lowest DNI at which the heat route is firm-FEASIBLE and
% cheaper than the electricity route (the operative crossover, Eq 69).
winA = (sw.relA>=P.firm.rel_floor) & (sw.A < sw.B);
ixw = find(winA,1);
if ~isempty(ixw)
    DNIstar = DNIsw(ixw);
else
    DNIstar = NaN;
end
% firm-feasibility crossover: lowest DNI at which the heat route reaches the floor
ixf = find(sw.relA>=P.firm.rel_floor,1);
DNIfeas = NaN; if ~isempty(ixf), DNIfeas = DNIsw(ixf); end
D.sweep = sw; D.result.DNIstar = DNIstar; D.result.DNIfeas = DNIfeas;
fprintf('    Result 2  break-even DNI* = %.0f ; heat-route firm-feasibility DNI = %.0f kWh/m2/yr\n',DNIstar,DNIfeas);

%% ------------------------------------------------------------------------
%  STEP 4 - Deep thermodynamic analysis of named archetype sites
%  ------------------------------------------------------------------------
fprintf('[4] Deep analysis of %d archetype sites ...\n',numel(P.arch));
ARCH = struct('name',{},'res',{},'R',{},'anA',{},'anB',{},'anC',{});
for k=1:numel(P.arch)
    a=P.arch(k);
    meask=[];
    if isfield(NASA,'arch') && k<=numel(NASA.arch) && all(isfinite(NASA.arch(k).DNI_m))
        meask=NASA.arch(k);
    end
    res=hr_resource(P,a.lat,a.KT,a.wind,a.DNI,meask);
    R=hr_solve_cell(P,res,a.WACC,ones(1,7),struct('doC',true,'wantHourly',true));
    ARCH(k).name=a.name; ARCH(k).res=res; ARCH(k).R=R;
    ARCH(k).anA=hr_analyze_arch(P,res,R.A);
    ARCH(k).anB=hr_analyze_arch(P,res,R.B);
    ARCH(k).anC=hr_analyze_arch(P,res,R.C);
end
D.arch = ARCH;
% SOEC V-i sweep (for electrochemistry figure)
ii = (0.2:0.05:1.1)';
VI = struct('i',ii,'Vcell',nan(size(ii)),'Vrev',nan(size(ii)),'eta_act',nan(size(ii)), ...
            'eta_ohm',nan(size(ii)),'eta_conc',nan(size(ii)),'SECel',nan(size(ii)), ...
            'SECtot',nan(size(ii)),'etaLHV',nan(size(ii)));
res0=hr_resource(P,P.arch(2).lat,P.arch(2).KT,P.arch(2).wind,P.arch(2).DNI);
for j=1:numel(ii)
    Rj=hr_solve_cell(P,res0,0.08,ones(1,7),struct('doC',false,'i_soec',ii(j)));
    sp=Rj.A.soec;
    VI.Vcell(j)=sp.Vcell; VI.Vrev(j)=sp.Vrev; VI.eta_act(j)=sp.eta_act;
    VI.eta_ohm(j)=sp.eta_ohm; VI.eta_conc(j)=sp.eta_conc;
    VI.SECel(j)=sp.SEC_el; VI.SECtot(j)=sp.SEC_tot; VI.etaLHV(j)=sp.eta_LHV;
end
D.VI = VI;

%% ------------------------------------------------------------------------
%  STEP 5 - Cost scenarios (2025/2030/2050) and Monte-Carlo robustness
%  ------------------------------------------------------------------------
fprintf('[5] Cost scenarios and Monte-Carlo (M=%d) ...\n',P.mc.M);
% (a) scenario LCOH on the archetypes
SCEN = struct('names',P.scen.names,'LCOH_A',nan(numel(P.arch),3), ...
              'LCOH_B',nan(numel(P.arch),3),'dom',nan(numel(P.arch),3));
for s=1:3
    m = P.scen.mult(s,:);
    for k=1:numel(P.arch)
        a=P.arch(k); res=hr_resource(P,a.lat,a.KT,a.wind,a.DNI);
        R=hr_solve_cell(P,res,a.WACC,m,struct('doC',false));
        SCEN.LCOH_A(k,s)=R.A.LCOH; SCEN.LCOH_B(k,s)=R.B.LCOH; SCEN.dom(k,s)=double(R.dLCOH>0);
    end
end
D.scen = SCEN;
% (b) Monte-Carlo over uncertain parameters (Eq 70-71) on a DNI ladder
MC = hr_montecarlo(P);
D.mc = MC;
fprintf('    Result 5  mean Pr[heat route wins] over feasible ladder = %.0f %%\n',100*mean(MC.Pwin,'omitnan'));

% (c) Monte-Carlo dominance-probability MAP (reduced sample on the grid)
fprintf('    building dominance-probability map ...\n');
Pmap = hr_dominance_map(P, GRID);
D.maps.Pwin = Pmap;

%% ------------------------------------------------------------------------
%  STEP 6 - Sensitivity (tornado) + comprehensive uncertainty analysis
%  ------------------------------------------------------------------------
fprintf('[6] Local sensitivity (tornado) ...\n');
D.tornado = hr_tornado(P);
fprintf('    comprehensive uncertainty propagation for ALL results ...\n');
D.uncertainty = hr_uncertainty(P);
fprintf('\n--- UNCERTAINTY SUMMARY (M=%d draws) ---\n',D.uncertainty.M);
disp(D.uncertainty.metrics);

save('All_Data.mat');
load('All_Data.mat');
%% ------------------------------------------------------------------------
%  STEP 7 - Validation, then figures + Excel export
%  ------------------------------------------------------------------------
fprintf('[7] Validation & verification ...\n');
VAL = hr_validate(P, D);
D.validation = VAL;

fprintf('[8] Generating figures ...\n');
FIG = hr_make_figures(P, D);

fprintf('[9] Exporting figure data to Excel (one sheet per figure) ...\n');
hr_export_excel(P, FIG);

% save numeric results (figure handles are NOT stored, to keep the .mat small)
save(P.io.matfile, 'D', '-v7.3');
fprintf('Saved results -> %s\n', P.io.matfile);
fprintf('TOTAL runtime %.1f s\n', toc(t0));
fprintf('=============================================================\n');

% =========================================================================
% ============================ LOCAL FUNCTIONS ============================
% =========================================================================
function G = hr_build_grid(P, NASA)
% Build the global lat-lon grid: analytic land mask + resource field. When
% NASA POWER monthly climatology is cached it ANCHORS the annual DNI/GHI/wind
% and stores monthly fields (DNI_m,...) for per-cell measured-mode dispatch;
% otherwise a physically-based synthetic field is used. WACC is always a
% country-risk proxy (no measured equivalent).
if nargin<2, NASA=struct('grid_ok',false); end
lon = P.grid.lon; lat = P.grid.lat;
[LON,LAT] = meshgrid(lon,lat);
land = realLandMask(LAT,LON);                   % real continents from 1-deg topography
% --- synthetic baseline (also the fallback for any missing measured cell) ---
band   = exp(-((abs(LAT)-25)/12).^2);
equator= 1 - 0.45*exp(-(LAT/8).^2);
polar  = max(1 - (max(abs(LAT)-40,0)/40),0.25);
desert = desertEnhance(LAT,LON);
DNI = min(max(1500*band.*equator.*polar + 1400*desert,700),3300);
KT  = min(max(0.34 + 0.16*(DNI-700)/2600 + 0.10*desert,0.30),0.80);
WIND = 4.0 + 3.0*min(abs(LAT)/55,1) + 1.0*coastalProxy(LAT,LON);
WACC = waccProxy(LAT,LON);
source = "synthetic (physically-based)";
hasMeas = false; DNI_m=[]; GHI_m=[]; T_m=[]; W_m=[];
% --- overlay measured NASA POWER climatology where available ----------------
if isfield(NASA,'grid_ok') && NASA.grid_ok
    md = P.time.monthDays(:)';                          % days per month
    DNI_m=NASA.DNI; GHI_m=NASA.GHI; T_m=NASA.T; W_m=NASA.W;
    % spatially interpolate each monthly field to fill residual gaps (sparse
    % satellite returns), so every land cell carries a measured-derived value.
    DNI_m=fillMonthly(DNI_m,LAT,LON); GHI_m=fillMonthly(GHI_m,LAT,LON);
    T_m  =fillMonthly(T_m,LAT,LON);   W_m  =fillMonthly(W_m,LAT,LON);
    annDNI = sum(DNI_m.*reshape(md,1,1,12),3);          % kWh/m2/yr
    annGHI = sum(GHI_m.*reshape(md,1,1,12),3);
    meanW  = mean(W_m,3);
    valid  = isfinite(annDNI) & isfinite(annGHI) & isfinite(meanW);
    DNI(valid)=annDNI(valid); WIND(valid)=meanW(valid);
    KTm = min(max(annGHI./max((2.6e3*cosd(min(abs(LAT),60))+1e3),1),0.2),0.85);
    KT(valid)=KTm(valid);
    hasMeas = true; source = "NASA POWER (measured monthly climatology)";
end
G = struct('lon',lon,'lat',lat,'LON',LON,'LAT',LAT,'land',land, ...
           'DNI',DNI,'KT',KT,'WIND',WIND,'WACC',WACC, ...
           'hasMeas',hasMeas,'DNI_m',DNI_m,'GHI_m',GHI_m,'T_m',T_m,'W_m',W_m, ...
           'source',source);
end

function meas = cellMeas(G, iy, ix)
% Extract a per-cell measured monthly struct for hr_resource, or [] to use the
% synthetic model (when measured data are absent or incomplete for the cell).
meas = [];
if ~isfield(G,'hasMeas') || ~G.hasMeas || isempty(G.DNI_m), return; end
dni = squeeze(G.DNI_m(iy,ix,:))'; ghi = squeeze(G.GHI_m(iy,ix,:))';
tt  = squeeze(G.T_m(iy,ix,:))';   ww  = squeeze(G.W_m(iy,ix,:))';
if all(isfinite([dni ghi tt ww]))
    meas = struct('DNI_m',dni,'GHI_m',ghi,'T_m',tt,'W_m',ww);
end
end

function Vf = fillMonthly(V, LAT, LON)
% Fill NaN gaps in each monthly slice [nLat x nLon x 12] by spatial
% interpolation (linear + nearest extrapolation) from the valid measured cells.
Vf = V;
for m=1:size(V,3)
    Z=V(:,:,m); good=isfinite(Z);
    if nnz(good) < 10, continue; end
    if nnz(~good)==0,  continue; end
    F=scatteredInterpolant(LON(good),LAT(good),Z(good),'linear','nearest');
    Zi=Z; Zi(~good)=F(LON(~good),LAT(~good)); Vf(:,:,m)=Zi;
end
end

function L = realLandMask(LAT,LON)
% Real land mask from the built-in 1-degree global topography (land = elev>0).
S = load('topo.mat');                         % topo [180x360], rows lat -89.5..89.5, cols lon 0.5..359.5
topo = S.topo;
latT = -89.5:1:89.5; lonT = 0.5:1:359.5;
lonC = mod(LON,360);                          % map -180..180 -> 0..360
elev = interp2(lonT, latT, topo, lonC, LAT, 'nearest', -9999);
L = elev > 0;                                 % above sea level = land
end

function d = desertEnhance(LAT,LON)
% Gaussian bumps over the principal high-DNI arid belts (schematic).
cen = [ 23 13; 24 45; 28 -8; 34 -110; -24 134; -23 -69; 39 -116; 27 73; 40 80];
d = zeros(size(LAT));
for c=1:size(cen,1)
   d = d + exp(-(((LAT-cen(c,1))/9).^2 + ((LON-cen(c,2))/12).^2));
end
d = min(d,1);
end

function c = coastalProxy(LAT,LON)
c = 0.5*(1+sin(LON/20)).*0.5;  % mild schematic coastal/diurnal wind pattern
c = min(max(c,0),1);
end

function W = waccProxy(LAT,LON)
% Lower cost of capital in OECD-like bands; higher in developing regions.
W = 0.085 + 0.0*LAT;
W = W - 0.02*(LAT>30 & LON>-130 & LON<-65);   % North America
W = W - 0.02*(LAT>35 & LAT<60 & LON>-10 & LON<30); % Europe
W = W - 0.02*(LAT<-10 & LAT>-40 & LON>112 & LON<155); % Australia
W = W + 0.02*(abs(LAT)<25 & LON>-20 & LON<55);  % Africa risk premium
W = min(max(W,0.045),0.12);
end

