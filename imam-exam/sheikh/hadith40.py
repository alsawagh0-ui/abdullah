# يولّد بطاقات الأربعين (الراوي، ومن أخرجه، والرواة والعدد) من جدول صفوة الحديث المطابَق على شرح ابن دقيق العيد
import re, json, random
from pathlib import Path
H = Path(__file__).resolve().parent
md = (H.parent / "safwa/hadith.md").read_text(encoding="utf-8")
rows = []
for line in md.splitlines():
    m = re.match(r"^\| (\d+) \| (.+?) \| (.+?) \| (.+?) \| ([\d–]+) \|$", line)
    if m: rows.append(dict(n=int(m[1]), start=m[2].strip(), rawi=m[3].strip(), rec=m[4].strip(), p=m[5]))
assert len(rows) == 42, len(rows)
plain = lambda s: s.replace("**", "").strip()
def rshort(r):
    if r["n"] == 27: return "النواس بن سمعان ووابصة بن معبد"
    b = re.findall(r"\*\*(.+?)\*\*", r["rawi"])
    return " و".join(x.strip() for x in b) if b else plain(r["rawi"])
NAMES = ["البخاري", "مسلم", "أبو داود", "الترمذي", "النسائي", "ابن ماجه", "الدارقطني", "البيهقي", "أحمد", "الدارمي", "مالك", "كتاب الحجة"]
def xshort(r):
    if r["n"] == 27: return "حديث النواس: مسلم، وحديث وابصة: أحمد والدارمي"
    t = plain(r["rec"]); found = []
    for nm in NAMES:
        i = t.find(nm)
        if i >= 0 and nm not in found: found.append((i, nm))
    found = [nm for _, nm in sorted(found)]
    return " و".join(found)
def start(r): return plain(r["start"])
# نفس الصحابي بأسماء مختلفة في الجدول: نوحّد الاسم المختصر عشان ما يطلع خياران لشخص واحد
CANON = {"عبد الله بن عمر": "ابن عمر", "عبد الله بن مسعود": "ابن مسعود", "عبد الله بن عباس": "ابن عباس",
         "أبو ذر الغفاري": "أبو ذر", "سعد بن مالك بن سنان الخدري": "أبو سعيد الخدري", "أنس": "أنس بن مالك"}
for r in rows: r["rs"], r["xs"] = CANON.get(rshort(r), rshort(r)), xshort(r)
random.seed(40)
cards = []
def opts(right, pool):
    c = [x for x in dict.fromkeys(pool) if x != right]
    random.shuffle(c); return c[:3]
allR = [r["rs"] for r in rows]; allX = [r["xs"] for r in rows]
for r in rows:
    s = start(r); tag = f"الحديث {r['n']}: {s}"
    cards.append({"id": f"h{r['n']}r", "b": "الأربعون: الراوي", "q": f"من راوي حديث: «{s}»؟", "a": plain(r["rawi"]), "ca": r["rs"], "w": opts(r["rs"], allR), "ex": f"{tag} — الراوي: {plain(r['rawi'])}. رواه: {plain(r['rec'])}.", "for": "both"})
    cards.append({"id": f"h{r['n']}x", "b": "الأربعون: من أخرجه", "q": f"من أخرج (روى) حديث: «{s}»؟", "a": plain(r["rec"]), "ca": r["xs"], "w": opts(r["xs"], allX), "ex": f"{tag} — الراوي: {plain(r['rawi'])}. رواه: {plain(r['rec'])}.", "for": "both"})
# الرواة والعدد: من سطر «مفاتيح للحفظ»
keys = md[md.index("**مفاتيح للحفظ"):md.index("## مقدمة النووي")]
km = re.search(r"- \*\*أبو هريرة\*\*.+", keys)[0]
groups = re.findall(r"\*\*(.+?)\*\*: ([\d، ]+)", km)
byn = {r["n"]: r for r in rows}
AR = {2: "حديثان", 3: "ثلاثة أحاديث", 4: "أربعة أحاديث", 5: "خمسة أحاديث", 9: "تسعة أحاديث"}
counts = [len(re.findall(r"\d+", g[1])) for g in groups]
for name, nums in groups:
    name = {"عمر": "عمر بن الخطاب"}.get(name, name)
    ns = [int(x) for x in re.findall(r"\d+", nums)]
    lst = "، ".join(f"({n}) {start(byn[n])}" for n in ns)
    wrong = [AR[k] for k in AR if k != len(ns)]; random.shuffle(wrong)
    cards.append({"id": f"hk_{len(cards)}", "b": "الأربعون: الرواة والعدد", "q": f"كم حديثاً رواه {name} في الأربعين النووية؟ وما هي؟", "a": f"{AR.get(len(ns), str(len(ns)))}: {lst}", "ca": AR.get(len(ns), str(len(ns))), "w": wrong[:3], "ex": f"أحاديث {name} في الأربعين: {lst}.", "for": "both"})
# من روى حديثاً واحداً فقط: سؤال معكوس
inGroup = {int(x) for _, nums in groups for x in re.findall(r"\d+", nums)}
for r in rows:
    if r["n"] in (18, 27) or r["n"] in inGroup: continue
    nm = r["rs"]
    others = [start(x) for x in rows if x["n"] != r["n"]]
    cards.append({"id": f"h{r['n']}v", "b": "الأربعون: الرواة والعدد", "q": f"ما الحديث الذي راويه {nm} في الأربعين النووية؟", "a": start(r), "w": opts(start(r), others), "ex": f"الحديث {r['n']}: «{start(r)}» — الراوي: {plain(r['rawi'])}. رواه: {plain(r['rec'])}.", "for": "both"})
# انفرد به البخاري / مسلم / ليست في الصحيحين
for label, pat in [("انفرد بها البخاري", r"انفرد به \*\*البخاري\*\*: ([\d، ]+)"), ("انفرد بها مسلم", r"انفرد به \*\*مسلم\*\*: ([\d، ]+)"), ("ليست في الصحيحين بهذا اللفظ", r"ليست في الصحيحين\*\* بهذا اللفظ: ([\d، ]+)")]:
    m = re.search(pat, keys)
    if not m: continue
    ns = [int(x) for x in re.findall(r"\d+", m[1])]
    lst = "، ".join(f"({n}) {start(byn[n])}" for n in ns)
    cards.append({"id": f"hk_{len(cards)}", "b": "الأربعون: الرواة والعدد", "q": f"ما أحاديث الأربعين التي {label}؟", "a": lst, "ex": f"{label}: {lst}.", "for": "both"})
(H / "safwa_cards" / "h40.json").write_text(json.dumps(cards, ensure_ascii=False, indent=1), encoding="utf-8")
print(len(cards), "بطاقة")
for c in cards[:4] + cards[84:92] + cards[-4:]: print(c["id"], c["q"], "→", c.get("ca") or c["a"][:80], "| w:", c.get("w"))
