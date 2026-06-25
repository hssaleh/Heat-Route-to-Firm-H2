function FIG = hr_make_figures(P, D)
%HR_MAKE_FIGURES  Build every publication figure for the study and return a
% cell array of figure-data structs (handle + numeric data table + caption,
% explanation and interpretation strings). Each figure groups related panels
% with tiledlayout and uses left/right y-axes (yyaxis) whenever the plotted
% series occupy different numeric ranges, per the project requirements.
%
% INPUT  : P (params), D (master data from HeatRoute_FirmH2_Main)
% OUTPUT : FIG (1xN cell). FIG{i} fields: id,name,caption,explanation,
%          interpretation,xlabel,ylabel,legend,T(table),fig(handle)
% =========================================================================

specs = { @fig01_concept, @fig02_maps, @fig03_dominance, @fig04_crossover, ...
          @fig05_mechanism, @fig06_future, @fig07_soec, @fig08_energyflow, ...
          @fig09_exergy, @fig10_entropy, @fig11_efficiency, @fig12_dimensionless, ...
          @fig13_dispatch, @fig14_economic, @fig15_environment, @fig16_tornado, ...
          @fig17_montecarlo, @fig18_split, @fig19_heatleverage, @fig20_validation, ...
          @fig21_uncertainty };
FIG = {};
for s=1:numel(specs)
    try
        f = specs{s}(P,D);

        
        f.id = sprintf('Fig%02d_%s', numel(FIG)+1, f.tag);
        
        FIG{end+1} = f;                                            %#ok<AGROW>
        try, savefig(f.fig, fullfile(P.io.outdir, sprintf('Figure_%03d_%s.fig',numel(FIG),f.tag))); catch, end
        fprintf('    [ok] Figure %02d  %s\n', numel(FIG), f.name);
    catch ME
        warning('    [skip] figure %d (%s): %s', s, func2str(specs{s}), ME.message);
    end
end


end

% =========================================================================
% ============================ STYLE HELPERS ==============================
% =========================================================================
function fig = NewFig(name)
% fig = figure('Name',name,'Color','w','Units','normalized', ...
%              'Position',[0.07 0.08 0.82 0.80],'Visible','on');
end
function styleAx(ax)
set(ax,'FontName','Helvetica','FontSize',11,'LineWidth',1.0,'Box','on');
grid(ax,'on'); ax.GridAlpha=0.12;
end
function s = S(varargin); s = string(sprintf(varargin{:})); end

function k = exemplarIdx(D)
% Index of the highest-DNI archetype where the heat route is firm-feasible
% (the clearest "why heat wins" exemplar); falls back to the highest DNI.
A=D.arch; n=numel(A);
dni=arrayfun(@(s)s.res.annualDNI,A);
feas=arrayfun(@(s)s.R.A.feasible,A);
cand=find(feas);
if isempty(cand), [~,k]=max(dni); return; end
[~,j]=max(dni(cand)); k=cand(j);
end

function h = mapPanel(ax, G, Z, ttl, cmapName, climits)
% World map: data over real land (covers the continents), ocean shaded blue,
% global coastlines drawn over the top so the whole globe reads as context.
persistent CL
if isempty(CL)
    try, CL=load('coastlines.mat'); catch, CL=struct('coastlat',[],'coastlon',[]); end
end
Zp = Z; Zp(~G.land)=NaN;
set(ax,'Color',[0.85 0.91 0.97]);                 % ocean background
hold(ax,'on');
hd=pcolor(ax, G.LON, G.LAT, Zp); set(hd,'EdgeColor','none'); % data over land
colormap(ax, cmapName);
if nargin>=6 && ~isempty(climits), set(ax,'CLim',climits); end
if ~isempty(CL.coastlat)                            % coastlines = the globe behind
    clon=CL.coastlon; clon(clon>180|clon<-180)=NaN; % avoid dateline streaks
    plot(ax, clon, CL.coastlat, '-', 'Color',[0.30 0.30 0.30], 'LineWidth',0.4);
end
cb=colorbar(ax); cb.LineWidth=0.8;
title(ax,ttl); xlabel(ax,'Longitude (\circ)'); ylabel(ax,'Latitude (\circ)');
xlim(ax,[min(G.lon) max(G.lon)]); ylim(ax,[min(G.lat) max(G.lat)]);
styleAx(ax); h=cb;
end

%% =========================================================================
% FIGURE 1 - Concept: the storage-medium decision and the heat leverage
% =========================================================================
function f = fig01_concept(P,D)
%
A=D.arch; k=exemplarIdx(D);                       % highest-DNI feasible archetype as exemplar
anA=A(k).anA; anB=A(k).anB;
secA=[anA.energy.SEC_elec, anA.energy.SEC_total-anA.energy.SEC_elec]; % [elec heat]
%
secB=[anB.energy.SEC_total, 0];
fig=figure('Name','Fig1 Concept','Position',[50 50 450 1000]); tl=tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
% panel a: energy-input split (electricity vs heat) per kg H2
ax=nexttile(tl); b=bar(ax,[secA;secB],'stacked'); b(1).FaceColor=P.style.colB; b(2).FaceColor=P.style.colA;
set(ax,'XTickLabel',{'Heat route (A)','Elec route (B)'}); ylabel(ax,'Specific energy (kWh kg^{-1} H_2)');
title(ax,'(a) Splitting-energy supply'); legend(ax,{'Electrical work','Heat'},'Location','north','Orientation','horizontal'); styleAx(ax);
ylim([0 65])
% panel b: levelized cost of the three architectures
Lc=[A(k).R.A.LCOH A(k).R.B.LCOH A(k).R.C.LCOH];
ax=nexttile(tl); b=bar(ax,Lc,'FaceColor','flat'); b.CData=[P.style.colA;P.style.colB;P.style.colC];
set(ax,'XTickLabel',{'A heat','B elec','C hybrid'}); ylabel(ax,'Firm LCOH (USD kg^{-1})');
title(ax,'(b) Firm hydrogen cost'); styleAx(ax);

% panel c: heat-leverage and electrical-substitution numbers
nd=anA.nd; vals=[nd.HeatLeverage nd.ElecSubstitution anA.exergy.psi_conv anB.exergy.psi_conv];
ax=nexttile(tl); b=bar(ax,vals,'FaceColor','flat');
b.CData=[P.style.colA;P.style.colA;P.style.colA;P.style.colB];
set(ax,'XTickLabel',{'Heat leverage \Lambda','Elec. substitution','\psi_A (2nd law)','\psi_B (2nd law)'});
xtickangle(ax,20); ylabel(ax,'Dimensionless (-)'); title(ax,'(c) Heat-leverage mechanism'); styleAx(ax);
%
 T=table(["Heat route A";"Elec route B"],secA(1)*[1;0]+secB(1)*[0;1], ...
        [secA(2);secB(2)],[A(k).R.A.LCOH;A(k).R.B.LCOH], ...
        'VariableNames',{'Route','SEC_electrical_kWhkg','SEC_heat_kWhkg','LCOH_USDkg'});
f=struct('tag','concept','name','Concept: storage-medium decision & heat leverage', ...
 'xlabel','Architecture','ylabel','Energy / cost / dimensionless', ...
 'legend',["Electrical work","Heat"],'T',T,'fig',fig, ...
 'caption',S('Fig. 1. The firm-hydrogen storage-medium decision and the heat-leverage mechanism (exemplar: %s). (a) Per-kg splitting energy supplied as electrical work versus heat for the heat (SOEC) and electricity (LT) routes; (b) optimized firm LCOH of the three architectures; (c) the heat-leverage ratio, electrical-substitution number and second-law efficiencies.',A(k).name), ...
 'explanation',S('Panel (a) shows that the high-temperature SOEC route meets part of the water-splitting enthalpy as heat (red), lowering the expensive electrical demand relative to the low-temperature route, which supplies all energy as electricity. Panel (b) compares the cost-optimal firm LCOH of the pure heat route (A), the pure electricity route (B) and the co-optimized hybrid (C). Panel (c) quantifies the mechanism through the heat-leverage ratio Lambda (heat share of total splitting energy), the electrical-substitution number (electricity saved versus the LT route) and the exergy efficiencies of both routes.'), ...
 'interpretation',S('Supplying ~%.0f%% of the splitting energy as cheaply-storable heat lets the heat route substitute ~%.0f%% of the electrical work and raises its second-law efficiency from %.2f (electricity route) to %.2f, which is the physical origin of its lower firm cost (%.2f vs %.2f USD/kg).',100*anA.nd.HeatLeverage,100*anA.nd.ElecSubstitution,anB.exergy.psi_conv,anA.exergy.psi_conv,A(k).R.A.LCOH,A(k).R.B.LCOH));
end


%% =========================================================================
% FIGURE 2 - Global firm-LCOH maps, heat route vs electricity route
% =========================================================================
function f = fig02_maps(P,D)
G=D.grid; M=D.maps;
fig=figure('Name','Fig2 LCOH maps','Position',[50 50 800 600]);  tl=tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
cl=[2 10];
ax=nexttile(tl); mapPanel(ax,G,M.LCOH_A,'(a) Heat route  LCOH_{firm} (USD kg^{-1})','turbo',cl);
ax=nexttile(tl); mapPanel(ax,G,M.LCOH_B,'(b) Electricity route  LCOH_{firm} (USD kg^{-1})','turbo',cl);
% data table: land cells
idx=find(G.land);
T=table(G.LAT(idx),G.LON(idx),M.LCOH_A(idx),M.LCOH_B(idx),G.DNI(idx), ...
        'VariableNames',{'Lat','Lon','LCOH_A_USDkg','LCOH_B_USDkg','DNI_kWhm2yr'});
