# يتحقق أن كل سؤال في تمارين الدروس جوابه نصٌّ منقول حرفياً من الدرس نفسه
import json, re, sys, unicodedata
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
BASICS = {"nahw": "20-من-الصفر-النحو.md", "aqeedah": "21-من-الصفر-العقيدة.md", "hadith": "22-من-الصفر-الحديث.md",
          "tajweed": "23-من-الصفر-التجويد.md", "tafsir": "24-من-الصفر-التفسير.md", "mithaq": "25-من-الصفر-ميثاق-المسجد.md"}
_D = re.compile(r"[ً-ْـ]")
def flat(t):
    t = unicodedata.normalize("NFKC", t)
    t = _D.sub("", t)
    for a, b in (("أ","ا"),("إ","ا"),("آ","ا"),("ة","ه"),("ى","ي"),("ؤ","و"),("ئ","ي")): t = t.replace(a, b)
    t = re.sub(r"[*|_#>`]", " ", t)
    return re.sub(r"\s+", " ", t).strip()
def lessons(md):
    out, cur = {}, None
    for line in md.split("\n"):
        if line.startswith("## "): cur = line[3:].strip(); out[cur] = []; continue
        if cur and not line.startswith("::"): out[cur].append(line)
    return {k: flat("\n".join(v)) for k, v in out.items()}
def check(sid):
    L = lessons((ROOT / BASICS[sid]).read_text(encoding="utf-8"))
    data = json.loads((ROOT / "lesson_q" / f"{sid}.json").read_text(encoding="utf-8"))
    bad = []
    for t, qs in data.items():
        if t not in L: bad.append(f"عنوان غير موجود: {t}"); continue
        for i, q in enumerate(qs):
            tag = f"{t} #{i+1}"
            if set(q) - {"q","o","c","e"} or not all(k in q for k in "qoce"): bad.append(f"{tag}: حقول"); continue
            if len(q["o"]) != 4 or len(set(q["o"])) != 4: bad.append(f"{tag}: الخيارات يجب أن تكون 4 مختلفة")
            if not (0 <= q["c"] < 4): bad.append(f"{tag}: c")
            if len(flat(q["e"])) < 8 or flat(q["e"]) not in L[t]: bad.append(f"{tag}: الشاهد ليس نصاً من الدرس: {q['e']}")
    return bad, sum(len(v) for v in data.values()), [t for t in L if t not in data]
if __name__ == "__main__":
    for sid in (sys.argv[1:] or BASICS):
        if not (ROOT / "lesson_q" / f"{sid}.json").exists(): print(sid, "لا ملف"); continue
        bad, n, missing = check(sid)
        print(f"{sid}: {n} سؤالاً، أخطاء {len(bad)}، دروس بلا تمرين: {missing}")
        for b in bad: print("  -", b)
