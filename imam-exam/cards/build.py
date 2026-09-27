# يبني صفحة بطاقات الفقه (خاصة): أسئلة دورة الشيخ الفيلكاوي بعد مطابقتها على دليل الطالب،
# مع الشرح وخيارات الاختيار من متعدد (sheikh/ex_*.json) لسلّم التعلم
import json
from pathlib import Path
D = Path(__file__).resolve().parent
SH = D.parent / "sheikh"
ex = {}
for f in sorted(SH.glob("ex_[0-9].json")):
    for e in json.loads(f.read_text(encoding="utf-8")): ex[e["id"]] = e
cards = []
# خارج المقرر (غير مذكورة في دليل الطالب): لا تدخل البطاقات
OUT = {"s98", "s99", "s110", "s114"}
for c in json.loads((SH / "cards.json").read_text(encoding="utf-8")):
    if c["id"] in OUT: continue
    if c["id"] == "s107": c.pop("n", None)   # التحويل للغرامات ليس من الكتاب
    c = {k: v for k, v in c.items() if k not in ("o", "w", "st", "p")}   # لا يظهر للطالب جواب الدورة الأصلي ولا سبب التصحيح
    e = ex.get(c["id"])
    if e:
        c["ex"] = e.get("ex", "")
        if len(e.get("wrong", [])) >= 3: c["w"] = e["wrong"][:3]
        if e.get("ca"): c["ca"] = e["ca"]
    cards.append(c)
# أسئلة مستخرجة من تسجيل الدورة كاملاً (sheikh/video/final_*.json): نضيف غير المكرر فقط
V = SH / "video"
def secs(t):
    p = [int(x) for x in str(t).split(":")]
    while len(p) < 3: p = [0] + p
    return p[0] * 3600 + p[1] * 60 + p[2]
seen = set()
for f in sorted(V.glob("final_[0-9].json")):
    for x in json.loads(f.read_text(encoding="utf-8")):
        if x.get("dup") or not x.get("a") or not x.get("q") or not x.get("p"): continue   # p=0: ليست في دليل الطالب
        cid = "v%d" % secs(x.get("t", "0:0:0"))
        while cid in seen: cid += "b"
        seen.add(cid)
        c = {"id": cid, "b": x.get("b", ""), "q": x["q"], "a": x["a"], "m": int(x.get("m", 0))}
        for k in ("ex", "ca", "mn"):   # الملاحظات (n) من خارج الكتاب فلا تُعرض
            if x.get(k): c[k] = x[k]
        if len(x.get("w", [])) >= 3: c["w"] = x["w"][:3]
        cards.append(c)
for c in cards: c["s"] = "fiqh"
# بقية المواد من «الصفوة» (sheikh/safwa_cards) + بطاقات الأربعين المولّدة من جدول صفوة الحديث
SC = SH / "safwa_cards"
subj_of = {"s_aqeedah": "aqeedah", "s_nahw": "nahw", "s_tajweed": "tajweed", "s_mithaq": "mithaq", "s_hadith": "hadith", "h40": "hadith", "s_tafsir": "tafsir"}
extra = []
for stem, sj in subj_of.items():
    f = SC / (stem + ".json")
    if not f.exists(): continue
    for x in json.loads(f.read_text(encoding="utf-8")):
        c = {k: x[k] for k in ("id", "b", "q", "a", "ca", "w", "ex") if x.get(k)}
        c["s"] = sj
        if len(c.get("w", [])) != 3: c.pop("w", None)
        if sj == "nahw" or x.get("for") == "imam": c["m"] = 1      # ليس في منهج المؤذن
        if x.get("for") == "muadhin": c["o"] = 1                     # للمؤذن فقط
        extra.append(c)
MARKS = {"imam": {"fiqh": 60, "hadith": 10, "aqeedah": 10, "nahw": 10, "tafsir": 4, "tajweed": 4, "mithaq": 2},
         "muadhin": {"fiqh": 50, "hadith": 20, "aqeedah": 10, "tafsir": 8, "tajweed": 8, "mithaq": 4}}
ORDER = ["الطهارة", "الصلاة", "الجنائز", "الزكاة", "الصيام", "الحج", "البيوع", "النكاح", "الطلاق", "العدة", "الرضاع", "النفقات", "الأطعمة", "الصيد", "الذبائح", "الأيمان"]
def rank(c):
    for i, k in enumerate(ORDER):
        if k in c["b"]: return i
    return len(ORDER)
cards = sorted(enumerate(cards), key=lambda ic: (rank(ic[1]), ic[0]))
cards = [c for _, c in cards] + extra
for c in cards:
    if c["b"] == "الصيد": c["b"] = "الصيد والذبائح"
# محتوى «الفهم قبل الحفظ» (sheikh/content/c_*.json): شجرة الباب، القواعد، ليش هذا الجواب، الأخطاء الشائعة، الحالات العملية
ids = {c["id"] for c in cards}
content = []
for f in sorted((SH / "content").glob("c_*.json")):
    for ch in json.loads(f.read_text(encoding="utf-8")):
        pg = lambda o: int(o.get("pdf", 0)) + 8   # رقم الصفحة المطبوع
        why = {w["card"]: w for w in ch.get("why", []) if w.get("card") in ids and "الكتاب نص" not in w["y"] and not w["y"].startswith("لأن الكتاب ذكر")}   # تعليل دائري لا يفيد
        for c in cards:
            if c["id"] in why: c["y"] = why[c["id"]]["y"]
        content.append({
            "b": ch["b"],
            "tree": [{"h": t["h"], "pts": t.get("pts", []), "p": pg(t)} for t in ch.get("tree", [])],
            "rules": [{"r": r["r"], "p": pg(r), "cards": [i for i in r.get("cards", []) if i in ids]} for r in ch.get("rules", [])],
            "traps": [{"t": t["t"], "right": t["right"], "wrong": t["wrong"], "p": pg(t), "card": t.get("card") if t.get("card") in ids else None} for t in ch.get("traps", [])],
            "cases": [{"q": k["q"], "a": k["a"], "w": k["w"][:3], "p": pg(k), "card": k.get("card") if k.get("card") in ids else None} for k in ch.get("cases", []) if len(k.get("w", [])) >= 3],
        })
content.sort(key=lambda k: rank({"b": k["b"]}))
tpl = (D / "template.html").read_text(encoding="utf-8")
clips = []
for f in sorted((SH).glob("h40_clips_[ab].json")):
    for c in json.loads(f.read_text(encoding="utf-8")):
        clips.append({"n": c["n"], "pts": [{"t": p["t"]} for p in c.get("pts", [])], "how": c.get("how", ""), "mn": c.get("mn", ""),
                      "ask": [{"q": q["q"], "a": q["a"], "w": q["w"][:3]} for q in c.get("ask", []) if len(q.get("w", [])) >= 3]})
clips.sort(key=lambda c: c["n"])
tpl = tpl.replace("/*MARKS*/{}", json.dumps(MARKS))
tpl = tpl.replace("/*CLIPS*/[]", json.dumps(clips, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
tpl = tpl.replace("/*CONTENT*/[]", json.dumps(content, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
out = tpl.replace("/*CARDS*/[]", json.dumps(cards, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
(D / "index.html").write_text(out, encoding="utf-8")
print(len(content), "باب بمحتوى،", sum(1 for c in cards if c.get("y")), "ليش،", len(cards), "بطاقة،", sum(1 for c in cards if c.get("ex")), "بشرح،", sum(1 for c in cards if c.get("w")), "بخيارات")
