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
for c in json.loads((SH / "cards.json").read_text(encoding="utf-8")):
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
        if x.get("dup") or not x.get("a") or not x.get("q"): continue
        cid = "v%d" % secs(x.get("t", "0:0:0"))
        while cid in seen: cid += "b"
        seen.add(cid)
        c = {"id": cid, "b": x.get("b", ""), "q": x["q"], "a": x["a"], "m": int(x.get("m", 0))}
        for k in ("ex", "ca", "mn", "n"):
            if x.get(k): c[k] = x[k]
        if len(x.get("w", [])) >= 3: c["w"] = x["w"][:3]
        cards.append(c)
ORDER = ["الطهارة", "الصلاة", "الجنائز", "الزكاة", "الصيام", "الحج", "البيوع", "النكاح", "الطلاق", "العدة", "الرضاع", "النفقات", "الأطعمة", "الصيد", "الذبائح", "الأيمان"]
def rank(c):
    for i, k in enumerate(ORDER):
        if k in c["b"]: return i
    return len(ORDER)
cards = sorted(enumerate(cards), key=lambda ic: (rank(ic[1]), ic[0]))
cards = [c for _, c in cards]
for c in cards:
    if c["b"] == "الصيد": c["b"] = "الصيد والذبائح"
tpl = (D / "template.html").read_text(encoding="utf-8")
out = tpl.replace("/*CARDS*/[]", json.dumps(cards, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
(D / "index.html").write_text(out, encoding="utf-8")
print(len(cards), "بطاقة،", sum(1 for c in cards if c.get("ex")), "بشرح،", sum(1 for c in cards if c.get("w")), "بخيارات")
