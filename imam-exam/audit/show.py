import json,sys
from dalil import *
res=json.load(open("auto.json",encoding="utf-8"))
kind=sys.argv[1]; a=int(sys.argv[2]); b=int(sys.argv[3])
rs=[r for r in res if r["k"]==kind][a:b]
for r in rs:
    t=clean(answer_part(chunks[r["ci"]]["txt"]))
    print(f"{r['k']}[{r['i']}] {r['q']} ⟵ {r['a']} || c{r['ci']} cov{r['cov']} :: {t[:230]}")