f=struct('tag','LCOHmaps','name','Global firm-LCOH maps (heat vs electricity route)', ...
 'xlabel','Longitude (deg)','ylabel','Latitude (deg)','legend',["LCOH heat","LCOH elec"],'T',T,'fig',fig, ...
 'caption',S('Fig. 2. Global maps of the levelized cost of firm (24-h) hydrogen for (a) the heat route and (b) the electricity route, on a %g-degree grid; resource field: %s.',P.grid.res,char(G.source)), ...
 'explanation',S('Each land cell is independently size-optimized to deliver firm hydrogen at minimum LCOH (Eqs 51-66). The heat route (a) is cheapest across the high-DNI subtropical arid belts; the electricity route (b) is more uniform but everywhere more expensive where firmness is imposed because battery storage is costly.'), ...
 'interpretation',S('Firm hydrogen is cheap in DIFFERENT places depending on the route: the heat route concentrates low cost in the high-DNI belt (down to ~%.1f USD/kg), whereas the electricity route rarely falls below ~%.1f USD/kg. This is the spatial signature that motivates a storage-medium decision map.',min(M.LCOH_A(idx)),min(M.LCOH_B(idx))));
end

%% =========================================================================
% FIGURE 3 - Dominance map (Delta LCOH) + thermal hydrogen belt + share
% =========================================================================
function f = fig03_dominance(P,D)
G=D.grid; M=D.maps;
fig=figure('Name','Fig3 Dominance','Position',[50 50 1000 350]); tl=tiledlayout(fig,1,4,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl,[1 3]);
% EFFECTIVE cost gap for the dominance map: where the heat route is NOT firm-
% feasible it cannot win, so force the gap negative there (electricity wins).
dd=M.dLCOH;
infA = G.land & ~M.feasA;                 % heat route firm-infeasible
dd(infA) = -abs(dd(infA)) - 0.2;
dd(~G.land)=NaN;
set(ax,'Color',[0.85 0.91 0.97]); hold(ax,'on');     % ocean background
hp=pcolor(ax,G.LON,G.LAT,dd); set(hp,'EdgeColor','none');
colormap(ax, diverging()); clim(ax,[-4 4]); cb=colorbar(ax); cb.Label.String='\DeltaLCOH_{eff} = LCOH_B - LCOH_A (USD kg^{-1})';
% thermal hydrogen belt = contour where the (feasibility-aware) gap = 0
contour(ax,G.LON,G.LAT,dd,[0 0],'k','LineWidth',2);
try, CL3=load('coastlines.mat'); c3=CL3.coastlon; c3(c3>180|c3<-180)=NaN; plot(ax,c3,CL3.coastlat,'-','Color',[0.30 0.30 0.30],'LineWidth',0.4); catch, end
title(ax,'(a) Dominance map and the thermal hydrogen belt (\DeltaLCOH=0 contour)');
xlabel(ax,{'Longitude (\circ)';' '}); ylabel(ax,'Latitude (\circ)');
xlim(ax,[min(G.lon) max(G.lon)]); ylim(ax,[min(G.lat) max(G.lat)]); styleAx(ax);
% inset bar: feasibility-aware global area share (matches the headline result)
shareHeat = D.result.dominanceShare;
ax2=nexttile(tl);
b=bar(ax2,[shareHeat;1-shareHeat]*100,'FaceColor','flat'); b.CData=[P.style.colA;P.style.colB];
set(ax2,'XTickLabel',{'Heat/hybrid','Electricity'}); ylabel(ax2,'Share of feasible land (%)');
title(ax2,'(b) Global share'); styleAx(ax2);
idx=find(G.land);
T=table(G.LAT(idx),G.LON(idx),M.dLCOH(idx),double(M.dom(idx)==1),G.DNI(idx), ...
        'VariableNames',{'Lat','Lon','dLCOH_USDkg','HeatWins','DNI_kWhm2yr'});
f=struct('tag','dominance','name','Global dominance map and the thermal hydrogen belt', ...
 'xlabel','Longitude (deg)','ylabel','Latitude (deg)','legend',["Heat/hybrid wins","Electricity wins"],'T',T,'fig',fig, ...
 'caption',S('Fig. 3 (HEADLINE). Global dominance map of the cost difference DeltaLCOH = LCOH_B - LCOH_A. The black line is the thermal-hydrogen belt (DeltaLCOH = 0); the inset bar gives the cos-latitude-weighted share of feasible land won by each route.'), ...
 'explanation',S('Positive DeltaLCOH (warm colours) marks where storing sunlight as heat delivers firm hydrogen more cheaply than storing it as electricity. The zero contour traces a contiguous high-DNI belt across North Africa, Arabia, the US Southwest, the Atacama and Australia.'), ...
 'interpretation',S('The heat/hybrid route is the least-cost path to firm hydrogen across %.0f%% of feasible land by area, defining a contiguous thermal hydrogen belt and redrawing the least-cost geography of the hydrogen economy.',100*shareHeat));
end

%% =========================================================================
% FIGURE 4 - Crossover law: Delta LCOH vs DNI with cost-sensitivity bands
% =========================================================================
function f = fig04_crossover(P,D)
sw=D.sweep;
% sensitivity bands: recompute dLCOH at low/high battery and TES cost
DNI=sw.DNI; n=numel(DNI);
ddC=sw.B-sw.A;
[ddLoBatt,ddHiBatt,ddLoTES,ddHiTES]=deal(nan(n,1));
ob=struct('doC',false,'nGrid',15,'nRefine',11);   % fine grid -> smooth bands
for j=1:n
   KT=0.40+0.40*(DNI(j)-1000)/2300; res=hr_resource(P,28,KT,5.0,DNI(j));
   m=ones(1,7); m(6)=200/250; R=hr_solve_cell(P,res,0.08,m,ob); ddLoBatt(j)=R.B.LCOH-R.A.LCOH;
   m=ones(1,7); m(6)=350/250; R=hr_solve_cell(P,res,0.08,m,ob); ddHiBatt(j)=R.B.LCOH-R.A.LCOH;
   m=ones(1,7); m(2)=20/25;  R=hr_solve_cell(P,res,0.08,m,ob); ddLoTES(j)=R.B.LCOH-R.A.LCOH;
   m=ones(1,7); m(2)=30/25;  R=hr_solve_cell(P,res,0.08,m,ob); ddHiTES(j)=R.B.LCOH-R.A.LCOH;
end
fig=figure('Name','Fig4 Crossover','Position',[50 50 450 400]);  ax=axes(fig); hold(ax,'on');
band=[min(ddLoBatt,ddHiBatt); flipud(max(ddLoBatt,ddHiBatt))];
fill(ax,[DNI;flipud(DNI)],band,P.style.colB,'FaceAlpha',0.15,'EdgeColor','none');
band2=[min(ddLoTES,ddHiTES); flipud(max(ddLoTES,ddHiTES))];
fill(ax,[DNI;flipud(DNI)],band2,P.style.colA,'FaceAlpha',0.15,'EdgeColor','none');
plot(ax,DNI,ddC,'k-','LineWidth',2.2);
yline(ax,0,'k--','LineWidth',1.0);
if ~isnan(D.result.DNIstar), xline(ax,D.result.DNIstar,':','Color',[0.3 0.3 0.3],'LineWidth',1.5,'Label','DNI^{*}'); end
xlabel(ax,'Annual DNI (kWh m^{-2} yr^{-1})'); ylabel(ax,'\DeltaLCOH = LCOH_B - LCOH_A (USD kg^{-1})');
title(ax,'Crossover law: heat-route advantage vs solar resource');
legend(ax,{'Battery-cost band','TES-cost band','Central \DeltaLCOH','\DeltaLCOH = 0'},'Location','NE');
styleAx(ax);
T=table(DNI,ddC,ddLoBatt,ddHiBatt,ddLoTES,ddHiTES, ...
   'VariableNames',{'DNI_kWhm2yr','dLCOH_central','dLCOH_battLo','dLCOH_battHi','dLCOH_tesLo','dLCOH_tesHi'});
f=struct('tag','crossover','name','Crossover law (Delta LCOH vs DNI) with cost bands', ...
 'xlabel','Annual DNI (kWh/m2/yr)','ylabel','dLCOH (USD/kg)', ...
 'legend',["Battery-cost band","TES-cost band","Central","zero"],'T',T,'fig',fig, ...
 'caption',S('Fig. 4. The crossover law: heat-route cost advantage DeltaLCOH versus annual DNI, with sensitivity bands for battery cost (200-350 USD/kWh) and TES cost (20-30 USD/kWh_th). The break-even DNI* is marked.'), ...
 'explanation',S('The advantage of the heat route grows monotonically with the solar resource. The shaded bands show how the curve shifts when battery and thermal-storage unit costs vary across their literature ranges, indicating the robustness of the ranking.'), ...
 'interpretation',S('A simple, transferable rule of thumb emerges: the heat route is favoured above a break-even DNI of ~%.0f kWh/m2/yr, shifting with storage costs. Cheaper batteries move the break-even up; cheaper TES moves it down.',maxnz(D.result.DNIstar,D.result.DNIfeas)));
end

