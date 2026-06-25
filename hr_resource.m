function R = hr_resource(P, lat, KT, meanWind, annualDNItarget, meas)
%HR_RESOURCE  Per-cell hourly solar/wind/temperature resource (12 typical days).
% =========================================================================
% PURPOSE : Build 12 monthly typical-day hourly profiles of DNI, GHI, incidence
%           geometry, wind and ambient temperature. Two data modes:
%             (1) SYNTHETIC (default): clear-sky beam (Hottel) x climatological
%                 clearness index, from latitude only (Eqs 3-6).
%             (2) MEASURED (preferred when available): NASA POWER long-term
%                 MONTHLY climatology anchors the daily totals, while the
%                 diurnal SHAPE comes from solar geometry. This is the standard
%                 "measured monthly total + modelled diurnal shape" reduction.
%
% INPUTS :
%   P, lat                 - parameters, site latitude [deg]
%   KT                     - annual clearness index [-]  (synthetic mode)
%   meanWind               - annual mean wind [m/s]      (synthetic mode)
%   annualDNItarget        - target annual DNI [kWh/m2/yr] (synthetic anchor; [] to skip)
%   meas (optional)        - measured monthly climatology struct with fields
%                            .DNI_m,.GHI_m [kWh/m2/day x12], .T_m [degC x12],
%                            .W_m [m/s x12]. If present -> MEASURED mode.
%
% OUTPUT : R struct (fields [24x12]) - .Gb,.G,.costheta,.IAM,.Tamb,.v,.rho and
%          scalars .annualDNI,.annualGHI,.lat,.KT,.source ("synthetic"/"NASA-POWER")
%
% REFERENCES: Duffie & Beckman (2013) [12]; Hottel (1976); Erbs et al. (1982);
%             NASA POWER (LaRC) climatology.
% =========================================================================
if nargin < 5, annualDNItarget = []; end
if nargin < 6, meas = []; end
useMeas = ~isempty(meas) && all(isfinite([meas.DNI_m(:);meas.GHI_m(:)]));
nH = P.time.nHour; nM = P.time.nMonth;
hours = P.time.hours; phi = deg2rad(lat);
monthDays = P.time.monthDays(:)';

% ---- monthly clearness (synthetic mode only) ----------------------------
monthsIdx = 1:nM;
seasonAmp = 0.12*(1-min(KT/0.75,1));
if abs(lat) < 30
    KT_m = KT + seasonAmp*cos(2*pi*(monthsIdx-7)/12);
else
    KT_m = KT - seasonAmp*cos(2*pi*(monthsIdx-7)/12);
end
KT_m = min(max(KT_m,0.18),0.82);

% ---- preallocate --------------------------------------------------------
[Gb,G,costheta,IAM,Tamb,v,rho] = deal(zeros(nH,nM));
GbClear = zeros(nH,nM); I0h = zeros(nH,nM);          % geometric clear-sky shapes

% Hottel clear-sky transmittance constants (sea-level proxy)
a0=0.4237-0.00821*(6-2.5)^2; a1=0.5055+0.00595*(6.5-2.5)^2; kk=0.2711; Isc=1367;

for m = 1:nM
    n = P.time.monthMid(m);
    delta = deg2rad(23.45*sind(360*(284+n)/365));         % Eq 3
    Eecc  = 1 + 0.033*cos(2*pi*n/365);
    for h = 1:nH
        omega = deg2rad(15*(hours(h)+0.5-12));            % Eq 4
        cosz = sin(delta)*sin(phi)+cos(delta)*cos(phi)*cos(omega);  % Eq 5
        cosz = max(cosz,0);
        if cosz <= 0.01, continue; end
        tau_b = a0 + a1*exp(-kk/max(cosz,0.05));
        GbClear(h,m) = Isc*Eecc*tau_b;                    % clear-sky DNI shape [W/m2]
        I0h(h,m)     = Isc*Eecc*cosz;                     % extraterrestrial horizontal
        cth = min(sqrt(max(cosz.^2+cos(delta).^2.*sin(omega).^2,0)),1);  % Eq 6
        costheta(h,m)=cth;
        th = acosd(min(max(cth,-1),1));
        IAM(h,m)=max(1-P.csp.b1*th-P.csp.b2*th.^2,0);     % Eq 12
    end
end

if useMeas
    % ---- MEASURED mode: scale geometric shapes to measured monthly totals
    for m=1:nM
        dDNI = sum(GbClear(:,m))/1000;                    % clear-sky daily DNI [kWh/m2/day]
        if dDNI>0, Gb(:,m)=GbClear(:,m)*max(meas.DNI_m(m),0)/dDNI; end
        dGHI = sum(I0h(:,m))/1000;
        if dGHI>0, G(:,m)=I0h(:,m)*max(meas.GHI_m(m),0)/dGHI; end
        Tamb(:,m)=meas.T_m(m)+7*sin(2*pi*(hours-9)/24);   % monthly mean + diurnal swing
        v(:,m)=max(meas.W_m(m)*(1+0.25*sin(2*pi*(hours-15)/24)),0);
        rho(:,m)=P.const.p0./(287.05*(Tamb(:,m)+273.15));
    end
    annualDNI = sum(meas.DNI_m(:)'.*monthDays);
    annualGHI = sum(meas.GHI_m(:)'.*monthDays);
    I0ann = sum(sum(I0h,1)/1000.*monthDays);
    KTout = annualGHI/max(I0ann,1);
    source = "NASA-POWER";
else
    % ---- SYNTHETIC mode ----
    for m=1:nM
        Gb(:,m) = GbClear(:,m)*min(KT_m(m)/0.78,1.0);
        G(:,m)  = KT_m(m)*I0h(:,m);
        Tmean_ann=30-0.45*abs(lat);
        seasonalT=-10*sign(lat)*cos(2*pi*(P.time.monthMid(m)-15)/365)*(abs(lat)/50);
        Tamb(:,m)=Tmean_ann+seasonalT+7*sin(2*pi*(hours-9)/24)+3*(KT_m(m)-0.5);
        v(:,m)=max(meanWind*(1+0.25*sin(2*pi*(hours-15)/24)),0);
        rho(:,m)=P.const.p0./(287.05*(Tamb(:,m)+273.15));
    end
    annualDNI=sum(sum(Gb,1).*monthDays)/1000;
    annualGHI=sum(sum(G ,1).*monthDays)/1000;
    if ~isempty(annualDNItarget)&&annualDNI>0
        Gb=Gb*annualDNItarget/annualDNI; annualDNI=annualDNItarget;
    end
    KTout=KT; source="synthetic";
end

R = struct('Gb',Gb,'G',G,'costheta',costheta,'IAM',IAM,'Tamb',Tamb,'v',v,'rho',rho, ...
           'annualDNI',annualDNI,'annualGHI',annualGHI,'wmonth',monthDays, ...
           'lat',lat,'KT',KTout,'source',source);
end
