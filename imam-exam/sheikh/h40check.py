# يتحقق من مقاطع الأربعين: كل نقطة شرح وكل جواب له دليل: e من صفوة الحديث حرفياً، أو bsrc من شرح ابن دقيق العيد (OCR) بتطابق ≥80
import sys, json, re
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "audit"))
import nf
from rapidfuzz import fuzz
H = Path(__file__).resolve().parent
clean = lambda s: re.sub(r"\s+", " ", s.replace("**", "")).strip()
SW = clean((H.parent / "safwa/hadith.md").read_text(encoding="utf-8"))
D = nf.BOOKS / nf.SUBJ["hadith"][0]
def page(p):
    f = D / f"{int(p):03d}.txt"
    return nf.letters(f.read_text(encoding="utf-8")) if f.exists() else ""
def proof(o, where):
    global bad, n
    n += 1
    if o.get("e"):
        es = o["e"] if isinstance(o["e"], list) else [o["e"]]
        for e in es:
            if clean(e) not in SW: bad += 1; print("✗", where, "e ليس في الصفوة:", e[:70])
        return
    if o.get("bsrc") and o.get("bp"):
        t = page(o["bp"] - 1) + page(o["bp"]) + page(o["bp"] + 1)
        for s in (o["bsrc"] if isinstance(o["bsrc"], list) else [o["bsrc"]]):
            r = fuzz.partial_ratio(nf.letters(s), t)
            if r < 80: bad += 1; print(f"✗ {where} ص{o['bp']} ({r:.0f}):", s[:70])
        return
    bad += 1; print("✗", where, "بلا دليل")
bad = n = 0
clips = json.load(open(sys.argv[1] if len(sys.argv) > 1 else H / "h40_clips.json"))
for c in clips:
    for i, p in enumerate(c.get("pts", [])): proof(p, f"{c['n']}.pts[{i}]")
    for i, q in enumerate(c.get("ask", [])):
        proof(q, f"{c['n']}.ask[{i}]")
        if len(q.get("w", [])) != 3: bad += 1; print("✗", c["n"], "ask w يجب 3")
print(f"{n} دليل، {bad} مشكلة")
