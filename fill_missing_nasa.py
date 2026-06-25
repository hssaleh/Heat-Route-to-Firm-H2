# -*- coding: utf-8 -*-
"""
fill_missing_nasa.py
Re-fetch only the FAILED (NaN) rows of data/nasa_power_grid.csv from NASA POWER,
using gentle pacing (few workers + exponential backoff) to avoid the throttling
that produced the gaps, then merge and rewrite the CSV. Idempotent: re-running
only retries whatever is still missing.
"""
import os, csv, json, time, math, random, urllib.request
from concurrent.futures import ThreadPoolExecutor

HERE=os.path.dirname(os.path.abspath(__file__))
CSV=os.path.join(HERE,'data','nasa_power_grid.csv')
MONTHS=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
PAR='ALLSKY_SFC_SW_DNI,ALLSKY_SFC_SW_DWN,T2M,WS50M'

def url(lat,lon):
    return ('https://power.larc.nasa.gov/api/temporal/climatology/point?'
            'parameters=%s&community=RE&longitude=%.4f&latitude=%.4f&format=JSON'%(PAR,lon,lat))

def fetch(ll):
    lat,lon=ll
    for k in range(6):
        try:
            req=urllib.request.Request(url(lat,lon),headers={'User-Agent':'Mozilla/5.0'})
            d=json.load(urllib.request.urlopen(req,timeout=60))
            p=d['properties']['parameter']
            row=[lat,lon]
            for key in ['ALLSKY_SFC_SW_DNI','ALLSKY_SFC_SW_DWN','T2M','WS50M']:
                row+=[float(p[key][m]) for m in MONTHS]
            time.sleep(0.05+random.random()*0.1)
            return row
        except Exception:
            time.sleep(2.0*(k+1)+random.random())   # exponential-ish backoff
    return [lat,lon]+[float('nan')]*48

def isnan(x):
    try: return math.isnan(float(x))
    except: return True

rows=list(csv.reader(open(CSV)))
hdr=rows[0]; data=rows[1:]
missing_idx=[i for i,r in enumerate(data) if len(r)<3 or r[2]=='' or isnan(r[2])]
print('missing rows:',len(missing_idx),'of',len(data))
pts=[(float(data[i][0]),float(data[i][1])) for i in missing_idx]

t=time.time(); done=0
with ThreadPoolExecutor(max_workers=5) as ex:
    for i,row in zip(missing_idx, ex.map(fetch,pts)):
        data[i]=[row[0],row[1]]+[('' if (v!=v) else v) for v in row[2:]]
        done+=1
        if done%100==0: print('  %d/%d done (%.0fs)'%(done,len(pts),time.time()-t))

with open(CSV,'w',newline='') as f:
    w=csv.writer(f); w.writerow(hdr); w.writerows(data)
still=sum(1 for r in data if len(r)<3 or r[2]=='' )
print('rewrote CSV; still-missing=%d; elapsed %.0fs'%(still,time.time()-t))
