# 第 6 關（stage_16）完整掃線：道具 0＝香蕉皮（3 片）、1＝飼料
from lv import *
import sys
A=seg('A',(-11.75,-6.5),(-1.0,-6.5)); B=seg('B',(7.2,-13.6),(0.6,-5.0)); F=seg('F',(-6.5,1.2),(-1.25,1.2))
GA=seg('G',(-1.5,-5.0),(0.0,-2.88))[1:]
FE=('E',-2.7,-2.3); FP=('F',-4.0,1.2); AP=('A',-9.0,-6.5); AT=('A',-4.0,-6.5); BP=('B',2.63,-7.65); GP=('G',-0.75,-3.94)
print('== 不放／阿火線單片（看守衛甲）'); runs(run(16,[job([])]+[job([(0,p)]) for p in F],name='F'))
print('== 不放飼料、三片各解一人：阿火 (-4,1.2)＋阿水 (2.63,-7.65)＋阿土線（看守衛乙抓不抓得到）'); runs(run(16,[job([(0,FP),(0,BP),(0,p)]) for p in A],name='FBA'))
print('== 保底：飼料 (-2.7,-2.3)＋阿土 (-9,-6.5)＋阿水 (2.63,-7.65)＋阿火線'); runs(run(16,[job([(1,FE),(0,AP),(0,BP),(0,p)]) for p in F],name='EABF'))
print('== 保底：飼料＋阿火 (-4,1.2)＋阿水 (2.63,-7.65)＋阿土線'); runs(run(16,[job([(1,FE),(0,FP),(0,BP),(0,p)]) for p in A],name='EFBA'))
print('== 保底：飼料＋阿火 (-4,1.2)＋阿土 (-9,-6.5)＋阿水線'); runs(run(16,[job([(1,FE),(0,FP),(0,AP),(0,p)]) for p in B],name='EFAB'))
print('== 進階（全員泡湯）：飼料＋阿火 (-4,1.2)＋阿土線（兩片）'); runs(run(16,[job([(1,FE),(0,FP),(0,p)]) for p in A],name='EFA'))
print('== 進階（飼料沒拆封）：阿火 (-4,1.2)＋守衛乙箭頭 (-0.75,-3.94)＋阿土線'); runs(run(16,[job([(0,FP),(0,GP),(0,p)]) for p in A],name='FGA'))
print('== 守衛乙箭頭掃線：阿火 (-4,1.2)＋阿土 (-4,-6.5)＋箭頭上每 0.25'); runs(run(16,[job([(0,FP),(0,AT),(0,p)]) for p in GA],name='FAG'))
print('== 不放飼料、不對時機：阿火＋阿土 (-9)＋阿水線'); runs(run(16,[job([(0,FP),(0,AP),(0,p)]) for p in B],name='FAB'))
if len(sys.argv)>1:
    G=grid('E',-5.0,5.0,-9.0,6.0,0.5)
    print('== 保底三片＋飼料格點'); gridmap(16,G,[(0,FP),(0,AP),(0,BP)],1,'grid3')
    print('== 阿火＋阿土對時機 (-4,-6.5)＋飼料格點'); gridmap(16,G,[(0,FP),(0,AT)],1,'grid2')
    print('== 只放飼料'); gridmap(16,G,[],1,'grid0')
if len(sys.argv)>1:
    print('== 阿火＋阿土 (-9)＋飼料格點，沒處理阿水（應該必輸）'); gridmap(16,G,[(0,FP),(0,AP)],1,'gridFA')
    print('== 同上，黃線兩側 2 公尺內每 0.25'); gridmap(16,grid('E',-2.0,2.0,-9.0,5.0,0.25),[(0,FP),(0,AP)],1,'gridFA2')
