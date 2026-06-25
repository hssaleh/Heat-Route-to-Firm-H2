function N = hr_load_nasa(P)
%HR_LOAD_NASA  Load cached NASA POWER monthly climatology (grid + archetypes).
% =========================================================================
% PURPOSE : Read the CSV caches written by fetch_nasa_power.py and return
%           measured monthly climatology fields aligned to the model grid and
%           to the named archetype sites. If the caches are absent or unusable,
%           returns N.ok=false so the pipeline falls back to the synthetic model.
%
% OUTPUT : N struct
%   .ok            logical, true if usable measured data are available
%   .grid_ok       logical, grid cache present
%   .DNI,.GHI,.T,.W  [nLat x nLon x 12] monthly fields (DNI/GHI in kWh/m2/day,
%                    T in degC, W in m/s) aligned to P.grid.lat x P.grid.lon
%   .arch          1xNarch struct with .DNI_m,.GHI_m,.T_m,.W_m (12-vectors)
%   .source        "NASA-POWER"
%
% UNITS/SOURCE: NASA Langley POWER long-term climatology, community RE.
% =========================================================================
N = struct('ok',false,'grid_ok',false,'source',"NASA-POWER");
dataDir = fullfile(fileparts(mfilename('fullpath')),'data');
gridCSV = fullfile(dataDir,'nasa_power_grid.csv');
archCSV = fullfile(dataDir,'nasa_power_arch.csv');

% ---- archetype sites ----------------------------------------------------
if exist(archCSV,'file')
    A = readmatrix(archCSV);                       % rows: lat lon DNI1..12 GHI.. T.. W..
    na = size(A,1);
    arch = struct('DNI_m',{},'GHI_m',{},'T_m',{},'W_m',{},'lat',{},'lon',{});
    for k=1:na
        arch(k).lat=A(k,1); arch(k).lon=A(k,2);
        arch(k).DNI_m=A(k,3:14); arch(k).GHI_m=A(k,15:26);
        arch(k).T_m=A(k,27:38);  arch(k).W_m=A(k,39:50);
    end
    N.arch = arch;
end

% ---- grid: PER-PARAMETER native CSVs, each interpolated onto P.grid --------
% NASA serves solar (DNI/GHI ~1 deg) and meteorology (T/W, MERRA-2) on DIFFERENT
% native grids, so each parameter is stored and interpolated on its own grid.
lat = P.grid.lat(:); lon = P.grid.lon(:);
[LON,LAT]=meshgrid(lon,lat); nLat=numel(lat); nLon=numel(lon);
tags={'DNI','GHI','T','W'}; out=struct(); srcPts=0; haveAll=true;
for b=1:4
    fp = fullfile(dataDir, sprintf('nasa_param_%s.csv',tags{b}));
    Z = nan(nLat,nLon,12);
    if exist(fp,'file')
        Araw = readmatrix(fp);                        % lat,lon,JAN..DEC
        slat=Araw(:,1); slon=Araw(:,2); vals=Araw(:,3:14); vals(vals<-100)=NaN;
        if b==1, srcPts=size(Araw,1); end
        for mo=1:12
            v=vals(:,mo); ok=isfinite(v);
            if nnz(ok)<10, continue; end
            F=scatteredInterpolant(slon(ok),slat(ok),v(ok),'natural','nearest');
            Z(:,:,mo)=F(LON,LAT);
        end
    else
        haveAll=false;
    end
    out.(tags{b})=Z;
end
if haveAll
    N.DNI=out.DNI; N.GHI=out.GHI; N.T=out.T; N.W=out.W; N.lat=lat; N.lon=lon;
    N.srcPts=srcPts;
    N.grid_ok = mean(isfinite(N.DNI(:,:,1)),'all') > 0.15;
elseif exist(gridCSV,'file')
    % fallback: legacy single combined CSV (4-deg) - interpolate all 4 columns
    Gm = readmatrix(gridCSV); slat=Gm(:,1); slon=Gm(:,2); raw=Gm(:,3:50); raw(raw<-100)=NaN;
    DNI=nan(nLat,nLon,12); GHI=DNI; T=DNI; W=DNI; blocks={1:12,13:24,25:36,37:48};
    arr={'DNI','GHI','T','W'};
    for b=1:4, cols=blocks{b};
        for mo=1:12, v=raw(:,cols(mo)); ok=isfinite(v);
            if nnz(ok)<10, continue; end
            F=scatteredInterpolant(slon(ok),slat(ok),v(ok),'natural','nearest');
            switch arr{b}, case 'DNI',DNI(:,:,mo)=F(LON,LAT); case 'GHI',GHI(:,:,mo)=F(LON,LAT);
                case 'T',T(:,:,mo)=F(LON,LAT); case 'W',W(:,:,mo)=F(LON,LAT); end
        end
    end
    N.DNI=DNI; N.GHI=GHI; N.T=T; N.W=W; N.lat=lat; N.lon=lon;
    N.srcPts=nnz(isfinite(raw(:,1))); N.grid_ok = mean(isfinite(DNI(:,:,1)),'all') > 0.15;
end

N.ok = isfield(N,'arch') && (N.grid_ok || ~exist(gridCSV,'file'));
if N.grid_ok
    fprintf('    NASA POWER: %d measured points interpolated onto the %gx%g grid.\n', ...
        N.srcPts, numel(N.lon), numel(N.lat));
end
end
