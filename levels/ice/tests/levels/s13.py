# 第 3 關（stage_13）掃線：道具 0＝香蕉皮、1＝飼料
from lv import *
B=seg('B',(-0.2,-10.6),(2.5,-2.0))
print('== 不放、香蕉皮單片（阿水線）'); rb=run(13,[job([])]+[job([(0,p)]) for p in B],name='B'); runs(rb)
FE=('E',5.7,-3.8)
print('== 飼料固定 (5.7,-3.8)＋香蕉皮沿阿水線'); runs(run(13,[job([(1,FE)])]+[job([(1,FE),(0,p)]) for p in B],name='BF'))
BP=('B',1.15,-6.3)
G=grid('E',-1.0,8.0,-9.0,1.0,0.5)
print('== 飼料格點＋香蕉皮固定 (1.15,-6.3)'); gridmap(13,G,[(0,BP)],1,'gridB')
print('== 只放飼料'); gridmap(13,G,[],1,'grid')
