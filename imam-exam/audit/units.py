# -*- coding: utf-8 -*-
import re, json
from dalil import *
src=open(ROOT+"07-دليل-الطالب-العبادات.md",encoding="utf-8").read()
units=[]; h2=h3=""
buf=[]
def flush(kind):
    global buf
    if buf:
        t=" ".join(buf).strip()
        if t: units.append({"h2":h2,"h3":h3,"t":t})
    buf=[]
for ln in src.split("\n"):
    s=ln.strip()
    if s.startswith("## "): flush(0); h2=s[3:].strip(); h3=""; continue
    if s.startswith("### "): flush(0); h3=s[4:].strip(); continue
    if not s or s=="---" or s.startswith("#"): flush(0); continue
    if re.match(r"^(-|\d+[.)-])\s",s) or s.startswith("**"):
        flush(0); buf=[s]; continue
    buf.append(s)
flush(0)
# تحقق من وجود كل سطر في نص الكتاب
def plain(t): return re.sub(r"\*\*|[#*_]","",t)
out=[]
for u in units:
    tt=toks(plain(u["t"]))
    if not tt: continue
    best=max(range(len(chunks)), key=lambda i: len(tt&CT[i]))
    cont=len(tt&CT[best])/len(tt)
    u.update(ci=best, cont=round(cont,2), n=len(tt)); out.append(u)
json.dump(out,open("units.json","w",encoding="utf-8"),ensure_ascii=False,indent=0)
import collections
b=collections.Counter("≥0.9" if u["cont"]>=0.9 else ("0.75-0.9" if u["cont"]>=0.75 else "<0.75") for u in out)
print("وحدات:",len(out),dict(b))
for u in [x for x in out if x["cont"]<0.75][:12]:
    print(u["cont"],"|",plain(u["t"])[:150])
