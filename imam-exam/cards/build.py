# يبني صفحة بطاقات الفقه (خاصة): أسئلة دورة الشيخ الفيلكاوي بعد مطابقتها على دليل الطالب
import json
from pathlib import Path
D = Path(__file__).resolve().parent
cards = [{k: v for k, v in c.items() if k not in ("o", "w", "st", "p")} for c in json.loads((D.parent / "sheikh" / "cards.json").read_text(encoding="utf-8"))]
tpl = (D / "template.html").read_text(encoding="utf-8")
out = tpl.replace("/*CARDS*/[]", json.dumps(cards, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
(D / "index.html").write_text(out, encoding="utf-8")
print(len(cards), "بطاقة")
