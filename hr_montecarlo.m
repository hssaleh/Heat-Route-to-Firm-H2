function MC = hr_montecarlo(P)
%HR_MONTECARLO  Uncertainty propagation (Eqs 70-71): Latin-hypercube sampling
% of uncertain techno-economic parameters, propagated through the firm-LCOH
% optimization of Architectures A and B over a DNI ladder, returning LCOH
% percentiles (P10/P50/P90) and the probability that the heat route wins.
%
% INPUT  : P (params)
% OUTPUT : MC struct with .DNI, .LCOH_A/B percentiles, .Pwin(DNI), .samples
%
% Sampled parameters Theta (Section 12): component costs c_j, WACC, SOEC ASR
% proxy (via c_SOEC), TES & power-block efficiency proxies, learning. Latin-
% hypercube sampling gives stable percentiles at modest M. [17,18]
% =========================================================================
M = P.mc.M;
DNIladder = (1200:100:3300)';                  % fine ladder spanning the crossover
nD = numel(DNIladder);

% --- Latin-hypercube design on [0,1]^k, mapped to parameter ranges ---------
k = 8;                                   % CSP,TES,SOEC,PV,wind,batt,WACC,DNIerr
try
    U = lhsdesign(M,k);
catch
    U = rand(M,k);                       % fallback if no Stats toolbox
end
rng = P.econ;
% map each column to its triangular-ish range (min..max), WACC separately
costCols = { 'c_CSP_rng','c_TES_rng','c_SOEC_rng','c_PV_rng','c_wind_rng','c_battE_rng' };
mult = ones(M,7);
for c=1:6
    r = rng.(costCols{c});
    central = [rng.c_CSP rng.c_TES rng.c_SOEC rng.c_PV rng.c_wind rng.c_battE];
    val = r(1) + (r(2)-r(1)).*U(:,c);
    mult(:,c) = val/central(c);          % multiplier relative to central
end
WACCs = rng.WACC_rng(1) + (rng.WACC_rng(2)-rng.WACC_rng(1)).*U(:,7);
% resource (DNI) error per draw: lognormal, ~10% CV (satellite climatology +
% interannual variability). This smears the firm-feasibility threshold so the
% dominance probability is a SMOOTH function of nominal DNI rather than a step.
sigln = 0.10;  DNIfac = exp(sigln*norminv_safe(U(:,8)));

LCOH_A = nan(M,nD); LCOH_B = nan(M,nD); RELA = nan(M,nD);
optMC = struct('doC',false,'wantHourly',false);
for j=1:nD
    for m=1:M
        DNIm = DNIladder(j)*DNIfac(m);                 % perturbed actual resource
        KT = 0.42 + 0.36*(DNIm-1000)/2300;
        res = hr_resource(P, 28, KT, 5.0, DNIm);
        R = hr_solve_cell(P,res,WACCs(m),mult(m,:),optMC);
        LCOH_A(m,j)=R.A.LCOH; LCOH_B(m,j)=R.B.LCOH; RELA(m,j)=R.A.reliab;
    end
end
% FEASIBILITY-AWARE dominance: the heat route "wins" only where it is firm-
% feasible (reliability >= floor) AND cheaper than the electricity route.
win  = (RELA>=P.firm.rel_floor) & ((LCOH_B-LCOH_A)>0);
Pwin = mean(win,1)';                        % Pr[heat route wins] per DNI
Pcheaper = mean((LCOH_B-LCOH_A)>0,1)';      % Pr[cheaper] (ignoring feasibility)
pct = @(X,p) prctile(X,p,1)';
MC = struct('DNI',DNIladder,'M',M, ...
    'LCOH_A_P10',pct(LCOH_A,10),'LCOH_A_P50',pct(LCOH_A,50),'LCOH_A_P90',pct(LCOH_A,90), ...
    'LCOH_B_P10',pct(LCOH_B,10),'LCOH_B_P50',pct(LCOH_B,50),'LCOH_B_P90',pct(LCOH_B,90), ...
    'Pwin',Pwin,'Pcheaper',Pcheaper,'LCOH_A_all',LCOH_A,'LCOH_B_all',LCOH_B, ...
    'RELA',RELA,'WACCs',WACCs,'mult',mult,'DNIfac',DNIfac);
end

function z=norminv_safe(u)
% Standard-normal quantile (Acklam approximation) - no toolbox dependency.
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
