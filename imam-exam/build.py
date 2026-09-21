#!/usr/bin/env python3
"""يبني صفحة الموقع من ملفات المذاكرة (Markdown) وبنك الأسئلة (JSON).

الاستخدام:  python3 imam-exam/build.py
الناتج:    website/exam/index.html  (صفحة واحدة، بدون خادم، بدون قاعدة بيانات)
لتغيير المقرر أو الدرجات عدّل TRACKS أدناه أو ملفات المحتوى فقط.
"""
import json, pathlib, datetime

ROOT = pathlib.Path(__file__).resolve().parent
OUT = ROOT.parent / "website" / "exam" / "index.html"

def md(name):
    return (ROOT / name).read_text(encoding="utf-8")

SUBJECTS = {
    "fiqh":    {"name": "الفقه",       "file": "01-الفقه-مفيد-الصاحب.md",      "source": "مفيد الصاحب في تلخيص دليل الطالب"},
    "hadith":  {"name": "الحديث",      "file": "02-الحديث-الأربعون-النووية.md", "source": "الأربعون النووية"},
    "aqeedah": {"name": "العقيدة",     "file": "03-العقيدة-بريق-الجمان.md",    "source": "تلخيص بريق الجمان"},
    "nahw":    {"name": "النحو",       "file": "06-النحو-مراجعة.md",           "source": "مراجعة مركزة"},
    "tafsir":  {"name": "التفسير",     "file": "04-التفسير-جزء-عم.md",         "source": "مختصر زبدة التفسير، جزء عم"},
    "tajweed": {"name": "التجويد",     "file": "05-التجويد.md",                "source": "أحكام التلاوة"},
    "mithaq":  {"name": "ميثاق المسجد","file": None,                            "source": "لم يُرسل المقرر بعد"},
}

# الدرجات لكل مسار. غيّرها هنا فقط.
TRACKS = {
    "imam": {
        "name": "إمام مسجد",
        "exam_date": "2026-10-06",
        "oral": "القرآن الكريم: مقابلة شفوية بعد الاختبار التحريري",
        "marks": {"fiqh": 60, "hadith": 10, "aqeedah": 10, "nahw": 10, "tafsir": 4, "tajweed": 4, "mithaq": 2},
        "notes": {"fiqh": "40 درجة عبادات + 20 درجة معاملات"},
        # عدد أسئلة الاختبار الفعلي لكل مادة (المجموع 50)
        "exam": {"fiqh": 30, "hadith": 5, "aqeedah": 5, "nahw": 5, "tafsir": 3, "tajweed": 2},
    },
    "muadhin": {
        "name": "مؤذن",
        "exam_date": "2026-10-06",
        "oral": "القرآن الكريم: مقابلة شفوية بعد الاختبار التحريري",
        # توزيع درجات المؤذنين لم يصل بعد؛ الترتيب حسب نموذج اختبار المؤذنين السابق.
        "marks": {"fiqh": None, "hadith": None, "aqeedah": None, "tafsir": None, "tajweed": None},
        "marks_pending": True,
        "notes": {},
        "exam": {"fiqh": 20, "hadith": 8, "aqeedah": 8, "tafsir": 7, "tajweed": 7},
    },
}

questions = json.loads((ROOT / "questions.json").read_text(encoding="utf-8"))
mcq = json.loads((ROOT / "mcq.json").read_text(encoding="utf-8"))
plan = md("00-الخطة-وتحليل-الاختبارات.md")

data = {"built": datetime.date.today().isoformat(), "plan": plan, "tracks": {}, "subjects": {}}
for sid, s in SUBJECTS.items():
    data["subjects"][sid] = {
        "name": s["name"], "source": s["source"],
        "notes": (md(s["file"]) + ("\n\n" + md("01b-الفقه-إضافات-من-دليل-الطالب.md") if sid=="fiqh" else "")) if s["file"] else "## المقرر لم يُرسل بعد\n\nأرسل صور أو ملف ميثاق المسجد ليُضاف هنا.",
        "questions": [q for q in questions if q["s"] == sid],
        "mcq": [q for q in mcq if q["s"] == sid],
    }
for tid, t in TRACKS.items():
    data["tracks"][tid] = t

template = (ROOT / "template.html").read_text(encoding="utf-8")
payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(template.replace("/*__DATA__*/null", payload), encoding="utf-8")
print("wrote", OUT, f"{OUT.stat().st_size/1024:.0f} KB")
