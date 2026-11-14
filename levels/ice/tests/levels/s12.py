# 第 2 關（stage_12）掃線
from lv import *
T1=seg('T1',(-11,-6.8),(-3,-6.8)); T2=seg('T2',(-3,-6.8),(-2,-1))[1:]
W1=seg('W1',(-6.6,-12.4),(-0.6,-6.4)); W2=seg('W2',(-0.6,-6.4),(-0.6,-3.6))[1:]
print('== 單片'); runs(run(12,[job([])]+[job([(0,p)]) for p in T1+T2+W1+W2],name='single'))
def combo(A,B,name,stepA=1,stepB=1):
    A=A[::stepA]; B=B[::stepB]
    res=run(12,[job([(0,a),(0,b)]) for a in A for b in B],name=name)
    print('== 兩片 %s：列=%s 每列一行（欄=%s）'%(name,A[0][0],B[0][0]))
    code={}
    for i,a in enumerate(A):
        row=''
        for j,b in enumerate(B):
            k=sig(res[i*len(B)+j])
            code.setdefault(k,chr(ord('A')+len(code)))
            row+=code[k]
        print('   %s(%.2f,%.2f) %s'%(a[0],a[1],a[2],row))
    for k,c in code.items(): print('   %s = %s'%(c,k))
combo(T1,W1,'T1xW1'); combo(T1,W2,'T1xW2'); combo(T2,W1,'T2xW1',2); combo(T2,W2,'T2xW2',2)
# 守衛腳邊、守衛箭頭上
G=seg('G',(2.5,-6.8),(0.0,-4.2))
print('== 守衛箭頭（單片、加阿水第一段）'); runs(run(12,[job([(0,p)]) for p in G]+[job([(0,p),(0,('W1',-1.83,-7.63))]) for p in G],name='guard'))
