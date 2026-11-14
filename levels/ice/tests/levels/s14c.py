# 第 4 關完整掃線（改座標後重跑用）：python3 s14c.py [quick]
from lv import *
import sys
quick=len(sys.argv)>1
R=seg('R',(-10.75,-2.0),(-1.25,-2.0)); I=[p for p in R if p[1]>=-5.5]
print('== 不放／單片'); runs(run(14,[job([])]+[job([(0,p)]) for p in R],name='single'))
def pairs(fixed,name):
    res=run(14,[job([(0,a),(0,b)]+fixed) for a in I for b in I],name=name)
    code={}; wins=0; tot=0
    for i,a in enumerate(I):
        row=''
        for j,b in enumerate(I):
            if j<i: row+=' '; continue
            r=res[i*len(I)+j]; k=sig(r); code.setdefault(k,chr(ord('A')+len(code))); row+=code[k]
            tot+=1; wins+= r['out']=='win'
        print('   x=%6.2f %s'%(a[1],row))
    for k,c in code.items(): print('   %s = %s'%(c,k))
    print('   可過關的組合 %d/%d'%(wins,tot))
print('== 兩片（不放飼料）：列=西邊那片、欄=東邊那片，x 從 %.2f 到 %.2f'%(I[0][1],I[-1][1])); pairs([],'pair')
print('== 兩片＋飼料 (2.7,-3.8)'); pairs([(1,('E',2.7,-3.8))],'pairE')
print('== 兩片＋飼料 (-3,-6.5)'); pairs([(1,('E',-3.0,-6.5))],'pairW')
G=grid('E',-5.0,5.0,-9.0,5.0,0.5)
P1=('R',-3.0,-2.0); P2=('R',-1.5,-2.0)
print('== 兩片固定 (-3,-2)(-1.5,-2)＋飼料格點'); gridmap(14,G,[(0,P1),(0,P2)],1,'gridPP')
print('== 只放飼料'); gridmap(14,G,[],1,'grid')
for px in ([-3.0] if quick else [-4.5,-3.0,-1.5]):
    print('== 一片 (%.1f,-2)＋飼料格點'%px); gridmap(14,G,[(0,('R',px,-2.0))],1,'gridP')