%% =========================================================================
% FIGURE 5 - Mechanism: firmness premium, exergy breakdown, storage split
% =========================================================================
function f = fig05_mechanism(P,D)
A=D.arch; nA=numel(A);
premA=arrayfun(@(s)s.R.A.firmPremium,A)*100; premB=arrayfun(@(s)s.R.B.firmPremium,A)*100;
names=arrayfun(@(s)string(s.name),A);%names=underscore2latex(names);
fig=figure('Name','Fig5 Mechanism','Position',[50 50 800 600]);  tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
% (a) firmness premium reversal
ax=nexttile(tl); b=bar(ax,[premA(:) premB(:)]); b(1).FaceColor=P.style.colA; b(2).FaceColor=P.style.colB;
set(ax,'XTick',1:nA,'XTickLabel',shortNames(names)); xtickangle(ax,30); 
ylabel(ax,'Firmness premium (%)'); title(ax,'(a) Firmness-premium reversal'); yline(ax,0,'k-');
legend(ax,{'Heat route','Electricity route'},'Location','N','Orientation','horizontal'); styleAx(ax);
% (b) exergy destruction breakdown (Sahara)
k=exemplarIdx(D); exA=A(k).anA.exergy; exB=A(k).anB.exergy;
ax=nexttile(tl);
allcats1=unique(underscore2latex([string(exA.comp_names);string(exB.comp_names)]),'stable');
allcats=unique([string(exA.comp_names);string(exB.comp_names)],'stable');
va=zeros(numel(allcats),1); vb=va;
for i=1:numel(allcats)
  ia=find(string(exA.comp_names)==allcats(i),1); if ~isempty(ia), va(i)=exA.comp_vals(ia); end
  ib=find(string(exB.comp_names)==allcats(i),1); if ~isempty(ib), vb(i)=exB.comp_vals(ib); end
end
b=bar(ax,[va vb]/1e6); b(1).FaceColor=P.style.colA; b(2).FaceColor=P.style.colB;
set(ax,'XTick',1:numel(allcats),'XTickLabel',allcats1); xtickangle(ax,30);
ylabel(ax,'Exergy destruction (GWh yr^{-1})'); title(ax,'(b) Exergy destruction by component');
set(ax,'YScale','log'); ylim([0.1 100])
legend(ax,{'Heat route','Electricity route'},'Location','N','Orientation','horizontal'); styleAx(ax);


A=D.arch; k=exemplarIdx(D);
anA=A(k).anA; anB=A(k).anB; anC=A(k).anC;

xxx=0
% (c) psi comparison
ax=nexttile(tl);
v=[anA.exergy.psi_conv anB.exergy.psi_conv anC.exergy.psi_conv;
   anA.exergy.psi_solar anB.exergy.psi_solar anC.exergy.psi_solar]';
b=bar(ax,v); b(1).FaceColor=[0.4 0.4 0.4]; b(2).FaceColor=[0.75 0.75 0.75];
set(ax,'XTickLabel',{'Heat A','Elec B','Hybrid C'}); ylabel(ax,'Exergy efficiency (-)');
title(ax,'(c) Second-law efficiency'); legend(ax,{'\psi conversion','\psi solar/primary'},'Location','N'); styleAx(ax);



% (d) storage-medium split vs DNI
sw=D.sweep;
ax=nexttile(tl); plot(ax,sw.DNI,sw.sigma*100,'-o','Color',P.style.colC,'MarkerFaceColor',P.style.colC,'LineWidth',1.8);
xlabel(ax,'Annual DNI (kWh m^{-2} yr^{-1})'); ylabel(ax,'Thermal share \sigma_{th} (%)');
title(ax,'(d) Storage-medium split (hybrid)'); ylim(ax,[60 105]); styleAx(ax);
T=table(names(:),premA(:),premB(:),'VariableNames',{'Site','FirmPremium_A_pct','FirmPremium_B_pct'});
T2=table(sw.DNI,sw.sigma*100,'VariableNames',{'DNI_kWhm2yr','SigmaThermal_pct'});
f=struct('tag','mechanism','name','Mechanism: firmness premium, exergy, storage split', ...
 'xlabel','Site / component / DNI','ylabel','% , GWh/yr , %', ...
 'legend',["Heat route","Electricity route"],'T',T,'T2',T2,'fig',fig, ...
 'caption',S('Fig. 5. Why the heat route wins. (a) Firmness premium (firm vs annual-average LCOH) for both routes across the archetype sites; (b) component exergy-destruction breakdown (Sahara exemplar); (c) conversion-chain and primary second-law efficiencies of the three architectures.(d) the cost-optimal thermal share of the hybrid versus DNI.'), ...
 'explanation',S('The firmness premium is the cost increment of imposing 24-h firmness. Because thermal storage is cheap and raises SOEC utilization, the heat route can carry a near-zero or negative firmness premium, whereas batteries make the electricity route premium strongly positive. The exergy map locates the irreversibilities; the split panel shows the hybrid optimum.'), ...
 'interpretation',S('The ranking reverses under firmness: the heat-route premium averages %.0f%% while the electricity-route premium averages +%.0f%%. The dominant irreversibility differs by route (heat: solar collection/Rankine; electricity: the electrolyzer), and the optimal thermal share rises toward 100%% as DNI increases.; The heat route attains a higher conversion-chain exergy efficiency (psi=%.2f) than the electricity route (psi=%.2f); its largest destruction sits in solar collection and the Rankine block, whereas the electricity route loses most exergy in the electrolyzer itself.',mean(premA),mean(premB), anA.exergy.psi_conv,anB.exergy.psi_conv));
end

%% =========================================================================
% FIGURE 6 - Future cost scenarios + Monte-Carlo robustness + Pwin map
% =========================================================================
function f = fig06_future(P,D)
SC=D.scen; MC=D.mc; G=D.grid;
fig=figure('Name','Fig6 Future','Position',[50 50 800 600]);  tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
% (a) scenario mean LCOH
ax=nexttile(tl,1);
mA=mean(SC.LCOH_A,1); mB=mean(SC.LCOH_B,1);
b=bar(ax,[mA;mB]'); b(1).FaceColor=P.style.colA; b(2).FaceColor=P.style.colB;
set(ax,'XTickLabel',cellstr(SC.names)); ylabel(ax,'Mean firm LCOH (USD kg^{-1})');xlabel(ax,'Year');
title(ax,'(a) Cost scenarios'); legend(ax,{'Heat','Electricity'},'Location','northeast'); styleAx(ax);
% (b) MC dominance probability + P10-P90 (yyaxis)
ax=nexttile(tl,2);
yyaxis(ax,'left');
fill(ax,[MC.DNI;flipud(MC.DNI)],[MC.LCOH_A_P10;flipud(MC.LCOH_A_P90)],P.style.colA,'FaceAlpha',0.15,'EdgeColor','none'); hold(ax,'on');
fill(ax,[MC.DNI;flipud(MC.DNI)],[MC.LCOH_B_P10;flipud(MC.LCOH_B_P90)],P.style.colB,'FaceAlpha',0.15,'EdgeColor','none');
plot(ax,MC.DNI,MC.LCOH_A_P50,'-','Color',P.style.colA,'LineWidth',1.8);
plot(ax,MC.DNI,MC.LCOH_B_P50,'-','Color',P.style.colB,'LineWidth',1.8);
ylabel(ax,'LCOH P10-P50-P90 (USD kg^{-1})'); ax.YColor=[0 0 0];
yyaxis(ax,'right');
plot(ax,MC.DNI,MC.Pwin*100,'k--o','LineWidth',1.8,'MarkerFaceColor','k');
ylabel(ax,'Pr[heat route wins] (%)'); ylim(ax,[0 105]); ax.YColor=[0.2 0.2 0.2];
xlabel(ax,'Annual DNI (kWh m^{-2} yr^{-1})'); title(ax,'(b) Monte-Carlo robustness'); styleAx(ax);
% (c) dominance-probability map
ax=nexttile(tl,[1 2]); mapPanel(ax,G,D.maps.Pwin,'(c) Pr[heat route wins]','turbo',[0 1]);
T=table(MC.DNI,MC.LCOH_A_P50,MC.LCOH_B_P50,MC.Pwin*100, ...
   'VariableNames',{'DNI_kWhm2yr','LCOH_A_P50','LCOH_B_P50','Pwin_pct'});
f=struct('tag','future','name','Future cost scenarios and Monte-Carlo robustness', ...
 'xlabel','Scenario / DNI / Longitude','ylabel','LCOH , probability', ...
 'legend',["Heat","Electricity","Pr[heat wins]"],'T',T,'fig',fig, ...
 'caption',S('Fig. 6. Robustness and the future. (a) Mean firm LCOH under 2025/2030/2050 cost projections; (b) Monte-Carlo (M=%d) median LCOH with P10-P90 bands (left axis) and the probability the heat route wins (right axis) versus DNI; (c) the per-cell dominance-probability map.',MC.M), ...
 'explanation',S('Capital-cost learning is applied per technology and scenario; uncertainty is propagated by Latin-hypercube sampling over component costs and WACC. The dominance probability and percentile bands convert the central claim into a probabilistic statement.'), ...
 'interpretation',S('The heat-route advantage persists under future cost trajectories and is robust to parameter uncertainty: across the high-DNI ladder the probability the heat route wins reaches up to %.0f%% (mean %.0f%%), supporting a probabilistic dominance claim rather than a point estimate.',100*max(MC.Pwin),100*mean(MC.Pwin)));
end

%% =========================================================================
% FIGURE 7 - SOEC electrochemistry: V-i curve + overpotentials + efficiency
% =========================================================================
function f = fig07_soec(P,D)
VI=D.VI;
fig=figure('Name','Fig7 SOEC','Position',[50 50 450 600]); tl=tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
% (a) V-i with stacked overpotentials
ax=nexttile(tl); hold(ax,'on');
base=VI.Vrev;
area(ax,VI.i,[base VI.eta_act VI.eta_ohm VI.eta_conc],'LineStyle','none');
plot(ax,VI.i,VI.Vcell,'k-','LineWidth',2.2);
yline(ax,P.const.Vtn0,'k:','LineWidth',1.0);ylim([0 2])
xlabel(ax,{'Current density (A cm^{-2})';' '}); ylabel(ax,'Cell voltage (V)');
title(ax,'(a) SOEC polarization and overpotentials');
legend(ax,{'V_{rev}','\eta_{act}','\eta_{ohm}','\eta_{conc}','V_{cell}'},'Location','northwest','NumColumns',3); styleAx(ax);
% (b) SEC and LHV efficiency vs i (yyaxis)
ax=nexttile(tl);
yyaxis(ax,'left'); plot(ax,VI.i,VI.SECel,'-o','Color',P.style.colB,'LineWidth',1.8,'MarkerFaceColor',P.style.colB); ylim([25 40]); hold(ax,'on');
plot(ax,VI.i,VI.SECtot,'-s','Color',P.style.colA,'LineWidth',1.8,'MarkerFaceColor',P.style.colA);
ylabel(ax,'Specific energy (kWh kg^{-1})'); ax.YColor=[0 0 0];
yyaxis(ax,'right'); plot(ax,VI.i,VI.etaLHV*100,'k--','LineWidth',1.8);ylim([75 90]);
ylabel(ax,'LHV efficiency (%)'); ax.YColor=[0.2 0.2 0.2];
xlabel(ax,'Current density (A cm^{-2})'); title(ax,'(b) Energy demand and efficiency');
legend(ax,{'SEC electrical','SEC total','\eta_{LHV}'},'Location','SE'); styleAx(ax);
T=table(VI.i,VI.Vrev,VI.Vcell,VI.eta_act,VI.eta_ohm,VI.eta_conc,VI.SECel,VI.SECtot,VI.etaLHV, ...
  'VariableNames',{'i_Acm2','Vrev','Vcell','eta_act','eta_ohm','eta_conc','SEC_el','SEC_tot','eta_LHV'});
f=struct('tag','soec','name','SOEC electrochemistry: polarization & efficiency', ...
 'xlabel','Current density (A/cm2)','ylabel','Voltage / SEC / efficiency', ...
 'legend',["Vrev","eta_act","eta_ohm","eta_conc","Vcell"],'T',T,'fig',fig, ...
 'caption',S('Fig. 7. SOEC behaviour. (a) Cell voltage versus current density decomposed into reversible, activation, ohmic and concentration contributions (the dotted line is the thermoneutral voltage); (b) electrical and total specific energy consumption (left) and LHV efficiency (right).'), ...
 'explanation',S('The Butler-Volmer activation, Arrhenius ohmic and Nernstian concentration overpotentials (Eqs 23-29) build the polarization curve. Operating below the thermoneutral voltage keeps the cell endothermic, so part of the energy is drawn as heat - exactly the lever exploited by the heat route.'), ...
 'interpretation',S('At the chosen operating point the cell needs only ~%.0f kWh/kg of electricity (vs ~52 for LT electrolysis) at an LHV efficiency near %.0f%%; raising current density increases overpotentials and electrical SEC, defining the efficiency-throughput trade-off.',interp1(VI.i,VI.SECel,0.5),100*max(VI.etaLHV)));
end

%% =========================================================================
% FIGURE 8 - Energy-flow waterfall (heat route vs electricity route)
% =========================================================================
function f = fig08_energyflow(P,D)
A=D.arch; k=exemplarIdx(D); enA=A(k).anA.energy; enB=A(k).anB.energy;
% normalise per kg H2 (kWh/kg)
H2A=A(k).R.A.H2_act; H2B=A(k).R.B.H2_act;
% Heat route chain: solar_inc -> absorbed -> field -> delivered -> H2(LHV)
stepsA = [enA.solar_inc, enA.solar_abs, enA.field_out, enA.delivered, enA.H2_LHV_yr]/H2A;
labA={'Solar incident','Absorbed','Field out','To SOEC','H_2 (LHV)'};
stepsB = [enB.gen_total, enB.gen_total-enB.curtail, enB.delivered, enB.H2_LHV_yr]/H2B;
labB={'PV/wind gen','After curtail','To LT_E_L','H_2 (LHV)'};
fig=figure('Name','Fig8 Energy flow','Position',[50 50 450 800]); tl=tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl); b=bar(ax,stepsA,'FaceColor',P.style.colA); set(ax,'XTickLabel',labA); xtickangle(ax,25);
ylabel(ax,'Energy per kg H_2 (kWh kg^{-1})'); title(ax,'(a) Heat route energy cascade'); styleAx(ax);
ax=nexttile(tl); b=bar(ax,stepsB,'FaceColor',P.style.colB); set(ax,'XTickLabel',labB); xtickangle(ax,25);
ylabel(ax,'Energy per kg H_2 (kWh kg^{-1})'); title(ax,'(b) Electricity route energy cascade'); styleAx(ax);
T=table(["solar_incident";"absorbed";"field_out";"to_SOEC";"H2_LHV"],stepsA(:), ...
   'VariableNames',{'Stage_A','kWh_per_kg'});
