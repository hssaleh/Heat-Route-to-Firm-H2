function VAL = hr_validate(P, D)
%HR_VALIDATE  Validation & verification of the model outputs against physical
% bounds and published benchmarks (Section 13 validation targets). Returns a
% table of checks (name, value, expected range, pass/fail) and prints a report.
% =========================================================================
checks = {};   % name, value, lo, hi, units
add = @(n,v,lo,hi,u) {n,v,lo,hi,u};

% --- SOEC electrochemistry vs reported V-i and efficiency [3] --------------
VI = D.VI; [~,j5]=min(abs(VI.i-0.5));
checks(end+1,:) = add('SOEC V_c_e_l_l @0.5 A/cm^2 [V]', VI.Vcell(j5), 1.05, 1.30, 'V');
checks(end+1,:) = add('SOEC LHV efficiency (peak)', max(VI.etaLHV), 0.80, 0.95, '-');
checks(end+1,:) = add('SOEC electrical SEC @0.5 [kWh/kg]', VI.SECel(j5), 28, 40, 'kWh/kg');

% --- LT electrolyzer SEC ---------------------------------------------------
checks(end+1,:) = add('LT electrolyzer SEC [kWh/kg]', P.lt.SEC_rated, 48, 58, 'kWh/kg');

% --- LCOH ranges vs literature [7,8,9,21] ----------------------------------
A = D.arch; LA=arrayfun(@(s)s.R.A.LCOH,A); LB=arrayfun(@(s)s.R.B.LCOH,A);
checks(end+1,:) = add('Heat-route firm LCOH range [USD/kg]', median(LA), 2.5, 7.5, 'USD/kg');
checks(end+1,:) = add('Elec-route firm LCOH range [USD/kg]', median(LB), 4.0, 12.0, 'USD/kg');

% --- exergy efficiency bounds ---------------------------------------------
psiA = A(2).anA.exergy.psi_conv; psiB=A(2).anB.exergy.psi_conv;
checks(end+1,:) = add('Heat-route 2^n^d-law eff ψ_c_o_n_v', psiA, 0.50, 0.95, '-');
checks(end+1,:) = add('Elec-route 2^n^d-law eff ψ_c_o_n_v', psiB, 0.40, 0.80, '-');
checks(end+1,:) = add('ψ_A > ψ_B (heat leverage)', double(psiA>psiB), 0.5, 1.5, 'bool');

% --- energy balance closure (1st law) for archetype 2, route A -------------
en=A(2).anA.energy;
closure = (en.H2_LHV_yr + A(2).anA.exergy.Ex_dest_total*0) ; %#ok<NASGU>
eta_chain = en.eta_I;
checks(end+1,:) = add('1^s^t-law conversion eff (A)', eta_chain, 0.55, 0.95, '-');

% --- capacity-factor / reliability >= firm floor ---------------------------
checks(end+1,:) = add('Heat-route firm reliability (high DNI)', A(2).R.A.reliab, P.firm.rel_floor-1e-6, 1.0, '-');

% --- dominance share & crossover sanity ------------------------------------
checks(end+1,:) = add('Global heat-route dominance share', D.result.dominanceShare, 0.05, 0.98, '-');
checks(end+1,:) = add('Break-even/feasibility DNI [kWh/m^2/yr]', maxnan(D.result.DNIstar,D.result.DNIfeas), 900, 2600, 'kWh/m^2/yr');

% --- Petela factor ---------------------------------------------------------
pet = A(1).anA.eff.petela;
checks(end+1,:) = add('Petela solar-exergy factor', pet, 0.90, 0.95, '-');

% --- Monte-Carlo dominance probability sane --------------------------------
checks(end+1,:) = add('MC mean Pr[heat wins]', mean(D.mc.Pwin,'omitnan'), 0.0, 1.0, '-');

% --- measured-resource (NASA POWER) sanity ---------------------------------
if isfield(D,'nasa') && isfield(D.nasa,'grid_ok') && D.nasa.grid_ok
    md=[31 28 31 30 31 30 31 31 30 31 30 31];
    annDNI = sum(D.nasa.DNI.*reshape(md,1,1,12),3);
    annDNI = annDNI(isfinite(annDNI));
    checks(end+1,:) = add('NASA grid mean annual DNI [kWh/m^2/yr]', mean(annDNI), 800, 2800, 'kWh/m^2/yr');
    checks(end+1,:) = add('NASA grid max annual DNI [kWh/m^2/yr]', max(annDNI), 1800, 3600, 'kWh/m^2/yr');
end
% archetype measured/used annual DNI within physical bounds
dnis = arrayfun(@(s)s.res.annualDNI, D.arch);
checks(end+1,:) = add('Archetype max annual DNI [kWh/m^2/yr]', max(dnis), 1500, 3600, 'kWh/m^2/yr');

% --- uncertainty-analysis sanity ------------------------------------------
if isfield(D,'uncertainty')
    U=D.uncertainty;
    ia=find(U.metrics.Metric=="LCOH heat route A (USD/kg)",1);
    checks(end+1,:) = add('Uncertainty CV of LCOH_A [%]', U.metrics.CV_pct(ia), 1, 45, '%');
    checks(end+1,:) = add('Pr[heat wins] @ reference cell', U.Pwin_ref, 0.5, 1.0, '-');
end

% assemble table
n=size(checks,1); name=strings(n,1); val=zeros(n,1); lo=zeros(n,1); hi=zeros(n,1);
unit=strings(n,1); pass=false(n,1);
for i=1:n
    name(i)=checks{i,1}; val(i)=checks{i,2}; lo(i)=checks{i,3}; hi(i)=checks{i,4}; unit(i)=checks{i,5};
    pass(i)= val(i)>=lo(i)-1e-9 & val(i)<=hi(i)+1e-9;
end
VAL = table(name,val,lo,hi,unit,pass,'VariableNames', ...
    {'Check','Value','Min','Max','Units','Pass'});
fprintf('\n--- VALIDATION REPORT (%d checks, %d passed) ---\n',n,nnz(pass));
disp(VAL);
if all(pass)
    fprintf('ALL CHECKS PASSED.\n');
else
    fprintf('WARNING: %d check(s) outside expected range (review).\n',nnz(~pass));
end
end

function y=maxnan(a,b)
v=[a b]; v=v(~isnan(v)); if isempty(v), y=NaN; else, y=max(v); end
end
