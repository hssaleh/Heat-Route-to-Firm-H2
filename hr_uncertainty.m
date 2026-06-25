function U = hr_uncertainty(P)
%HR_UNCERTAINTY  Comprehensive uncertainty analysis for ALL generated results.
% =========================================================================
% PURPOSE : Monte-Carlo (Latin-hypercube) propagation of BOTH techno-economic
%           parameter uncertainty AND resource-data uncertainty through the
%           full firm-LCOH model, summarising the uncertainty of every headline
%           and secondary result (LCOH of the three routes, cost gap, firmness
%           premia, exergy efficiencies, storage-medium split, specific energy,
%           CO2 mitigation/abatement, and the crossover DNI*).
%
% SAMPLED inputs (Theta): unit costs c_j (7), WACC, a resource/DNI error factor
%   (lognormal, ~8% CV, representing satellite-climatology uncertainty), and
%   SOEC degradation/ASR via the SOEC cost channel.
%
% OUTPUT : U struct
%   .M, .metrics (table: Metric, Mean, Std, CV_pct, P10, P50, P90, CI95lo, CI95hi)
%   .samp  (struct of raw MxN sample arrays for figures)
%   .DNIstar (Mx1 crossover samples), .ladder (DNI ladder)
%
% METHOD : for each draw a DNI ladder is solved (A,B,C) giving the crossover
%   DNI*, and a reference high-DNI cell yields the per-metric samples. Reported
%   intervals are empirical percentiles (P10/P50/P90) and the 95% CI.
% =========================================================================
M = P.mc.M;
rng(P.mc.seed+7);
ladder = (1400:300:3200)';  nL=numel(ladder);
refDNI = 2700;              % reference high-DNI cell for per-metric uncertainty

% --- LHS design over [cost(6), WACC, DNIerr, SOECextra] -------------------
k=9;
try, Ud=lhsdesign(M,k); catch, Ud=rand(M,k); end
E=P.econ; cols={'c_CSP_rng','c_TES_rng','c_SOEC_rng','c_PV_rng','c_wind_rng','c_battE_rng'};
central=[E.c_CSP E.c_TES E.c_SOEC E.c_PV E.c_wind E.c_battE];
mult=ones(M,7);
for c=1:6, r=E.(cols{c}); mult(:,c)=(r(1)+(r(2)-r(1)).*Ud(:,c))/central(c); end
WACCs=E.WACC_rng(1)+(E.WACC_rng(2)-E.WACC_rng(1)).*Ud(:,7);
% resource (DNI) error: lognormal, geometric mean 1, CV ~ 8%
sigln=0.08; DNIfac=exp(sigln*(norminv_safe(Ud(:,8))));
% extra SOEC cost variation already in mult(:,3); keep Ud(:,9) reserved
opt=struct('doC',true,'wantHourly',false);

% --- preallocate sample stores -------------------------------------------
S.LCOH_A=nan(M,1); S.LCOH_B=nan(M,1); S.LCOH_C=nan(M,1); S.dLCOH=nan(M,1);
S.premA=nan(M,1); S.premB=nan(M,1); S.psiA=nan(M,1); S.psiB=nan(M,1);
S.sigma=nan(M,1); S.SEC=nan(M,1); S.etaI=nan(M,1); S.etaSTH=nan(M,1);
S.CO2abate=nan(M,1); S.CO2mit=nan(M,1); S.DNIstar=nan(M,1);

for m=1:M
    % ---- crossover DNI* from the ladder ----
    dd=nan(nL,1); relA=nan(nL,1);
    for j=1:nL
        KT=0.42+0.36*(ladder(j)-1000)/2300;
        res=hr_resource(P,28,KT,5.0,ladder(j)*DNIfac(m));
        R=hr_solve_cell(P,res,WACCs(m),mult(m,:),struct('doC',false));
        dd(j)=R.B.LCOH-R.A.LCOH; relA(j)=R.A.reliab;
    end
    winA=(relA>=P.firm.rel_floor)&(dd>0);
    iw=find(winA,1); if ~isempty(iw), S.DNIstar(m)=ladder(iw); end
    % ---- reference cell: all per-metric samples ----
    res=hr_resource(P,25,0.70,5.0,refDNI*DNIfac(m));
    R=hr_solve_cell(P,res,WACCs(m),mult(m,:),opt);
    anA=hr_analyze_arch(P,res,R.A); anB=hr_analyze_arch(P,res,R.B);
    S.LCOH_A(m)=R.A.LCOH; S.LCOH_B(m)=R.B.LCOH; S.LCOH_C(m)=R.C.LCOH;
    S.dLCOH(m)=R.B.LCOH-R.A.LCOH;
    S.premA(m)=R.A.firmPremium; S.premB(m)=R.B.firmPremium;
    S.psiA(m)=anA.exergy.psi_conv; S.psiB(m)=anB.exergy.psi_conv;
    S.sigma(m)=R.C.storage_thermal_frac; S.SEC(m)=anA.eff.SEC_total;
    S.etaI(m)=anA.eff.eta_I; S.etaSTH(m)=anA.eff.eta_STH;
    S.CO2abate(m)=anA.econ.CO2_abatement_cost; S.CO2mit(m)=anA.env.CO2_mitig_tyr;
