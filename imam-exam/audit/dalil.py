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

# ---------- استخراج نص المتن من مقطع ----------
def matn(ci):
    t=answer_part(chunks[ci]["txt"])
    t=re.sub(r"متن\s*دليل\s*الطالب\s*سؤال\s*و\s*ج\s*واب\s*\d*","",t)
    # تعليقات المحقق بين معقوفين ليست من المتن
    for _ in range(3): t=re.sub(r"\[[^\[\]]*\]","",t)
    t=re.sub(r"[\[\]]","",t)
    t=re.sub(r"#.*?$","",t)
    # عناوين أقسام المحقق الملحقة بآخر المقطع
    t=re.split(r"(?:أولا|ثانيا|ثالثا|رابعا|خامسا|سادسا|سابعا|ثامنا|تاسعا|عاشرا|الحادي عشر|الثاني عشر|الثالث عشر|الرابع عشر)\s*[:：]\s*أسئلة|أسئلة متعلقة",t)[0]
    t=t.replace("(","").replace(")","")
    t=clean(t)
    t=re.sub(r"^[\s:：\-–ج]+","",t)
    fixes={"لا طهور":"الطهور","لا طاهر":"الطاهر","لا يدين":"اليدين","االغسال":"الأغسال","االحرام":"الإحرام","هللا":"الله",
           "ثالثا":"ثلاثاً","الصالة":"الصلاة","بالكالم":"بالكلام","وكالكالم":"وكالكلام","بسالمه":"بسلامه","بسالم":"بسلام",
           "وببطالن":"وببطلان","واال ستنجاء":"والاستنجاء","واالستنجاء":"والاستنجاء","والستحاضة":"والاستحاضة","وإلحرام":"وللإحرام",
           "د بع":"بعد","إال":"إلا","بال لذة":"بلا لذة","بال حائل":"بلا حائل","بال رفع":"بلا رفع","بال عذر":"بلا عذر","بال حاجة":"بلا حاجة",
           "اإلحتقان":"الاحتقان","باإلنزال":"بالإنزال","اإلنزال":"الإنزال","ولا مرور":"والمرور","لاو ":"ولا ","األرادب":"الأرادب","باألرادب":"بالأرادب",
           "ر آخ":"آخر","م وعد":"وعدم","ئر سا":"سائر"}
    for a,b in fixes.items(): t=t.replace(a,b)
    t=re.sub(r"\s+"," ",t).strip(" -–،,")
    return t
def excerpt(ci, probe, maxlen=420):
    t=matn(ci)
    if len(t)<=maxlen: return t
    # قسّم إلى بنود واختر الأقرب مع مقدمة المقطع
    parts=re.split(r"\s(?=\d+\s*[-–)])|\s(?=الأول|الثاني|الثالث|الرابع|الخامس|السادس|السابع|الثامن|التاسع|العاشر)|\s-\s",t)
    head=parts[0]
    q=toks(probe)
    scored=sorted(((len(toks(p)&q),k,p) for k,p in enumerate(parts[1:],1)),reverse=True)
    pick=sorted([x for x in scored[:3] if x[0]>0], key=lambda x:x[1])
    body=" … ".join(p for _,_,p in pick)
    out=(head[:160]+(" … "+body if body else "")).strip()
    return out[:maxlen]
