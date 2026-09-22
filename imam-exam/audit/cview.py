import json,sys
from dalil import *
res=json.load(open("auto.json",encoding="utf-8"))
kind=sys.argv[1]; a=int(sys.argv[2]); b=int(sys.argv[3])
for r in [r for r in res if r["k"]==kind][a:b]:
    alts=" | ".join(f"c{ci}:{matn(ci)[:70]}" for ci in r["alt"][:3])
    print(f"{r['i']}. {r['q']} ⟵ {r['a']}\n      {alts}")