f=struct('tag','energyflow','name','Energy cascade per kg H2 (both routes)', ...
 'xlabel','Conversion stage','ylabel','Energy per kg H2 (kWh/kg)','legend',["Heat","Electricity"],'T',T,'fig',fig, ...
 'caption',S('Fig. 8. Energy cascade per kilogram of hydrogen for (a) the heat route and (b) the electricity route (%s exemplar).',A(k).name), ...
 'explanation',S('Bars trace the energy required at each stage, normalized to the delivered hydrogen. Optical/receiver losses dominate the heat-route front end; curtailment and conversion losses shape the electricity-route cascade.'), ...
 'interpretation',S('The heat route delivers a kilogram of hydrogen from ~%.0f kWh of incident sunlight; the electricity route needs ~%.0f kWh of generated electricity. The narrowing of the cascade reveals where useful energy is lost and where each route can be improved.',stepsA(1),stepsB(1)));
end

%% =========================================================================
% FIGURE 9 - Exergy (2nd law) destruction map per architecture
% =========================================================================
function f = fig09_exergy(P,D)
%%
A=D.arch; k=exemplarIdx(D);
anA=A(k).anA; anB=A(k).anB; anC=A(k).anC;
fig=figure('Name','Fig9 Exergy','Position',[50 50 450 800]); tl=tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
% (a) destruction bars
% ax=nexttile(tl); hold(ax,'on');
% plotDestr(ax,anA.exergy,P.style.colA,1); plotDestr(ax,anB.exergy,P.style.colB,2);set(ax,'YScale','log'),ylim([0.1 100])
% ylabel(ax,'Exergy destruction (GWh yr^{-1})'); title(ax,'(a) Component exergy destruction');
% xlabel(ax,'Component'); styleAx(ax);

% (b) exergy destruction breakdown (Sahara)
k=exemplarIdx(D); exA=A(k).anA.exergy; exB=A(k).anB.exergy;
ax=nexttile(tl);
allcats1=unique(underscore2latex([string(exA.comp_names);string(exB.comp_names)]),'stable');
allcats=unique([string(exA.comp_names);string(exB.comp_names)],'stable');
va=zeros(numel(allcats),1); vb=va;
for i=1:numel(allcats)
  ia=find(string(exA.comp_names)==allcats(i),1); if ~isempty(ia), va(i)=exA.comp_vals(ia); end
  ib=find(string(exB.comp_names)==allcats(i),1); if ~isempty(ib), vb(i)=exB.comp_vals(ib); end
end
b=bar(ax,[va vb]/1e6); b(1).FaceColor=P.style.colA; b(2).FaceColor=P.style.colB;
set(ax,'XTick',1:numel(allcats),'XTickLabel',allcats1); xtickangle(ax,30);
ylabel(ax,'Exergy destruction (GWh yr^{-1})'); title(ax,'(a) Exergy destruction by component');
set(ax,'YScale','log'); ylim([0.1 100])
legend(ax,{'Heat route','Electricity route'},'Location','N','Orientation','horizontal'); styleAx(ax);


% (b) psi comparison
ax=nexttile(tl);
v=[anA.exergy.psi_conv anB.exergy.psi_conv anC.exergy.psi_conv;
   anA.exergy.psi_solar anB.exergy.psi_solar anC.exergy.psi_solar]';
b=bar(ax,v); b(1).FaceColor=[0.4 0.4 0.4]; b(2).FaceColor=[0.75 0.75 0.75];
set(ax,'XTickLabel',{'Heat A','Elec B','Hybrid C'}); ylabel(ax,'Exergy efficiency (-)');
title(ax,'(b) Second-law efficiency'); 
legend(ax,{'\psi conversion','\psi solar/primary'},'Location','N'); styleAx(ax);

T=table(string(anA.exergy.comp_names),anA.exergy.comp_vals/1e6, ...
   'VariableNames',{'Component_A','ExergyDestruction_GWhyr'});
f=struct('tag','exergy','name','Exergy destruction map and second-law efficiency', ...
 'xlabel','Component / architecture','ylabel','Exergy destruction / efficiency', ...
 'legend',["Heat route","Electricity route"],'T',T,'fig',fig, ...
 'caption',S('Fig. 9. Exergy analysis (%s exemplar). (a) Annual exergy destruction by component for the heat and electricity routes; (b) conversion-chain and primary second-law efficiencies of the three architectures.',A(k).name), ...
 'explanation',S('Component exergy destruction is obtained from steady exergy balances (Eq 61) with solar exergy from the Petela factor. The bars localize irreversibility; psi quantifies how much of the input exergy survives as chemical exergy of hydrogen.'), ...
 'interpretation',S('The heat route attains a higher conversion-chain exergy efficiency (psi=%.2f) than the electricity route (psi=%.2f); its largest destruction sits in solar collection and the Rankine block, whereas the electricity route loses most exergy in the electrolyzer itself.',anA.exergy.psi_conv,anB.exergy.psi_conv));
%%
end

%% =========================================================================
% FIGURE 10 - Entropy generation per component + entropy-generation number
% =========================================================================
function f = fig10_entropy(P,D)
A=D.arch; k=exemplarIdx(D); entA=A(k).anA.entropy; entB=A(k).anB.entropy;
fig=figure('Name','Fig10 Entropy','Position',[50 50 450 400]); ax=axes(fig);
cats1=unique(underscore2latex([string(entA.comp_names);string(entB.comp_names)]),'stable');
cats=unique([string(entA.comp_names);string(entB.comp_names)],'stable');
va=zeros(numel(cats),1); vb=va;
for i=1:numel(cats)
  ia=find(string(entA.comp_names)==cats(i),1); if ~isempty(ia), va(i)=entA.Sgen_comp(ia); end
  ib=find(string(entB.comp_names)==cats(i),1); if ~isempty(ib), vb(i)=entB.Sgen_comp(ib); end
