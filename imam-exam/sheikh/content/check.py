# يتحقق أن كل «src» في ملفات المحتوى نصٌّ من دليل الطالب (مطابقة تقريبية ≥80 مع صفحات pdf p-1..p+1)
# الاستعمال: python3 check.py [ملف.json ...]
import sys, re, json, glob, os
from rapidfuzz import fuzz
DM = "/tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/dm"
def norm(s):
    s = re.sub(r"[ً-ْـٰ]", "", s)
    s = re.sub("[إأآٱ]", "ا", s).replace("ى", "ي").replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي")
    s = re.sub(r"[^ء-ي0-9 ]", " ", s)
    return re.sub(r"\s+", " ", s).strip()
_cache = {}
def page(p):
    if p not in _cache:
        f = f"{DM}/{p:03d}.txt"
        _cache[p] = norm(open(f).read()) if os.path.exists(f) else ""
    return _cache[p]
def ok(src, p):
    t = " ".join(page(q) for q in (p - 1, p, p + 1))
    return fuzz.partial_ratio(norm(src), t) if t else 0
def walk(o, path=""):
    if isinstance(o, dict):
        if "src" in o and "pdf" in o: yield path, o
        for k, v in o.items(): yield from walk(v, f"{path}.{k}")
    elif isinstance(o, list):
        for i, v in enumerate(o): yield from walk(v, f"{path}[{i}]")
files = sys.argv[1:] or sorted(glob.glob(os.path.dirname(os.path.abspath(__file__)) + "/c_*.json"))
bad = n = 0
for f in files:
    d = json.load(open(f))
    for path, o in walk(d):
        srcs = o["src"] if isinstance(o["src"], list) else [o["src"]]
        for s in srcs:
            n += 1; r = ok(s, int(o["pdf"]))
            if r < 80: bad += 1; print(f"✗ {os.path.basename(f)} {path} pdf{o['pdf']} ({r:.0f}): {s[:90]}")
print(f"{n} نص، {bad} غير مطابق")
