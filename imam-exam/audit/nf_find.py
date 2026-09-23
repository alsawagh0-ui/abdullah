# يبحث في نص الكتاب المصوَّر (OCR) عن عبارة ويعرض أقرب الصفحات
#   python3 audit/nf_find.py SID "عبارة" [عدد]     |   python3 audit/nf_find.py SID -p 45   (يعرض الصفحة)
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))
import nf
from rapidfuzz import fuzz
sid = sys.argv[1]
d = nf.BOOKS / nf.SUBJ[sid][0]
if sys.argv[2] == "-p":
    print((d / f"{int(sys.argv[3]):03d}.txt").read_text(encoding="utf-8")); sys.exit()
q = nf.letters(sys.argv[2]); n = int(sys.argv[3]) if len(sys.argv) > 3 else 5
res = []
for f in sorted(d.glob("*.txt")):
    raw = f.read_text(encoding="utf-8")
    s = fuzz.partial_ratio(q, nf.letters(raw))
    res.append((s, int(f.stem), raw))
for s, p, raw in sorted(res, reverse=True)[:n]:
    lines = [l for l in raw.split("\n") if fuzz.partial_ratio(q, nf.letters(l)) >= 70 or fuzz.partial_ratio(nf.letters(l), q) >= 80]
    print(f"== ص {p}  تطابق {s:.0f}")
    for l in lines[:4]: print("   ", l.strip()[:160])
