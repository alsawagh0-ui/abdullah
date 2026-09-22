# -*- coding: utf-8 -*-
import json, sys
from dalil import *
def items(kind):
    d=json.load(open(ROOT+f"{kind}.json",encoding="utf-8"))
    out=[]
    for i,q in enumerate(d):
        if q["s"]!="fiqh": continue
        sc=q.get("sc","ibadat")
        if sc!="ibadat": continue
        ans = q["o"][q["c"]] if kind=="mcq" else (("صح" if q["t"] else "خطأ") if kind=="tf" else q.get("a",""))
        out.append((kind,i,q["q"],ans))
    return out
def coverage(ans, ci):
    a=toks(ans)
    if not a: return 1.0
    return len(a & CT[ci]) / len(a)
res=[]
for kind in ("mcq","tf","fill","questions"):
    for k,i,q,a in items(kind):
        # للأسئلة صح/خطأ نبحث بالسؤال فقط
        probe = q if kind=="tf" else q+" "+a
        top=search(probe,k=3)
        best=None
        for v,ci in top:
            cov = coverage(q if kind=="tf" else a, ci)
            if best is None or cov>best[1]: best=(ci,cov,v)
        res.append({"k":k,"i":i,"q":q,"a":a,"ci":best[0],"cov":round(best[1],2),"score":round(best[2],1),"alt":[ci for _,ci in top]})
json.dump(res,open("auto.json","w",encoding="utf-8"),ensure_ascii=False,indent=0)
import collections
c=collections.Counter((r["k"], "ok" if r["cov"]>=0.75 else ("mid" if r["cov"]>=0.4 else "low")) for r in res)
for k in ("mcq","tf","fill","questions"):
    print(k, {b:c[(k,b)] for b in ("ok","mid","low")})
