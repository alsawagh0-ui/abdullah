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
tpl = (D / "template.html").read_text(encoding="utf-8")
out = tpl.replace("/*CARDS*/[]", json.dumps(cards, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
(D / "index.html").write_text(out, encoding="utf-8")
print(len(cards), "بطاقة،", sum(1 for c in cards if c.get("ex")), "بشرح،", sum(1 for c in cards if c.get("w")), "بخيارات")
