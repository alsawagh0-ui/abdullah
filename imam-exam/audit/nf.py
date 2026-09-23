# مراجعة أسئلة غير الفقه على نص الكتاب (مصوَّر الكتاب بعد OCR)
#   python3 audit/nf.py export            يقسّم الأسئلة دفعات في audit/nf/items
#   python3 audit/nf.py check FILE...     يتحقق من ملف قرارات
#   python3 audit/nf.py apply             يطبّق كل القرارات في audit/nf/dec على البنوك
import json, re, sys, unicodedata
from pathlib import Path
from rapidfuzz import fuzz

ROOT = Path(__file__).resolve().parent.parent
BOOKS = Path("/tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books")
SUBJ = {
    "nahw":    ("nahw_t",    "التحفة السنية"),
    "hadith":  ("hadith_t",  "شرح ابن دقيق العيد على الأربعين"),
    "aqeedah": ("aqeedah_t", "بريق الجمان"),
    "mithaq":  ("mithaq_t",  "ميثاق المسجد"),
    "tajweed": ("tajweed_t", "شرح غاية المريد للأستاذة إيمان أحمد الشيخ"),
}
KINDS = ("mcq", "tf", "fill", "questions")
FIX_OK = {"mcq": {"q", "o", "c"}, "tf": {"q", "t"}, "fill": {"q", "a"}, "questions": {"q"}}
NF = ROOT / "audit" / "nf"
_D = re.compile(r"[ً-ٰٟـ]")

def letters(t):
    t = unicodedata.normalize("NFKC", t)
    t = _D.sub("", t)
    for a, b in (("أ","ا"),("إ","ا"),("آ","ا"),("ٱ","ا"),("ة","ه"),("ى","ي"),("ؤ","و"),("ئ","ي"),("ء","")):
        t = t.replace(a, b)
    return re.sub(r"[^ء-ي ]", "", re.sub(r"\s+", " ", t)).replace(" ", "")

_pages = {}
IMG = []   # شواهد مأخوذة من صورة الصفحة، تُعرض للمراجعة اليدوية
def page(sid, p):
    key = (sid, p)
    if key not in _pages:
        # نسخة OCR ثانية بدقة أعلى (إن وُجدت) تُضمّ إلى الأولى لتقليل أخطاء القراءة
        txt = ""
        for d in (SUBJ[sid][0], SUBJ[sid][0] + "2"):
            f = BOOKS / d / f"{p:03d}.txt"
            if f.exists(): txt += " " + f.read_text(encoding="utf-8")
        _pages[key] = letters(txt)
    return _pages[key]

def found(sid, p, text):
    """أعلى تطابق للنص في الصفحة أو ما يجاورها (يتسامح مع أخطاء OCR)."""
    q = letters(text)
    best = 0
    for pp in (p, p - 1, p + 1):
        hay = page(sid, pp)
        if hay: best = max(best, fuzz.partial_ratio(q, hay))
    return best

def banks():
    return {k: json.loads((ROOT / f"{k}.json").read_text(encoding="utf-8")) for k in KINDS}

