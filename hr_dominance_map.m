function Pwin = hr_dominance_map(P, GRID)
%HR_DOMINANCE_MAP  Monte-Carlo probability that the heat route wins, per cell.
% A reduced LHS sample (for tractability) of capital costs and WACC is
% propagated through both architectures at every land cell; Pwin is the
% fraction of draws in which LCOH_B > LCOH_A (Eq 71). Returns a [nLat x nLon]
% map (NaN over ocean).
% =========================================================================
Msmall = max(round(P.mc.M/20), 16);           % reduced sample for the map
stride = max(2, round(8/P.grid.res));          % subsample finer grids more, then interpolate
[nLat,nLon]=size(GRID.DNI);
Pwin = nan(nLat,nLon);
try, U=lhsdesign(Msmall,7); catch, U=rand(Msmall,7); end
rng=P.econ;
central=[rng.c_CSP rng.c_TES rng.c_SOEC rng.c_PV rng.c_wind rng.c_battE];
cols={'c_CSP_rng','c_TES_rng','c_SOEC_rng','c_PV_rng','c_wind_rng','c_battE_rng'};
mult=ones(Msmall,7);
for c=1:6, r=rng.(cols{c}); mult(:,c)=(r(1)+(r(2)-r(1)).*U(:,c))/central(c); end
WACCs=rng.WACC_rng(1)+(rng.WACC_rng(2)-rng.WACC_rng(1)).*U(:,7);
opt=struct('doC',false,'wantHourly',false);
iyv=1:stride:nLat; ixv=1:stride:nLon;
hasMeas = isfield(GRID,'hasMeas') && GRID.hasMeas && ~isempty(GRID.DNI_m);
for iy=iyv
  for ix=ixv
    if ~GRID.land(iy,ix), continue; end
    meas=[];
    if hasMeas
        dni=squeeze(GRID.DNI_m(iy,ix,:))'; ghi=squeeze(GRID.GHI_m(iy,ix,:))';
        tt=squeeze(GRID.T_m(iy,ix,:))'; ww=squeeze(GRID.W_m(iy,ix,:))';
        if all(isfinite([dni ghi tt ww])), meas=struct('DNI_m',dni,'GHI_m',ghi,'T_m',tt,'W_m',ww); end
    end
    res=hr_resource(P,GRID.LAT(iy,ix),GRID.KT(iy,ix),GRID.WIND(iy,ix),GRID.DNI(iy,ix),meas);
    win=0;
    for m=1:Msmall
        R=hr_solve_cell(P,res,WACCs(m),mult(m,:),opt);
        % feasibility-aware: heat wins only if firm-feasible AND cheaper
        win = win + double( (R.A.reliab>=P.firm.rel_floor) && ((R.B.LCOH-R.A.LCOH)>0) );
    end
    Pwin(iy,ix)=win/Msmall;
  end
end
% fill the skipped cells by nearest computed neighbour (cheap, smooth map)
known = ~isnan(Pwin);
if nnz(known)>3
    [JJ,II]=meshgrid(1:nLon,1:nLat);
    F=scatteredInterpolant(II(known),JJ(known),Pwin(known),'nearest','nearest');
    Pfull=F(II,JJ); Pwin=Pfull;
end
Pwin(~GRID.land)=NaN;
end
