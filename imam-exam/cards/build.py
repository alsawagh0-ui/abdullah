# يبني صفحة بطاقات الفقه (خاصة): إمام/مؤذن ثم البطاقات مباشرة، مع تكرار متباعد
import json, re, glob, unicodedata
from pathlib import Path
R = Path(__file__).resolve().parent.parent
def n(t):
    t = re.sub(r"[ً-ْـ]", "", unicodedata.normalize("NFKC", t))
    return re.sub(r"\W", "", t)
cov = {}
for f in glob.glob(str(R / "audit/cov/res_*.json")):
    for r in json.loads(Path(f).read_text(encoding="utf-8")): cov[(r["k"], r["i"])] = r["v"]
cards, seen = [], set()
for k in ("questions", "fill", "mcq", "tf"):
    for i, q in enumerate(json.loads((R / f"{k}.json").read_text(encoding="utf-8"))):
        if q["s"] != "fiqh" or q.get("rej") or q.get("sc") not in ("ibadat", "muamalat"): continue
        key = n(q["q"])
        if key in seen: continue
        seen.add(key)
        if k == "mcq": a, x = q["o"][q["c"]], ""
        elif k == "tf": a, x = ("صح" if q["t"] else "خطأ"), q.get("e", "")
        else: a, x = q["a"], ""
        pg = re.findall(r"ص (\d+)", q.get("src", ""))
        cards.append({"id": f"{k[0]}{i}", "q": q["q"] + ("  (صح أم خطأ؟)" if k == "tf" else ""), "a": a, "x": x,
                      "m": 1 if q["sc"] == "muamalat" else 0, "d": 1 if cov.get((k, i)) == "y" else 0,
                      "p": int(pg[0]) if pg else 0})
cards.sort(key=lambda c: (c["d"], c["p"]))   # ما ليس في مفيد الصاحب أولاً، ثم بترتيب الكتاب
tpl = (Path(__file__).parent / "template.html").read_text(encoding="utf-8")
out = tpl.replace("/*CARDS*/[]", json.dumps(cards, ensure_ascii=False, separators=(",", ":")).replace("</", "<\\/"))
(Path(__file__).parent / "index.html").write_text(out, encoding="utf-8")
print(len(cards), "بطاقة", sum(c["m"] for c in cards), "معاملات", sum(c["d"] for c in cards), "في المذكرة")
