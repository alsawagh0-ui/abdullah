# -*- coding: utf-8 -*-
"""أدوات مطابقة أسئلة الفقه بنص دليل الطالب (سؤال وجواب)."""
import re, json, glob, itertools, collections, unicodedata
ROOT="/home/user/abdullah/imam-exam/"
chunks=json.load(open(ROOT+"audit/dalil_chunks.json",encoding="utf-8"))

# معجم كلمات صحيحة من ملفات المذاكرة النظيفة
lex=collections.Counter()
for f in glob.glob(ROOT+"*.md"):
    for w in re.findall(r"[ء-ي]+", re.sub(r"[ً-ْـ]","",open(f,encoding="utf-8").read())):
        lex[w]+=1
SW=[("ال","لا"),("أل","لأ"),("إل","لإ"),("آل","لآ")]
def variants(w):
    idx=[]
    for a,b in SW:
        for m in re.finditer(a,w): idx.append((m.start(),a,b))
    idx=idx[:6]
    out=set()
    for r in range(1,len(idx)+1):
        for comb in itertools.combinations(idx,r):
            s=list(w); ok=True
            for pos,a,b in sorted(comb,reverse=True):
                s[pos:pos+2]=list(b)
            out.add("".join(s))
    return out
FIX={"ال":"لا","وال":"ولا","فال":"فلا","إال":"إلا","أال":"ألا","كال":"كلا"}
def fixword(w):
    if w in FIX: return FIX[w]
    if lex[w]>0: return w
    best=max(variants(w), key=lambda v: lex[v], default=w)
    return best if lex[best]>0 else w
def clean(t):
    t=re.sub(r"[ً-ْـ]","",t)
    t=re.sub(r"[ء-ي]+", lambda m: fixword(m.group(0)), t)
    t=re.sub(r"\s+([،,.:؟)])",r"\1",t); t=re.sub(r"([(])\s+",r"\1",t)
    return re.sub(r"\s+"," ",t).strip()
def answer_part(t):
    m=re.search(r"ج\s*[:：]\s*|[:：]\s*ج\s",t)
    return t[m.end():] if m else t
def question_part(t):
    m=re.search(r"ج\s*[:：]|[:：]\s*ج\s",t)
    return t[:m.start()] if m else ""
# تطبيع للمطابقة: حذف الألفات واللامات يلغي أثر التشوه
def key(t):
    t=unicodedata.normalize("NFKC",t); t=re.sub(r"[ً-ْـ]","",t)
    t=t.replace("ة","ه").replace("ى","ي")
    t=re.sub(r"[اأإآلء ٰ]","",t)
    return t
def toks(t):
    return set(w for w in (key(x) for x in re.findall(r"[ء-ي]+",t)) if len(w)>=2)
CT=[toks(c["txt"]) for c in chunks]
DF=collections.Counter(w for s in CT for w in s)
import math
N=len(chunks)
def search(text,k=3,book=None):
    q=toks(text); sc=[]
    for i,s in enumerate(CT):
        if book and chunks[i]["book"]!=book: continue
        v=sum(math.log(N/(1+DF[w])) for w in q&s)
        sc.append((v,i))
    sc.sort(reverse=True)
    return sc[:k]
