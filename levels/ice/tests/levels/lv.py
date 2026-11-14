# 掃線共用工具：產生 jobs、呼叫 sweep.sh、整理結果
# 用法（從專案根目錄，先 export GODOT=…）：python3 levels/ice/tests/levels/s13.py > levels/ice/tests/levels/tables/stage_13.txt
import math, subprocess, os, re, itertools, tempfile
S=os.path.dirname(os.path.abspath(__file__))          # sweep.sh 在這裡
W=os.environ.get('ICE_SWEEP_OUT') or tempfile.mkdtemp(prefix='ice_sweep_')   # jobs 檔和原始輸出放這裡（不寫進專案）
def seg(tag,a,b,step=0.25):
    L=math.hypot(b[0]-a[0],b[1]-a[1]); n=int(L/step+1e-6); out=[]
    for i in range(n+1):
        k=i*step/L
        out.append((tag,round(a[0]+(b[0]-a[0])*k,2),round(a[1]+(b[1]-a[1])*k,2)))
    return out
def grid(tag,x0,x1,z0,z1,step=0.5):
    out=[]; x=x0
    while x<=x1+1e-6:
        z=z0
        while z<=z1+1e-6:
            out.append((tag,round(x,2),round(z,2))); z+=step
        x+=step
    return out
def job(casts):
    # casts: [(item, (tag,x,z)), ...]
    lab='+'.join('%s(%.2f,%.2f)'%(p[0],p[1],p[2]) for _,p in casts) or 'none'
    return lab+'|'+';'.join('%d,%.2f,%.2f'%(i,p[1],p[2]) for i,p in casts)
def run(stage,jobs,twice=True,name='tmp'):
    fn=os.path.join(W,'jobs_%s_%s.txt'%(stage,name)); open(fn,'w').write('\n'.join(jobs)+'\n')
    def once():
        return subprocess.run([os.path.join(S,'sweep.sh'),str(stage),fn],capture_output=True,text=True).stdout
    o=once()
    if 'SCRIPT ERROR' in o or 'Parse Error' in o: print(o[:3000])
    if twice:
        o2=once()
        print('  [重跑一致]' if o==o2 else '  [!!! 兩次結果不同]')
    open(os.path.join(W,'out_%s_%s.txt'%(stage,name)),'w').write(o)
    res=[]
    for l in o.strip().split('\n'):
        p=[x.strip() for x in l.split('|',4)]
        if len(p)<5: continue
        oc=p[1].split()
        if len(oc)<2 or oc[0] not in ('win','lose'): oc=['stuck']+oc
        res.append(dict(label=p[0],out=oc[0],t=float(oc[1]),fail='castfail' in p[1],stars=p[2],by=p[3],ev=p[4]))
    if len(res)!=len(jobs): print('  [!!! 筆數不符 %d/%d]'%(len(res),len(jobs)))
    return res
def sig(r):
    # 結果摘要：輸贏、星星、誰抓的、誰掉進洞／雪堆
    falls=''.join(sorted(re.findall(r'(\S+?)掉進',r['ev']),key=str))
    falls=','.join(re.findall(r'[\d.]+ (\S+?)掉進',r['ev']))
    pile=','.join(re.findall(r'[\d.]+ (\S+?)倒栽',r['ev']))
    s=r['out']
    if r['out']=='win': s+='['+r['stars'].replace('rescue','').strip(',')+']'
    elif r['out']=='stuck': s='卡住60秒'
    else: s+='(%s抓)'%r['by']
    if falls: s+=' 洞:'+falls
    if pile: s+=' 雪堆:'+pile
    if r['fail']: s+=' 放不了'
    return s
def runs(res,key=sig):
    # 把連續相同結果的位置合併成一段
    out=[]
    for r in res:
        k=key(r)
        if out and out[-1][0]==k: out[-1][2]=r['label']; out[-1][3]+=1
        else: out.append([k,r['label'],r['label'],1])
    for k,a,b,n in out: print('   %-34s ~ %-34s x%-3d %s'%(a,b,n,k))
def gridmap(stage,G,fixed,item,name,xs=None):
    # 飼料格點：每格一個代號，列=z（北在上）、欄=x
    res=run(stage,[job(fixed+[(item,g)]) for g in G],name=name)
    code={}; m={}
    for g,r in zip(G,res):
        k=sig(r); code.setdefault(k,chr(ord('A')+len(code)) if len(code)<26 else chr(ord('a')+len(code)-26)); m[(g[1],g[2])]=code[k]
    xs=sorted(set(g[1] for g in G)); zs=sorted(set(g[2] for g in G))
    print('        x: '+' '.join('%4.1f'%x for x in xs[::2]))
    for z in zs: print('   z=%5.1f '%z+''.join(m.get((x,z),' ') for x in xs))
    for k,c in code.items(): print('   %s = %s'%(c,k))
    return res
