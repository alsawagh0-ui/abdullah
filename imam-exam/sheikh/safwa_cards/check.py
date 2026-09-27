# يتحقق أن كل بطاقة صفوة مأخوذة من ملف الصفوة: الحقل e نص حرفي منه (بعد حذف ** والمسافات الزائدة)
import sys, json, re, glob, os
H = os.path.dirname(os.path.abspath(__file__)); SW = os.path.join(H, "../../safwa")
def clean(s): return re.sub(r"\s+", " ", s.replace("**", "").replace("*", "")).strip()
bad = n = 0
for f in (sys.argv[1:] or sorted(glob.glob(H + "/s_*.json"))):
    subj = os.path.basename(f)[2:-5]
    src = clean(open(f"{SW}/{subj}.md").read())
    cards = json.load(open(f)); ids = set()
    for c in cards:
        n += 1; errs = []
        for k in ("id", "b", "q", "a", "e"):
            if not c.get(k): errs.append("ناقص " + k)
        if c.get("id") in ids: errs.append("id مكرر")
        ids.add(c.get("id"))
        es = c.get("e") if isinstance(c.get("e"), list) else [c.get("e", "")]
        for e in es:
            if clean(e) not in src: errs.append("e ليس في الصفوة: " + e[:60])
        if len(c.get("w", [])) != 3 or len(set(c.get("w", []))) != 3: errs.append("w يجب 3 مختلفة")
        if c.get("for") not in ("both", "imam", "muadhin"): errs.append("for")
        if errs: bad += 1; print("✗", os.path.basename(f), c.get("id"), "؛ ".join(errs))
print(f"{n} بطاقة، {bad} فيها مشكلة")