end
yyaxis(ax,'left'); b=bar(ax,[va vb]); b(1).FaceColor=P.style.colA; b(2).FaceColor=P.style.colB;
ylabel(ax,'Entropy generation rate (kW K^{-1})'); ax.YColor=[0 0 0];
set(ax,'XTick',1:numel(cats),'XTickLabel',cats1); xtickangle(ax,25);set(ax,'YScale','log');ylim([100 200000])

yyaxis(ax,'right');
plot(ax,1:numel(cats),cumsum(va)/sum(va)*100,'k--o','LineWidth',1.6);
ylabel(ax,'Cumulative share, heat route (%)'); ylim(ax,[0 105]); ax.YColor=[0.2 0.2 0.2];set(ax,'YScale','log');ylim([0.1 200])
title(ax,'Entropy generation by component (Gouy-Stodola)'); xlabel(ax,'Component'); styleAx(ax);
lgd = legend(ax,{'Heat route','Electricity route','Cumulative (heat)'},'Location','east');
pos = lgd.Position;
pos(2) = pos(2) + 0.2;   % move upward
lgd.Position = pos;
T=table(cats(:),va,vb,'VariableNames',{'Component','Sgen_A_kWK','Sgen_B_kWK'});
f=struct('tag','entropy','name','Entropy generation by component', ...
 'xlabel','Component','ylabel','Entropy generation (kW/K)', ...
 'legend',["Heat route","Electricity route"],'T',T,'fig',fig, ...
 'caption',S('Fig. 10. Entropy-generation analysis (%s). Component entropy-generation rates from the Gouy-Stodola theorem (S_gen = Ex_dest/T0), with the cumulative share for the heat route on the right axis.',A(k).name), ...
 'explanation',S('Entropy generation is proportional to exergy destruction; ranking components by S_gen identifies the dominant irreversibilities that limit second-law performance and guides where design effort yields the most.'), ...
 'interpretation',S('The dominant entropy source is the %s for the heat route and the %s for the electricity route; targeting it offers the largest thermodynamic improvement, while the entropy-generation number quantifies overall irreversibility.',entA.dominant,entB.dominant));
end

%% =========================================================================
% FIGURE 11 - First- vs second-law efficiency across archetypes
% =========================================================================
function f = fig11_efficiency(P,D)
A=D.arch; n=numel(A); names=arrayfun(@(s)string(s.name),A);%names=underscore2latex(names);
e1A=arrayfun(@(s)s.anA.eff.eta_I,A); e2A=arrayfun(@(s)s.anA.eff.eta_II,A);
e1B=arrayfun(@(s)s.anB.eff.eta_I,A); e2B=arrayfun(@(s)s.anB.eff.eta_II,A);
sthA=arrayfun(@(s)s.anA.eff.eta_STH,A);
fig=figure('Name','Fig11 Efficiency','Position',[50 50 600 500]); ax=axes(fig);
yyaxis(ax,'left');
b=bar(ax,[e1A(:) e2A(:) e1B(:) e2B(:)]);
b(1).FaceColor=P.style.colA; b(2).FaceColor=brighten(P.style.colA,0.4);
b(3).FaceColor=P.style.colB; b(4).FaceColor=brighten(P.style.colB,0.4);
ylabel(ax,'Conversion efficiency (-)'); ax.YColor=[0 0 0]; ylim(ax,[0 1.05]);

yyaxis(ax,'right'); plot(ax,1:n,sthA*100,'k--o','LineWidth',1.8,'MarkerFaceColor','k');
ylabel(ax,'Solar-to-H_2 efficiency, heat route (%)'); ax.YColor=[0.2 0.2 0.2];ylim(ax,[20 32]);
set(ax,'XTick',1:n,'XTickLabel',shortNames(names)); xtickangle(ax,30);
title(ax,'First- and second-law efficiencies by site'); xlabel(ax,'Site');
legend(ax,{'\eta_I^A','\eta_{II}^A','\eta_I^B','\eta_{II}^B','\eta_{STH}^A'},'Location','north','Orientation','horizontal');
styleAx(ax);
T=table(names(:),e1A(:),e2A(:),e1B(:),e2B(:),sthA(:), ...
  'VariableNames',{'Site','etaI_A','etaII_A','etaI_B','etaII_B','etaSTH_A'});
f=struct('tag','efficiency','name','First- vs second-law efficiencies by site', ...
 'xlabel','Site','ylabel','Efficiency', ...
 'legend',["etaI_A","etaII_A","etaI_B","etaII_B","etaSTH_A"],'T',T,'fig',fig, ...
 'caption','Fig. 11. First-law (energy) and second-law (exergy) conversion efficiencies of the heat and electricity routes across the archetype sites, with the heat-route solar-to-hydrogen efficiency on the right axis.', ...
 'explanation','For each site the four bars give the energy and exergy efficiencies of both routes; the dashed line is the overall solar-to-hydrogen efficiency of the heat route, which folds in the solar-collection step.', ...
 'interpretation',S('The heat route is consistently superior on both laws (mean eta_I=%.2f, eta_II=%.2f) versus the electricity route (mean eta_I=%.2f, eta_II=%.2f); solar-to-hydrogen efficiency rises with site resource quality.',mean(e1A),mean(e2A),mean(e1B),mean(e2B)));
end

%% =========================================================================
% FIGURE 12 - Dimensionless analysis (classical + innovative)
% =========================================================================
function f = fig12_dimensionless(P,D)
A=D.arch; k=exemplarIdx(D); nd=A(k).anA.nd;
classical = {'Re_{htf}',nd.Re_htf;'Pr',nd.Pr_htf;'Nu',nd.Nu_htf;'Pe',nd.Pe_htf; ...
             'Gr',nd.Gr;'Ra',nd.Ra;'Bi',nd.Bi;'Fo',nd.Fo;'Ja',nd.Ja;'Ste',nd.Ste};
innov = {'Heat leverage \Lambda',nd.HeatLeverage;'Elec. substitution',nd.ElecSubstitution; ...
         'Exergy quality',nd.ExergyQuality;'\sigma_{thermal}',A(k).R.C.storage_thermal_frac; ...
         'Solar multiple',nd.SolarMultiple;'Storage number',nd.StorageNumber; ...
         'Capacity factor',nd.CapacityFactor;'Exergetic sustain.',nd.ExergSustain};
fig=figure('Name','Fig12 Dimensionless','Position',[50 50 450 800]); tl=tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl); vals=cell2mat(classical(:,2));
b=bar(ax,vals,'FaceColor',[0.30 0.5 0.7]); set(ax,'YScale','log');
set(ax,'XTick',1:size(classical,1),'XTickLabel',classical(:,1)); xtickangle(ax,35);
ylabel(ax,'Value (log scale)'); title(ax,'(a) Classical dimensionless groups'); styleAx(ax);
ax=nexttile(tl); vals2=cell2mat(innov(:,2));
b=bar(ax,vals2,'FaceColor',P.style.colC);
set(ax,'XTick',1:size(innov,1),'XTickLabel',innov(:,1)); xtickangle(ax,35);
ylabel(ax,'Value (-)'); title(ax,'(b) Innovative route-specific groups'); styleAx(ax);
T=table([string(classical(:,1));string(innov(:,1))],[cell2mat(classical(:,2));cell2mat(innov(:,2))], ...
   'VariableNames',{'Group','Value'});
f=struct('tag','dimensionless','name','Dimensionless analysis (classical + innovative)', ...
 'xlabel','Dimensionless group','ylabel','Value','legend',[],'T',T,'fig',fig, ...
 'caption',S('Fig. 12. Dimensionless characterization of the heat route (%s). (a) Classical transport/thermal groups (Reynolds, Prandtl, Nusselt, Peclet, Grashof, Rayleigh, Biot, Fourier, Jakob, Stefan); (b) innovative route-specific groups defined in this work.',A(k).name), ...
 'explanation',S('The classical groups characterize molten-salt receiver convection (Re,Pr,Nu,Pe), receiver natural-convection/radiation losses (Gr,Ra), TES transient conduction (Bi,Fo) and steam raising (Ja,Ste). The innovative groups - heat leverage, electrical substitution, exergy quality, storage-medium split, solar multiple, storage number and exergetic sustainability index - compress the techno-economic mechanism into transferable numbers.'), ...
 'interpretation',S('The receiver operates in the fully-turbulent regime (Re~%.0e), TES is thermally thin (Bi=%.2f), and the heat-leverage group Lambda=%.2f together with the electrical-substitution number (%.2f) and exergetic sustainability index (%.1f) provide a compact, physically-grounded explanation of the heat-route advantage.',nd.Re_htf,nd.Bi,nd.HeatLeverage,nd.ElecSubstitution,nd.ExergSustain));
end

