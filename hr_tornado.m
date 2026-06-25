function T = hr_tornado(P)
%HR_TORNADO  Local (one-at-a-time) sensitivity of the heat-route firm LCOH
% and of the heat-vs-electricity advantage (dLCOH) to the principal uncertain
% parameters, at a representative high-DNI site. Returns low/high LCOH swings
% for a tornado chart and ranks the most influential variables.
% =========================================================================
res = hr_resource(P, 27, 0.72, 5.0, 2900);     % representative high-DNI cell
WACC0 = 0.08;
base = hr_solve_cell(P,res,WACC0,ones(1,7),struct('doC',false));
LA0 = base.A.LCOH; LB0 = base.B.LCOH; dd0 = LB0-LA0;

% parameter perturbations: {name, costMultIndex(0=WACC), lowFactor, highFactor}
items = {
 'CSP field+block cost', 1, 4000/4500, 6000/4500
 'TES cost',             2, 20/25,     30/25
 'SOEC cost',            3, 1000/1500, 2500/1500
 'PV cost',              4, 700/800,   1000/800
 'Wind cost',            5, 1200/1400, 1600/1400
 'Battery cost',         6, 200/250,   350/250
 'LT electrolyzer cost', 7, 800/1100,  1500/1100
 'WACC',                 0, 0.05/0.08, 0.12/0.08 };
n = size(items,1);
T = struct('names',{items(:,1)},'LA_lo',nan(n,1),'LA_hi',nan(n,1), ...
           'LB_lo',nan(n,1),'LB_hi',nan(n,1),'dd_lo',nan(n,1),'dd_hi',nan(n,1), ...
           'LA0',LA0,'LB0',LB0,'dd0',dd0);
for i=1:n
    ci = items{i,2};
    for s=1:2
        m=ones(1,7); w=WACC0;
        f = items{i,2+s};
        if ci==0, w=WACC0*f; else, m(ci)=f; end
        R=hr_solve_cell(P,res,w,m,struct('doC',false));
        if s==1
            T.LA_lo(i)=R.A.LCOH; T.LB_lo(i)=R.B.LCOH; T.dd_lo(i)=R.B.LCOH-R.A.LCOH;
        else
            T.LA_hi(i)=R.A.LCOH; T.LB_hi(i)=R.B.LCOH; T.dd_hi(i)=R.B.LCOH-R.A.LCOH;
        end
    end
end
% rank by total LCOH_A swing
[~,T.rankA] = sort(abs(T.LA_hi-T.LA_lo),'descend');
end
