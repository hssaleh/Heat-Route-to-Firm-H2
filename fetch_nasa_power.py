# -*- coding: utf-8 -*-
"""
fetch_nasa_power.py
Download NASA POWER long-term MONTHLY CLIMATOLOGY for the model grid and the
named archetype sites, and cache to CSV for the MATLAB pipeline (hr_load_nasa).

Parameters (community = RE):
  ALLSKY_SFC_SW_DNI  - direct normal irradiance      [kWh m-2 day-1]  (monthly mean daily)
  ALLSKY_SFC_SW_DWN  - global horizontal irradiance   [kWh m-2 day-1]
  T2M                - 2-m air temperature             [degC]
  WS50M              - 50-m wind speed                 [m s-1]

Grid matches hr_config: lon -180:4:180, lat -58:4:58 (all cells; the land mask
is applied in MATLAB). Output rows: lat, lon, DNI_1..12, GHI_1..12, T_1..12, W_1..12.

Source: NASA Langley Research Center (LaRC) POWER Project (https://power.larc.nasa.gov).
"""
import os, sys, csv, json, time, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'data')
os.makedirs(DATA, exist_ok=True)
MONTHS = ['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
PARAMS = 'ALLSKY_SFC_SW_DNI,ALLSKY_SFC_SW_DWN,T2M,WS50M'

def url_for(lat, lon):
    return ('https://power.larc.nasa.gov/api/temporal/climatology/point?'
            'parameters=%s&community=RE&longitude=%.4f&latitude=%.4f&format=JSON'
            % (PARAMS, lon, lat))

def fetch(ll, retries=3):
    lat, lon = ll
    for k in range(retries):
        try:
            req = urllib.request.Request(url_for(lat,lon), headers={'User-Agent':'Mozilla/5.0'})
            d = json.load(urllib.request.urlopen(req, timeout=60))
            p = d['properties']['parameter']
            row = [lat, lon]
            for key in ['ALLSKY_SFC_SW_DNI','ALLSKY_SFC_SW_DWN','T2M','WS50M']:
                row += [float(p[key][m]) for m in MONTHS]
            return row
        except Exception:
            time.sleep(1.0 + k)
    return [lat, lon] + [float('nan')]*48          # failed -> NaN, MATLAB falls back

def write_csv(path, rows):
    hdr = ['lat','lon']
    for tag in ['DNI','GHI','T','W']:
        hdr += ['%s_%d'%(tag,m) for m in range(1,13)]
    with open(path,'w',newline='') as f:
        w = csv.writer(f); w.writerow(hdr); w.writerows(rows)

def run_grid(force=False):
    out = os.path.join(DATA,'nasa_power_grid.csv')
    if os.path.exists(out) and not force:
        print('grid cache exists:', out); return
    lons = list(range(-180,181,4)); lats = list(range(-58,59,4))
    pts = [(la,lo) for la in lats for lo in lons]
    print('fetching %d grid points ...' % len(pts)); t=time.time()
    with ThreadPoolExecutor(max_workers=12) as ex:
        rows = list(ex.map(fetch, pts))
    nbad = sum(1 for r in rows if r[2]!=r[2])      # NaN check
    write_csv(out, rows)
    print('  wrote %s (%d rows, %d failed) in %.0fs' % (out,len(rows),nbad,time.time()-t))

def run_arch(force=False):
    out = os.path.join(DATA,'nasa_power_arch.csv')
    if os.path.exists(out) and not force:
        print('arch cache exists:', out); return
    # must match hr_config P.arch order
    sites = [(-23.5,-68.2),(27.0,2.5),(24.0,45.0),(33.5,-112.0),
             (-22.0,118.0),(37.4,-5.0),(27.0,73.0),(53.0,10.0)]
    print('fetching %d archetype points ...' % len(sites)); t=time.time()
    with ThreadPoolExecutor(max_workers=8) as ex:
        rows = list(ex.map(fetch, sites))
    write_csv(out, rows)
    print('  wrote %s in %.0fs' % (out,time.time()-t))

if __name__ == '__main__':
    force = ('--force' in sys.argv)
    run_arch(force)
    run_grid(force)
    print('done.')