%% =========================================================================
% FIGURE 13 - Diurnal/seasonal dispatch of the heat route (TES operation)
% =========================================================================
function f = fig13_dispatch(P,D)
A=D.arch; k=exemplarIdx(D); H=A(k).R.A.hourly;
fig=figure('Name','Fig13 Dispatch','Position',[50 50 450 1000]); tl=tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
mo=1:12; hr=0:23;
ax=nexttile(tl); imagesc(ax,mo,hr,H.Qfield); set(ax,'YDir','normal'); colorbar(ax);
xlabel(ax,'Month'); ylabel(ax,'Hour'); title(ax,'(a) CSP field output (kW_{th})'); colormap(ax,'turbo'); styleAx(ax);
ax=nexttile(tl); imagesc(ax,mo,hr,H.soc); set(ax,'YDir','normal'); colorbar(ax);
xlabel(ax,'Month'); ylabel(ax,'Hour'); title(ax,'(b) TES state of charge (kWh_{th})'); colormap(ax,'turbo'); styleAx(ax);
% (c) representative-day profile (annual mean day): field, load, SOC
ax=nexttile(tl);
fieldDay=mean(H.Qfield,2); socDay=mean(H.soc,2); loadDay=H.Lth*ones(24,1);
yyaxis(ax,'left'); plot(ax,hr,fieldDay,'-','Color',P.style.colA,'LineWidth',1.8); hold(ax,'on');
plot(ax,hr,loadDay,'k--','LineWidth',1.5); ylabel(ax,'Power (kW_{th})'); ax.YColor=[0 0 0]; ylim([0 2.5e4])

yyaxis(ax,'right'); area(ax,hr,socDay,'FaceColor',P.style.colC,'FaceAlpha',0.25,'EdgeColor',P.style.colC);
ylabel(ax,'TES SOC (kWh_{th})'); ax.YColor=P.style.colC;
xlabel(ax,'Hour of day'); title(ax,'(c) Mean-day dispatch'); xlim(ax,[0 23]);
legend(ax,{'Field','Firm load','TES SOC'},'Location','NW','NumColumns',2,'Box','off'); styleAx(ax);

T=table(hr(:),fieldDay,loadDay,socDay,'VariableNames',{'Hour','FieldOut_kWth','FirmLoad_kWth','TES_SOC_kWhth'});
f=struct('tag','dispatch','name','Diurnal/seasonal heat-route dispatch (TES)', ...
 'xlabel','Hour / Month','ylabel','Power / state of charge', ...
 'legend',["Field","Firm load","TES SOC"],'T',T,'fig',fig, ...
 'caption',S('Fig. 13. Heat-route dispatch (%s). Hour-by-month heatmaps of (a) CSP field thermal output and (b) molten-salt TES state of charge, with (c) the mean-day balance of field output, firm thermal load and storage.',A(k).name), ...
 'explanation','Thermal energy is collected during the day, charged into the two-tank molten-salt store, and discharged overnight to hold the electrolyzer at a constant firm load - the diurnal storage cycle that underpins firmness.', ...
 'interpretation','The TES fills during solar hours and drains overnight, sustaining firm output around the clock; the seasonal heatmaps show how winter days draw the store deeper, which sets the storage-hours sizing.');
end

%% =========================================================================
% FIGURE 14 - Economic structure: capex shares, LCOH build-up, abatement
% =========================================================================
function f = fig14_economic(P,D)
A=D.arch; k=exemplarIdx(D); R=A(k).R;
fig=figure('Name','Fig14 Economic','Position',[50 50 450 1000]); tl=tiledlayout(fig,3,1,'Padding','compact','TileSpacing','compact');
% (a) capex shares
ax=nexttile(tl);
cbA=R.A.capexBreak; nmA=fieldnames(cbA); vA=cellfun(@(x)cbA.(x),nmA);
cbB=R.B.capexBreak; nmB=fieldnames(cbB); vB=cellfun(@(x)cbB.(x),nmB);
mx=max(numel(vA),numel(vB)); M=zeros(2,mx); M(1,1:numel(vA))=vA/1e6; M(2,1:numel(vB))=vB/1e6;
b=bar(ax,M,'stacked'); set(ax,'XTickLabel',{'Heat A','Elec B'}); ylabel(ax,'CAPEX (million USD)');
title(ax,'(a) Capital cost structure'); styleAx(ax); ylim([0 60])
legend(ax,[nmA;repmat({''},mx-numel(nmA),1)],'Location','north','Orientation','horizontal','Interpreter','none');
% (b) LCOH build-up (annualized cost components per kg)
ax=nexttile(tl);
H2=R.A.H2_act;
compA=[R.A.Cann_capex R.A.opex R.A.repl R.A.water]/H2;
b=bar(ax,compA,'FaceColor',P.style.colA); set(ax,'XTickLabel',{'CRF\cdotCAPEX','OPEX','Replace','Water'}); xtickangle(ax,20);
ylabel(ax,'LCOH component (USD kg^{-1})'); title(ax,'(b) Heat-route LCOH build-up'); styleAx(ax);
% (c) CO2 abatement cost
ax=nexttile(tl);
ab=[A(k).anA.econ.CO2_abatement_cost A(k).anB.econ.CO2_abatement_cost];
b=bar(ax,ab,'FaceColor','flat'); b.CData=[P.style.colA;P.style.colB];
set(ax,'XTickLabel',{'Heat A','Elec B'}); ylabel(ax,'CO_2 abatement cost (USD tCO_2^{-1})');
title(ax,'(c) Carbon abatement cost'); styleAx(ax);
T=table(string(nmA),vA/1e6,'VariableNames',{'Component_A','CAPEX_MUSD'});
f=struct('tag','economic','name','Economic structure: CAPEX, LCOH build-up, abatement', ...
 'xlabel','Component / route','ylabel','Cost', 'legend',string(nmA(:))','T',T,'fig',fig, ...
 'caption',S('Fig. 14. Techno-economics (%s). (a) Capital-cost structure of the two routes; (b) build-up of heat-route LCOH from annualized capital, O&M, stack replacement and water; (c) CO2 abatement cost relative to grey (SMR) hydrogen.',A(k).name), ...
 'explanation','Capital expenditure is decomposed by component (Eq 51); LCOH follows from the capital-recovery factor plus operating, replacement and water costs (Eqs 52-56). Abatement cost compares the green premium with the avoided SMR emissions.', ...
 'interpretation',S('The heat-route capital is dominated by the solar field/block and SOEC, and its lower LCOH translates to a CO2 abatement cost of ~%.0f USD/tCO2 versus ~%.0f for the electricity route, a decisive economic and climate advantage.',A(k).anA.econ.CO2_abatement_cost,A(k).anB.econ.CO2_abatement_cost));
end

%% =========================================================================
% FIGURE 15 - Environmental indicators across sites (yyaxis)
% =========================================================================
function f = fig15_environment(P,D)
A=D.arch; n=numel(A); names=arrayfun(@(s)string(s.name),A); %names=underscore2latex(names);
co2=arrayfun(@(s)s.anA.env.CO2_mitig_tyr,A)/1000;     % ktCO2/yr
water=arrayfun(@(s)s.anA.env.water_use_tyr,A)/1000;   % kt/yr
land=arrayfun(@(s)s.anA.env.land_per_kg,A);           % m2/kg
fig=figure('Name','Fig15 Environment','Position',[50 50 600 500]); ax=axes(fig);
yyaxis(ax,'left'); b=bar(ax,[co2(:) water(:)]); b(1).FaceColor=P.style.colC; b(2).FaceColor=[0.2 0.5 0.8];
ylabel(ax,'CO_2 avoided (ktCO_2/yr) ; Water (kt/yr)'); ax.YColor=[0 0 0];ylim([0 10])

yyaxis(ax,'right'); plot(ax,1:n,land,'k--o','LineWidth',1.8,'MarkerFaceColor','k');
ylabel(ax,'Land use (m^2 per kg H_2)'); ax.YColor=[0.2 0.2 0.2];ylim([0 0.5])
set(ax,'XTick',1:n,'XTickLabel',shortNames(names)); xtickangle(ax,30);
title(ax,'Environmental indicators (heat route) by site');
legend(ax,{'CO_2 avoided','Water use','Land per kg'},'Location','north','Orientation','horizontal'); styleAx(ax);
T=table(names(:),co2(:),water(:),land(:),'VariableNames',{'Site','CO2_avoided_ktyr','Water_ktyr','Land_m2perkg'});
f=struct('tag','environment','name','Environmental indicators by site', ...
 'xlabel','Site','ylabel','CO2 / water / land','legend',["CO2 avoided","Water","Land/kg"],'T',T,'fig',fig, ...
 'caption','Fig. 15. Environmental indicators of the heat route by site: avoided CO2 versus grey hydrogen and feed-water demand (left axis), and land use per kilogram of hydrogen (right axis).', ...
 'explanation','Avoided emissions use the SMR carbon intensity; water is the process+stoichiometric demand; land scales with the solar field aperture. Different ranges are shown on dual axes for legibility.', ...
 'interpretation',S('Each plant avoids on the order of %.0f ktCO2/yr against grey hydrogen at modest water (%.1f kt/yr) and land (%.2f m2/kg) intensity, situating the heat route favourably on the water-energy-land nexus.',mean(co2),mean(water),mean(land)));
end

%% =========================================================================
% FIGURE 16 - Tornado sensitivity of LCOH and the heat-route advantage
% =========================================================================
function f = fig16_tornado(P,D)
% Tornado of the DECISION metric DeltaLCOH = LCOH_B - LCOH_A (the heat-route
% advantage). Every cost matters here: CSP/TES/SOEC act through route A, while
% PV/wind/battery/LT act through route B - unlike an LCOH_A-only tornado where
% the electricity-route costs would (correctly) show zero effect.
T0=D.tornado; names=string(T0.names); n=numel(names);
base=T0.dd0;
lo=T0.dd_lo-base; hi=T0.dd_hi-base;
swing=abs(hi-lo); [~,ord]=sort(swing,'ascend');
fig=figure('Name','Fig16 Tornado','Position',[50 50 700 400]); ax=axes(fig); hold(ax,'on');
for i=1:n
   yi=i; a=lo(ord(i)); b=hi(ord(i));
   patch(ax,[min(a,b) max(a,b) max(a,b) min(a,b)],[yi-0.35 yi-0.35 yi+0.35 yi+0.35], ...
         P.style.colC,'FaceAlpha',0.85,'EdgeColor','k');
