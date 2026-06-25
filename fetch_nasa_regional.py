# -*- coding: utf-8 -*-
"""
fetch_nasa_regional.py
Fetch NASA POWER long-term MONTHLY climatology natively via the REGIONAL endpoint
(up to 100 points/call, 1 parameter/call) and write ONE CSV PER PARAMETER.

IMPORTANT: NASA POWER serves solar parameters (DNI, GHI) on a ~1-degree grid but
meteorology (T2M, WS50M) on the finer MERRA-2 grid, so the four parameters do NOT
share coordinates. Each parameter is therefore stored on its own native grid and
interpolated separately onto the model grid in MATLAB (hr_load_nasa). Output:
  data/nasa_param_DNI.csv, _GHI.csv, _T.csv, _W.csv   (cols: lat,lon,JAN..DEC)

Resumable: existing per-parameter CSVs are loaded; tiles already covered for a
parameter are skipped. Gentle worker pool + backoff to survive throttling.
"""
import os, csv, json, time, random, urllib.request, threading
from concurrent.futures import ThreadPoolExecutor

HERE=os.path.dirname(os.path.abspath(__file__)); DATA=os.path.join(HERE,'data')
os.makedirs(DATA,exist_ok=True)
MONTHS=['JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC']
PARAMS=['ALLSKY_SFC_SW_DNI','ALLSKY_SFC_SW_DWN','T2M','WS50M']
TAG={'ALLSKY_SFC_SW_DNI':'DNI','ALLSKY_SFC_SW_DWN':'GHI','T2M':'T','WS50M':'W'}
def csvpath(p): return os.path.join(DATA,'nasa_param_%s.csv'%TAG[p])

LANDBOX=[(-38,40,-20,55),(34,62,-12,62),(5,60,55,150),(5,40,60,95),
         (-45,-9,110,156),(12,62,-130,-52),(-56,14,-85,-33),(48,72,-170,-138),
         (-36,-20,15,33)]
def tile_has_land(la,lo,sz=10):
    for (a0,a1,o0,o1) in LANDBOX:
        if not (la+sz<a0 or la>a1 or lo+sz<o0 or lo>o1): return True
    return False
def url(p,la,lo,sz=10):
    return ('https://power.larc.nasa.gov/api/temporal/climatology/regional?'
            'parameters=%s&community=RE&latitude-min=%g&latitude-max=%g'
            '&longitude-min=%g&longitude-max=%g&format=JSON'%(p,la,la+sz,lo,lo+sz))

store={p:{} for p in PARAMS}; covered={p:set() for p in PARAMS}
lock=threading.Lock(); done=[0]; t0=time.time()

def load_existing():
    for p in PARAMS:
        fp=csvpath(p)
        if not os.path.exists(fp): continue
        try:
            for r in list(csv.reader(open(fp)))[1:]:
                latp=round(float(r[0]),2); lonp=round(float(r[1]),2)
                store[p][(latp,lonp)]=[float(x) for x in r[2:14]]
                covered[p].add((int((latp//10)*10),int((lonp//10)*10)))
            print('resumed %s: %d points'%(TAG[p],len(store[p])),flush=True)
        except Exception: pass

def fetch(task):
    p,la,lo=task
    for k in range(8):
        try:
            req=urllib.request.Request(url(p,la,lo),headers={'User-Agent':'Mozilla/5.0'})
            d=json.load(urllib.request.urlopen(req,timeout=120))
            pts=[]
            for f in d.get('features',[]):
                c=f['geometry']['coordinates']
                pr=f['properties']['parameter'][p]
                pts.append((round(c[1],2),round(c[0],2),[float(pr[m]) for m in MONTHS]))
            with lock:
                for (latp,lonp,vals) in pts: store[p][(latp,lonp)]=vals
                done[0]+=1
                if done[0]%150==0:
                    tot=sum(len(store[q]) for q in PARAMS)
                    print('  %d tasks, pts DNI=%d T=%d, %.0fs'%(done[0],len(store[PARAMS[0]]),len(store[PARAMS[2]]),time.time()-t0),flush=True)
            time.sleep(0.1+random.random()*0.2)
            return
        except Exception:
            time.sleep(3.0*(k+1)+random.random()*2)
    with lock: done[0]+=1

load_existing()
tasks=[]
for la in range(-60,60,10):
    for lo in range(-180,180,10):
        if tile_has_land(la,lo):
            for p in PARAMS:
                if (la,lo) not in covered[p]: tasks.append((p,la,lo))
print('regional tasks to fetch: %d (after resume)'%len(tasks),flush=True)
with ThreadPoolExecutor(max_workers=4) as ex:
    list(ex.map(fetch,tasks))

# write one CSV per parameter
for p in PARAMS:
    fp=csvpath(p); hdr=['lat','lon']+MONTHS
    with open(fp,'w',newline='') as f:
        w=csv.writer(f); w.writerow(hdr)
        for (latp,lonp),vals in sorted(store[p].items(),key=lambda kv:(kv[0][1],kv[0][0])):
            w.writerow([latp,lonp]+vals)
    print('wrote %s : %d native points'%(fp,len(store[p])),flush=True)
print('done in %.0fs'%(time.time()-t0),flush=True)