def export(n=100):
    B = banks()
    out = NF / "items"; out.mkdir(parents=True, exist_ok=True)
    for sid in SUBJ:
        items = []
        for k in KINDS:
            for i, q in enumerate(B[k]):
                if q.get("s") != sid or q.get("rej"): continue
                it = {"k": k, "i": i}
                it.update({f: q[f] for f in ("q", "o", "c", "t", "a", "e") if f in q})
                items.append(it)
        for j in range(0, len(items), n):
            (out / f"{sid}_{j//n+1}.json").write_text(json.dumps(items[j:j+n], ensure_ascii=False, indent=0), encoding="utf-8")
        print(sid, len(items), "سؤالاً في", (len(items) + n - 1) // n, "دفعات")

def check(path):
    sid = Path(path).stem.split("_")[0]
    D = json.loads(Path(path).read_text(encoding="utf-8"))
    items = json.loads((NF / "items" / Path(path).name).read_text(encoding="utf-8"))
    want = {(x["k"], x["i"]) for x in items}
    B = banks(); bad = []; seen = set()
    for d in D:
        tag = f'{d.get("k")}#{d.get("i")}'
        key = (d.get("k"), d.get("i"))
        if key not in want: bad.append(f"{tag}: ليس في الدفعة"); continue
        seen.add(key)
        v = d.get("v")
        if v not in ("ok", "fix", "rej"): bad.append(f"{tag}: v"); continue
        if v in ("fix", "rej") and not d.get("why"): bad.append(f"{tag}: يحتاج why")
        if v == "rej": continue
        if v == "fix":
            fx = d.get("fix") or {}
            if not fx or set(fx) - FIX_OK[d["k"]]: bad.append(f"{tag}: حقول fix غير مسموحة {list(fx)}")
            if d["k"] == "mcq":
                o = fx.get("o", B["mcq"][d["i"]]["o"]); c = fx.get("c", B["mcq"][d["i"]]["c"])
                if len(o) != 4 or not (0 <= c < 4): bad.append(f"{tag}: خيارات")
        Q = d.get("quotes") or []
        if not Q: bad.append(f"{tag}: لا شاهد"); continue
        if not d.get("src"): bad.append(f"{tag}: لا src")
        for x in Q:
            if len(letters(x.get("t", ""))) < 12: bad.append(f"{tag}: شاهد قصير"); continue
            if x.get("img"):   # قُرئ من صورة الصفحة لأن OCR فاسد في هذا السطر؛ يُراجَع يدوياً
                IMG.append(f'{Path(path).name} {tag} ص {x.get("p")}: {x["t"]}'); continue
            s = found(sid, int(x.get("p", 0)), x["t"])
            if s < 80: bad.append(f'{tag}: الشاهد لم يوجد في ص {x.get("p")} (تطابق {s:.0f}): {x["t"][:60]}')
    miss = want - seen
    if miss: bad.append(f"لم يُقرر فيها: {sorted(miss)[:10]}{'...' if len(miss) > 10 else ''} ({len(miss)})")
    return bad, len(D)

def apply():
    B = banks(); st = {"ok": 0, "fix": 0, "rej": 0}; log = []
    for f in sorted((NF / "dec").glob("*.json")):
        sid = f.stem.split("_")[0]; book = SUBJ[sid][1]
        for d in json.loads(f.read_text(encoding="utf-8")):
            q = B[d["k"]][d["i"]]; before = dict(q)
            for x in ("src", "rej"): q.pop(x, None)
            st[d["v"]] += 1
            if d["v"] == "rej":
                q["rej"] = d["why"]; log.append({"f": f.name, "k": d["k"], "i": d["i"], "v": "rej", "why": d["why"], "before": before}); continue
            if d["v"] == "fix":
                q.update(d["fix"]); log.append({"f": f.name, "k": d["k"], "i": d["i"], "v": "fix", "why": d["why"], "before": before, "after": dict(q)})
            texts = [x["t"].strip() for x in d["quotes"]]
            src = f"{book}، {d['src']}"
            if d["k"] == "questions":
                q["a"] = " ".join(texts)
            else:
                q["e"] = " ".join("«" + t + "»" for t in texts)
            q["src"] = src
    for k in KINDS:
        (ROOT / f"{k}.json").write_text(json.dumps(B[k], ensure_ascii=False, indent=0), encoding="utf-8")
    (NF / "changes.json").write_text(json.dumps(log, ensure_ascii=False, indent=0), encoding="utf-8")
    print(st)

if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "export": export()
    elif cmd == "check":
        for p in sys.argv[2:]:
            bad, n = check(p)
            print(f"{Path(p).name}: {n} قراراً، مشكلات {len(bad)}")
            for b in bad[:60]: print("  -", b)
        for x in IMG: print("  [صورة]", x)
    elif cmd == "apply": apply()
