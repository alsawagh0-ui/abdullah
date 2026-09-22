# -*- coding: utf-8 -*-
import sys, json
from dalil import *
kind, start, n = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
data=json.load(open(ROOT+f"{kind}.json",encoding="utf-8"))
items=[(i,q) for i,q in enumerate(data) if q["s"]=="fiqh" and q.get("sc")=="ibadat"] if kind!="questions" else \
      [(i,q) for i,q in enumerate(data) if q["s"]=="fiqh" and q.get("sc","ibadat")=="ibadat"]
for i,q in items[start:start+n]:
    ans = q["o"][q["c"]] if kind=="mcq" else (("صح" if q["t"] else "خطأ") if kind=="tf" else q.get("a",""))
    print(f"### {kind}[{i}] س: {q['q']}  ⟵ {ans}")
    for v,ci in search(q["q"]+" "+ans, k=2):
        print(f"   [{ci}|{chunks[ci]['book']}] {clean(answer_part(chunks[ci]['txt']))[:330]}")
