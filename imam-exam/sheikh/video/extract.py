# يستخرج كل أسئلة الشيخ من الفيديو، جزءاً جزءاً (كل 10 دقائق مع تداخل 30 ثانية)
import json, sys, os, re
from gem import ask
MODEL = sys.argv[1] if len(sys.argv) > 1 else "gemini-3.8-flash"
TOTAL = 3*3600 + 40*60 + 9
SEG, OV = 600, 30
PROMPT = """هذا جزء من دورة شرح «دليل الطالب» في الفقه الحنبلي لاختبار الأئمة والمؤذنين، والشرح بطريقة سؤال وجواب.
المطلوب: استخرج **كل** سؤال طرحه الشيخ أو قرأه أو قال إنه يأتي في الاختبار، **في هذا الجزء فقط**، بالترتيب، مع جوابه **كما قاله الشيخ** كاملاً (إذا عدّد قائمة فاذكرها كلها، وإذا ذكر رقماً فاذكره).
- لا تلخّص، ولا تدمج سؤالين، ولا تحذف أي سؤال ولو كان قصيراً أو مكرراً أو لغزاً.
- اذكر الوقت بصيغة س:د:ث من بداية الفيديو كله (لا من بداية الجزء).
- إذا ذكر الشيخ تنبيهاً مهماً أو قاعدة بلا سؤال صريح فاكتبها سؤالاً بصيغة «ما حكم...؟» أو «ما ضابط...؟» وضع "كان_سؤالاً": false.
- اذكر الباب الفقهي لكل سؤال.
أخرج JSON فقط، مصفوفة من: {"وقت":"س:د:ث","باب":"...","س":"...","ج":"...","كان_سؤالاً":true}
إذا لم يكن في الجزء أي سؤال فأخرج []."""
os.makedirs(f"out_{MODEL}", exist_ok=True)
start = 0; i = 0
while start < TOTAL:
    i += 1; end = min(TOTAL, start + SEG + OV)
    f = f"out_{MODEL}/seg_{i:02d}.json"
    if not os.path.exists(f):
        txt = ask(PROMPT, start, end, model=MODEL, fps=0.2)
        m = re.search(r"\[.*\]", txt, re.S)
        try: data = json.loads(m.group(0)) if m else []
        except Exception: data = {"raw": txt}
        json.dump({"start": start, "end": end, "items": data}, open(f, "w", encoding="utf-8"), ensure_ascii=False, indent=1)
        print(i, start, end, len(data) if isinstance(data, list) else "RAW", flush=True)
    start += SEG