end
xline(ax,0,'k-','LineWidth',1.0);
set(ax,'YTick',1:n,'YTickLabel',names(ord));
xlabel(ax,'\Delta(LCOH_B - LCOH_A) from base (USD kg^{-1})');
title(ax,S('Tornado: sensitivity of the heat-route advantage (base \\DeltaLCOH = %.2f USD/kg)',base)); styleAx(ax);
Tt=table(names(:),T0.dd_lo(:),T0.dd_hi(:),T0.LA_lo(:),T0.LA_hi(:),T0.LB_lo(:),T0.LB_hi(:), ...
   'VariableNames',{'Parameter','dLCOH_low','dLCOH_high','LCOH_A_low','LCOH_A_high','LCOH_B_low','LCOH_B_high'});
f=struct('tag','tornado','name','Tornado sensitivity of the heat-route advantage', ...
 'xlabel','Delta(LCOH_B-LCOH_A) from base (USD/kg)','ylabel','Parameter','legend',[],'T',Tt,'fig',fig, ...
 'caption',S('Fig. 16. Local one-at-a-time sensitivity (tornado) of the heat-route ADVANTAGE DeltaLCOH = LCOH_B - LCOH_A to the principal techno-economic parameters at a high-DNI site (base DeltaLCOH = %.2f USD/kg). CSP/TES/SOEC costs act through the heat route; PV/wind/battery/LT costs through the electricity route.',base), ...
 'explanation','Each bar spans the change in the cost gap when a single parameter is moved across its literature range with all others fixed; bars are ranked by influence. Unlike a heat-route-only LCOH tornado, every component cost has an effect because it shifts one of the two competing routes.', ...
 'interpretation',S('The heat-route advantage is most sensitive to %s and the cost of capital; cheaper batteries and electrolyzers narrow the gap (they help the electricity route), while cheaper CSP/TES widen it - all retain a positive advantage across the ranges.',names(ord(end))));
end

%% =========================================================================
% FIGURE 17 - Monte-Carlo LCOH distributions and dominance probability
% =========================================================================
function f = fig17_montecarlo(P,D)
MC=D.mc; jsel=[1 3 numel(MC.DNI)]; jsel=unique(min(jsel,numel(MC.DNI)));
fig=figure('Name','Fig17 MonteCarlo','Position',[50 50 450 800]); tl=tiledlayout(fig,2,1,'Padding','compact','TileSpacing','compact');
ax=nexttile(tl); hold(ax,'on');
grp=[]; dat=[]; lab={};
for jj=1:numel(jsel)
   j=jsel(jj);
   dat=[dat; MC.LCOH_A_all(:,j); MC.LCOH_B_all(:,j)];
   grp=[grp; (2*jj-1)*ones(MC.M,1); (2*jj)*ones(MC.M,1)];
   lab{2*jj-1}=sprintf('A %d',round(MC.DNI(j))); lab{2*jj}=sprintf('B %d',round(MC.DNI(j)));
end
try
   boxchart(ax,grp,dat);
catch
   boxplot(ax,dat,grp);
end
set(ax,'XTick',1:numel(lab),'XTickLabel',lab); xtickangle(ax,30);
ylabel(ax,'Firm LCOH (USD kg^{-1})'); xlabel(ax,'Route @ DNI (kWh m^{-2} yr^{-1})');
title(ax,{'(a) Monte-Carlo LCOH distributions';' '}); styleAx(ax);
ax=nexttile(tl); hold(ax,'on');
if isfield(MC,'Pcheaper')
  plot(ax,MC.DNI,MC.Pcheaper*100,'--','Color',[0.5 0.5 0.5],'LineWidth',1.5);
end
plot(ax,MC.DNI,MC.Pwin*100,'-o','Color',P.style.colA,'LineWidth',2,'MarkerFaceColor',P.style.colA);
xlabel(ax,'Annual DNI (kWh m^{-2} yr^{-1})'); ylabel(ax,'Pr[heat route wins] (%)'); ylim(ax,[0 105]);
if isfield(D,'result') && ~isnan(D.result.DNIfeas), xline(ax,D.result.DNIfeas,':','Color',[0.3 0.3 0.3],'Label','firm-feasible','LabelVerticalAlignment','bottom'); end
title(ax,'(b) Dominance probability (firm-feasible & cheaper)');
legend(ax,{'Pr[cheaper] (any reliability)','Pr[heat wins] (firm-feasible)'},'Location','southeast'); styleAx(ax);
T=table(MC.DNI,MC.LCOH_A_P10,MC.LCOH_A_P50,MC.LCOH_A_P90,MC.LCOH_B_P10,MC.LCOH_B_P50,MC.LCOH_B_P90,MC.Pwin*100, ...
  'VariableNames',{'DNI','A_P10','A_P50','A_P90','B_P10','B_P50','B_P90','Pwin_pct'});
f=struct('tag','montecarlo','name','Monte-Carlo LCOH distributions & dominance probability', ...
 'xlabel','Route@DNI / DNI','ylabel','LCOH / probability','legend',["Pr cheaper","Pr heat wins"],'T',T,'fig',fig, ...
 'caption',S('Fig. 17. Monte-Carlo uncertainty (M=%d, Latin-hypercube over costs and WACC). (a) Firm-LCOH distributions for both routes at selected DNI; (b) probability the heat route is firm-feasible AND cheaper (solid) versus merely cheaper ignoring feasibility (dashed), against DNI.',MC.M), ...
 'explanation','Parameter uncertainty is propagated through the full optimization. The dominance probability is feasibility-aware: at low DNI the heat route cannot hold a firm 24-h output (reliability below the floor) so it cannot win even when its nominal LCOH is lower (dashed line).', ...
 'interpretation',S('Dominance probability rises from ~0 below the firm-feasibility threshold (~%.0f kWh/m2/yr) to ~%.0f%% across the high-DNI belt; the gap between the dashed and solid curves is exactly the firmness constraint biting at low resource.',D.result.DNIfeas,100*max(MC.Pwin)));
end

%% =========================================================================
% FIGURE 18 - Storage-medium split frontier and hybrid sizing vs DNI
% =========================================================================
function f = fig18_split(P,D)
sw=D.sweep;
fig=figure('Name','Fig18 Split','Position',[50 50 450 500]); ax=axes(fig);
yyaxis(ax,'left'); plot(ax,sw.DNI,sw.sigma*100,'-o','Color',P.style.colC,'LineWidth',2,'MarkerFaceColor',P.style.colC);
ylabel(ax,'Thermal share \sigma_{th} (%)'); ylim(ax,[65 105]); ax.YColor=P.style.colC;
yyaxis(ax,'right');
plot(ax,sw.DNI,sw.PVc/1e3,'-s','Color',P.style.colB,'LineWidth',1.8,'MarkerFaceColor',P.style.colB); hold(ax,'on');
plot(ax,sw.DNI,sw.hTES,'-^','Color',P.style.colA,'LineWidth',1.8,'MarkerFaceColor',P.style.colA);
ylabel(ax,'Hybrid PV (MW) ; TES (h)'); ax.YColor=[0.2 0.2 0.2];ylim([0 35])
xlabel(ax,'Annual DNI (kWh m^{-2} yr^{-1})'); title(ax,'Storage-medium split frontier and hybrid sizing');
legend(ax,{'\sigma_{th} thermal share','Hybrid PV capacity','TES hours'},'Location','SE'); styleAx(ax);
T=table(sw.DNI,sw.sigma*100,sw.PVc/1e3,sw.hTES,sw.SM, ...
   'VariableNames',{'DNI','SigmaThermal_pct','PV_MW','TES_h','SolarMultiple'});
f=struct('tag','split','name','Storage-medium split frontier and hybrid sizing', ...
 'xlabel','Annual DNI (kWh/m2/yr)','ylabel','Thermal share / sizing', ...
 'legend',["sigma_th","PV","TES hours"],'T',T,'fig',fig, ...
 'caption','Fig. 18. The storage-medium split frontier: cost-optimal thermal share of the hybrid architecture (left axis) and the corresponding PV capacity and TES hours (right axis) versus annual DNI.', ...
 'explanation','At each DNI the hybrid co-optimizes thermal (CSP/TES) and electrical (PV/battery) storage. BELOW the firm-feasibility threshold the CSP field alone cannot hold a 24-h output, so cost-optimal hybrids ADD photovoltaics (daytime electricity) to reach firmness, giving a thermal share below 100%. ABOVE the threshold the heat route is firm-feasible and cheapest on its own, so the optimal PV capacity falls to zero and the thermal share saturates at 100%. The TES duration is the storage needed to bridge the night; it is largest at low DNI (compensating a weaker, more variable resource) and saturates near the night-length requirement (~12 h) at high DNI.', ...
 'interpretation',S('The optimal storage medium shifts with resource: below ~%.0f kWh/m2/yr cheap daytime PV is added (thermal share down to ~%.0f%%), while above it pure thermal storage is cost-optimal (PV -> 0, sigma_th -> 100%%) and the TES duration settles near the overnight requirement.',sw.DNI(find(sw.sigma>=0.999,1)),100*min(sw.sigma)));
end

