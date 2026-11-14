# 第 5 關（stage_15）完整掃線：道具 0＝香蕉皮、1＝飼料
from lv import *
A=seg('A',(-11.75,-6.5),(-1.0,-6.5)); B=seg('B',(7.2,-13.6),(0.6,-5.0)); F=seg('F',(9.0,-3.4),(1.2,-3.4))
FE=('E',-2.7,0.7); FP=('F',5.0,-3.4); AP=('A',-4.0,-6.5)
def core(r):
    ev=[e.strip() for e in r['ev'].split(';')]
    return [e for e in ev if ('阿土' in e or '阿水' in e) and '抓住' not in e and '追不上' not in e and '改追' not in e and '整人清單' not in e]
r11=run(11,[job([(0,p)]) for p in A],name='A')
r15=run(15,[job([(1,FE),(0,FP),(0,p)]) for p in A],name='EFA')
print('== 阿土線：stage_11 單片 vs stage_15（飼料 (-2.7,0.7)＋阿火一片＋阿土一片）')
print('   阿土、阿水的事件逐字相同 %d/%d'%(sum(core(a)==core(b) for a,b in zip(r11,r15)),len(A)))
for a,b in zip(r11,r15):
    if core(a)!=core(b): print('   不同：',a['label'],'\n     11:',core(a),'\n     15:',core(b))
print('   stage_11：'); runs(r11)
print('   stage_15：'); runs(r15)
print('== 不放飼料：不放、阿火線單片、阿土線＋阿火一片')
runs(run(15,[job([])]+[job([(0,p)]) for p in F]+[job([(0,FP),(0,p)]) for p in A],name='nofeed'))
print('== 飼料 (-2.7,0.7)＋阿土 (-4,-6.5)＋阿火線'); runs(run(15,[job([(1,FE),(0,AP),(0,p)]) for p in F],name='EAF'))
print('== 飼料 (-2.7,0.7)＋阿火一片＋阿水線'); runs(run(15,[job([(1,FE),(0,FP),(0,p)]) for p in B],name='EFB'))
print('== 飼料 (-2.7,0.7)＋單片（阿土線、阿火線）'); runs(run(15,[job([(1,FE),(0,p)]) for p in A+F],name='E1'))
G=grid('E',-5.0,5.0,-9.0,5.0,0.5)
print('== 阿土 (-4,-6.5)＋阿火 (5,-3.4)＋飼料格點'); gridmap(15,G,[(0,AP),(0,FP)],1,'gridAF')
print('== 只放飼料'); gridmap(15,G,[],1,'grid')
