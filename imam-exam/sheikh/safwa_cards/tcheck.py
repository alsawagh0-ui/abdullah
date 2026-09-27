# يتحقق أن نصوص التفسير (bsrc) موجودة في كتاب مختصر زبدة التفسير (صفحات جزء عمّ 567–604)
# طبقة النص في الملف تُسقط أحياناً «ل» و«ا» (امعارج = المعارج)، فنطبّع بحذفهما مع التشكيل والهمزات
import sys, re, json, glob, os
from rapidfuzz import fuzz
TD = "/tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/tafsir"
def norm(s):
    s = re.sub(r"[ً-ْٰـ]", "", s)
    s = re.sub("[اأإآٱلءئؤ]", "", s).replace("ى", "ي").replace("ة", "ه")
    return re.sub(r"[^ء-ي0-9]", "", s)
pg = lambda p: norm(open(f"{TD}/{p}.txt").read()) if os.path.exists(f"{TD}/{p}.txt") else ""
bad = n = 0
f = sys.argv[1] if len(sys.argv) > 1 else os.path.dirname(os.path.abspath(__file__)) + "/s_tafsir.json"
for c in json.load(open(f)):
    srcs = c.get("bsrc"); srcs = srcs if isinstance(srcs, list) else [srcs]
    p = int(c.get("bp", 0))
    t = pg(p - 1) + pg(p) + pg(p + 1)
    for s in srcs:
        n += 1
        r = fuzz.partial_ratio(norm(s or ""), t) if t and s else 0
        if r < 85: bad += 1; print(f"✗ {c.get('id')} ص{p} ({r:.0f}): {(s or '')[:80]}")
print(f"{n} نص من الكتاب، {bad} غير مطابق")