%% =========================================================================
% FIGURE 19 - Heat-leverage exergy mechanism vs DNI
% =========================================================================
function f = fig19_heatleverage(P,D)
sw=D.sweep;
fig=figure('Name','Fig19 HeatLeverage','Position',[50 50 600 500]); ax=axes(fig);
feas = sw.relA>=P.firm.rel_floor;                 % heat route firm-feasible
dd = sw.B - sw.A;
yyaxis(ax,'left');
plot(ax,sw.DNI,sw.psiA*100,'-','Color',P.style.colA,'LineWidth',2); hold(ax,'on');
plot(ax,sw.DNI,sw.psiB*100,'-','Color',P.style.colB,'LineWidth',2);
ylabel(ax,'Conversion exergy efficiency \psi (%)'); ax.YColor=[0 0 0]; ylim(ax,[40 100]);
yyaxis(ax,'right');
ddF=dd; ddF(~feas)=NaN; ddI=dd; ddI(feas)=NaN;
plot(ax,sw.DNI,ddI,':','Color',[0.6 0.6 0.6],'LineWidth',1.4);   % heat route not firm-feasible
plot(ax,sw.DNI,ddF,'k-','LineWidth',2.0);                        % firm-feasible region
ylabel(ax,'\DeltaLCOH (USD kg^{-1})'); ax.YColor=[0.2 0.2 0.2];ylim([3.5 5])
if ~isnan(D.result.DNIfeas), xline(ax,D.result.DNIfeas,'--','Color',[0.3 0.3 0.3],'Label','firm-feasible','LabelVerticalAlignment','bottom'); end
xlabel(ax,'Annual DNI (kWh m^{-2} yr^{-1})'); title(ax,'Heat-leverage mechanism: exergy efficiency and cost gap');
legend(ax,{'\psi heat route','\psi electricity route','\DeltaLCOH (not firm)','\DeltaLCOH (firm-feasible)'},'Location','N','NumColumns',2); styleAx(ax);
T=table(sw.DNI,sw.psiA,sw.psiB,dd,double(feas),'VariableNames',{'DNI','psi_A','psi_B','dLCOH','FirmFeasible'});
f=struct('tag','heatleverage','name','Heat-leverage exergy mechanism vs DNI', ...
 'xlabel','Annual DNI (kWh/m2/yr)','ylabel','psi / dLCOH','legend',["psi_A","psi_B","dLCOH"],'T',T,'fig',fig, ...
 'caption','Fig. 19. The heat-leverage mechanism: conversion-chain exergy efficiency of the two routes (left axis) and the resulting cost gap DeltaLCOH (right axis) versus annual DNI.', ...
 'explanation','By supplying part of the splitting energy as high-temperature heat that can be stored cheaply, the heat route attains a higher second-law efficiency; the figure links this thermodynamic advantage directly to the economic cost gap.', ...
 'interpretation',S('The heat route maintains an exergy efficiency of ~%.0f%% versus ~%.0f%% for the electricity route; this persistent second-law advantage is the physical cause of the cost gap, which widens with the solar resource.',100*mean(sw.psiA),100*mean(sw.psiB)));
end

%% =========================================================================
% FIGURE 20 - Validation panel
% =========================================================================
function f = fig20_validation(P,D)
V=D.validation;
fig=figure('Name','Fig20 Validation','Position',[50 50 1000 600]); ax=axes(fig); hold(ax,'on');
n=height(V); flr=1e-3;                         % floor for log display of zero bounds
for i=1:n
   yi=n-i+1;
   lo=max(V.Min(i),flr); hi=max(V.Max(i),flr); val=max(V.Value(i),flr);
   plot(ax,[lo hi],[yi yi],'-','Color',[0.6 0.6 0.6],'LineWidth',6);
   col=P.style.colA; if ~V.Pass(i), col=[0.9 0.3 0.2]; end
   plot(ax,val,yi,'o','MarkerFaceColor',col,'MarkerEdgeColor','k','MarkerSize',8);
end

set(ax,'XScale','log');                          % values span ~1e-2 .. 1e4
set(ax,'YTick',1:n,'YTickLabel',flipud(V.Check)); xlabel(ax,'Value (mixed units, log scale; bar = expected range)');
xlim(ax,[1e-1 1e4]); ylim([0 21])
title(ax,S('Validation: %d of %d checks within expected ranges',nnz(V.Pass),n)); styleAx(ax);
f=struct('tag','validation','name','Validation against physical bounds & benchmarks', ...
 'xlabel','Value','ylabel','Check','legend',[],'T',V,'fig',fig, ...
 'caption',S('Fig. 20. Validation panel. Model outputs (markers) against expected physical/literature ranges (grey bars); %d of %d checks pass.',nnz(V.Pass),height(V)), ...
 'explanation','Each row checks a model output (SOEC voltage and efficiency, LCOH ranges, exergy efficiencies, reliability, Petela factor, dominance share) against an independent physical bound or published benchmark (Section 13 targets).', ...
 'interpretation',S('%d of %d validation checks lie within their expected ranges, supporting the credibility of the model before its new results are interpreted.',nnz(V.Pass),height(V)));
end

%% =========================================================================
% FIGURE 21 - Comprehensive uncertainty analysis of all results
% =========================================================================
function f = fig21_uncertainty(P,D)
U=D.uncertainty; T=U.metrics; SM=U.samp;     % SM = samples (S is the string helper)
fig=figure('Name','Fig21 Uncertainty','Position',[50 50 900 800]); tl=tiledlayout(fig,2,2,'Padding','compact','TileSpacing','compact');
% (a) coefficient of variation by metric (ranked)
ax=nexttile(tl,[1 2]);
[cv,ord]=sort(T.CV_pct,'ascend');
barh(ax,cv,'FaceColor',[0.45 0.55 0.75]);
set(ax,'YTick',1:height(T),'YTickLabel',T.Metric(ord),'FontSize',8);
xlabel(ax,{'Coefficient of variation (%)';' '}); title(ax,'(a) Relative uncertainty by result'); styleAx(ax);
% (b) LCOH distributions A/B/C (box) at reference cell
ax=nexttile(tl);
dat=[SM.LCOH_A;SM.LCOH_B;SM.LCOH_C];
grp=[ones(U.M,1);2*ones(U.M,1);3*ones(U.M,1)];
try, boxchart(ax,grp,dat); catch, boxplot(ax,dat,grp); end
set(ax,'XTick',1:3,'XTickLabel',{'A heat','B elec','C hybrid'});
ylabel(ax,'Firm LCOH (USD kg^{-1})'); title(ax,S('(b) LCOH distributions @ %d DNI',U.refDNI)); styleAx(ax);
ylim([1 13])
% (c) crossover DNI* distribution with P10/P50/P90
ax=nexttile(tl);
ds=SM.DNIstar(isfinite(SM.DNIstar));
histogram(ax,ds,'FaceColor',P.style.colA,'FaceAlpha',0.55,'EdgeColor','none'); hold(ax,'on');
xline(ax,prctile(ds,50),'k-','LineWidth',1.8,'Label','P50');
xline(ax,prctile(ds,10),'k:','LineWidth',1.2); xline(ax,prctile(ds,90),'k:','LineWidth',1.2);
xlabel(ax,'Crossover DNI^{*} (kWh m^{-2} yr^{-1})'); ylabel(ax,'Count'); set(ax,'YScale','log'); ylim([0.01 1000])

title(ax,'(c) Crossover DNI* distribution'); styleAx(ax);
f=struct('tag','uncertainty','name','Comprehensive uncertainty of all results', ...
 'xlabel','Metric / route / DNI*','ylabel','CV / LCOH / count','legend',[],'T',T,'fig',fig, ...
 'caption',S('Fig. 21. Comprehensive uncertainty analysis (M=%d Latin-hypercube draws over component costs, WACC and an 8%% resource-data error). (a) Coefficient of variation of every reported result; (b) firm-LCOH distributions of the three routes at the reference cell; (c) distribution of the crossover DNI* and the cumulative distribution of the cost gap.',U.M), ...
 'explanation','Both techno-economic parameters and the satellite resource estimate are perturbed and propagated through the full optimization. The table behind this figure lists mean, standard deviation, CV and P10/P50/P90 with 95%% confidence intervals for each result.', ...
 'interpretation',S('All headline results are robust: the cost gap remains positive in %.0f%% of draws at the reference site, the heat-route LCOH distribution sits clearly below the electricity route, and the crossover DNI* has a P10-P90 spread that still places it within the high-DNI belt.',100*U.Pwin_ref));
end

%% =========================================================================
% ============================ SMALL HELPERS =============================
% =========================================================================
function plotDestr(ax,exr,col,off)
v=exr.comp_vals/1e6; 
x=(1:numel(v))+(off-1.5)*0.18;
bar(ax,x,v,0.18,'FaceColor',col);
set(ax,'XTick',1:numel(v),'XTickLabel',string(exr.comp_names)); xtickangle(ax,30);
end


function s=shortNames(names)
s=strings(size(names));
for i=1:numel(names)
   t=char(names(i)); p=strfind(t,'('); if ~isempty(p), t=strtrim(t(1:p-1)); end
   s(i)=string(t);
end
  
end

function c=diverging()
% blue-white-red diverging colormap
n=256; r=linspace(0.13,0.84,n)'; g=linspace(0.40,0.19,n)'; b=linspace(0.67,0.15,n)';
mid=round(n/2); w=[1 1 1];
c=[ [linspace(0.13,1,mid)' linspace(0.40,1,mid)' linspace(0.67,1,mid)'];
    [linspace(1,0.84,n-mid)' linspace(1,0.19,n-mid)' linspace(1,0.15,n-mid)'] ];
end
function y=maxnz(a,b)
v=[a b]; v=v(~isnan(v)); if isempty(v), y=NaN; else, y=max(v); end
end


function out = underscore2latex(in)
    if iscell(in)
        out = cell(size(in));
        for k = 1:numel(in)
            out{k} = convertOne(in{k});
        end
    elseif isstring(in)
        out = strings(size(in));
        for k = 1:numel(in)
            out(k) = string(convertOne(char(in(k))));
        end
    else % char
        out = convertOne(in);
    end
end

function t = convertOne(t)
    idx = strfind(t,'_');
    if ~isempty(idx)
        pre  = t(1:idx(1));      % includes first _
        post = t(idx(1)+1:end);
        if ~isempty(post)
            post = strjoin(cellstr(post(:))','_');
            t = [pre post];
        end
    end
end