end

% --- assemble summary table ----------------------------------------------
metr = {
 'LCOH heat route A (USD/kg)',      S.LCOH_A;
 'LCOH electricity route B (USD/kg)',S.LCOH_B;
 'LCOH hybrid C (USD/kg)',          S.LCOH_C;
 'Cost gap dLCOH (USD/kg)',         S.dLCOH;
 'Firmness premium A (-)',          S.premA;
 'Firmness premium B (-)',          S.premB;
 'Exergy eff ψ_A (-)',            S.psiA;
 'Exergy eff ψ_B (-)',            S.psiB;
 'Storage thermal share (-)',       S.sigma;
 'SEC total A (kWh/kg)',            S.SEC;
 '1^s^t-law eff A (-)',               S.etaI;
 'Solar-to-H_2 eff A (-)',           S.etaSTH;
 'CO_2 abatement cost (USD/tCO_2)',   S.CO2abate;
 'CO_2 mitigation (tCO_2/yr)',        S.CO2mit;
 'Crossover DNI* (kWh/m^2/yr)',      S.DNIstar };
n=size(metr,1);
Name=strings(n,1); Mean=zeros(n,1); Std=zeros(n,1); CV=zeros(n,1);
P10=zeros(n,1); P50=zeros(n,1); P90=zeros(n,1); CIlo=zeros(n,1); CIhi=zeros(n,1);
for i=1:n
    x=metr{i,2}; x=x(isfinite(x)); Name(i)=metr{i,1};
    Mean(i)=mean(x); Std(i)=std(x); CV(i)=100*Std(i)/max(abs(Mean(i)),eps);
    P10(i)=prctile(x,10); P50(i)=prctile(x,50); P90(i)=prctile(x,90);
    CIlo(i)=prctile(x,2.5); CIhi(i)=prctile(x,97.5);
end
metrics=table(Name,Mean,Std,CV,P10,P50,P90,CIlo,CIhi, ...
   'VariableNames',{'Metric','Mean','Std','CV_pct','P10','P50','P90','CI95_lo','CI95_hi'});

% probability heat route wins at the reference cell
Pwin_ref = mean(S.dLCOH>0);
U=struct('M',M,'metrics',metrics,'samp',S,'ladder',ladder,'refDNI',refDNI, ...
         'Pwin_ref',Pwin_ref,'DNIfac',DNIfac);
fprintf('    uncertainty: Pr[heat wins @ %d DNI]=%.0f%%, dLCOH=%.2f+/-%.2f USD/kg (CV %.0f%%)\n', ...
    refDNI,100*Pwin_ref,mean(S.dLCOH),std(S.dLCOH),100*std(S.dLCOH)/abs(mean(S.dLCOH)));
end

function z=norminv_safe(u)
% standard-normal quantile without the Statistics dependency (Acklam approx)
u=min(max(u,1e-6),1-1e-6);
a=[-3.969683028665376e+01 2.209460984245205e+02 -2.759285104469687e+02 1.383577518672690e+02 -3.066479806614716e+01 2.506628277459239e+00];
b=[-5.447609879822406e+01 1.615858368580409e+02 -1.556989798598866e+02 6.680131188771972e+01 -1.328068155288572e+01];
c=[-7.784894002430293e-03 -3.223964580411365e-01 -2.400758277161838e+00 -2.549732539343734e+00 4.374664141464968e+00 2.938163982698783e+00];
d=[7.784695709041462e-03 3.224671290700398e-01 2.445134137142996e+00 3.754408661907416e+00];
pl=0.02425; ph=1-pl; z=zeros(size(u));
l=u<pl; h=u>ph; mid=~(l|h);
q=sqrt(-2*log(u(l)));
z(l)=(((((c(1)*q+c(2)).*q+c(3)).*q+c(4)).*q+c(5)).*q+c(6))./((((d(1)*q+d(2)).*q+d(3)).*q+d(4)).*q+1);
q=u(mid)-0.5; r=q.*q;
z(mid)=(((((a(1)*r+a(2)).*r+a(3)).*r+a(4)).*r+a(5)).*r+a(6)).*q./(((((b(1)*r+b(2)).*r+b(3)).*r+b(4)).*r+b(5)).*r+1);
q=sqrt(-2*log(1-u(h)));
z(h)=-(((((c(1)*q+c(2)).*q+c(3)).*q+c(4)).*q+c(5)).*q+c(6))./((((d(1)*q+d(2)).*q+d(3)).*q+d(4)).*q+1);
end
