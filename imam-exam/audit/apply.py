# يطبّق قرارات dec.py على بنوك الأسئلة: الرفض، والتصحيح، وكتابة الشرح من نص دليل الطالب
import json, dec
from dalil import chunks
from quote import quote

ROOT = "/home/user/abdullah/imam-exam/"
BOOK = {"الطهارة": "كتاب الطهارة", "الصلاة": "كتاب الصلاة", "الجنائز": "كتاب الجنائز",
        "الزكاة": "كتاب الزكاة", "الصوم والاعتكاف": "كتاب الصيام", "الحج والعمرة": "كتاب الحج"}

def explain(refs):
    parts, srcs = [], []
    for r in refs:
        t, p = quote(r)
        parts.append("«" + t + "»")
        s = f"دليل الطالب، ص {p}" if p else f"دليل الطالب، {BOOK[chunks[r]['book']]}"
        if s not in srcs: srcs.append(s)
    return " ".join(parts), "؛ ".join(srcs)

def main():
  stats = {"ok": 0, "fix": 0, "rej": 0}
  changes = []
  for kind in ("mcq", "tf", "fill", "questions"):
      path = ROOT + kind + ".json"
      L = json.load(open(path, encoding="utf-8"))
      for (k, i), v in dec.D.items():
          if k != kind: continue
          q = L[i]
          before = dict(q)
          for f in ("e", "src", "rej"): q.pop(f, None)
          if isinstance(v, str):
              q["rej"] = v[4:] if v.startswith("rej:") else v
              stats["rej"] += 1
              changes.append((kind, i, "rej", before, q))
              continue
          refs = v
          if isinstance(v, tuple):
              _, fx, refs = v
              q.update(fx)
              stats["fix"] += 1
              changes.append((kind, i, "fix", before, dict(q)))
          else:
              stats["ok"] += 1
          e, src = explain(refs)
          if kind == "questions":
              q["a"] = e.replace("«", "").replace("»", "")   # الإجابة النموذجية = نص الكتاب
              q["src"] = src
          else:
              q["e"], q["src"] = e, src
      json.dump(L, open(path, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
  print(stats)
  json.dump([{"k": k, "i": i, "t": t, "before": b, "after": a} for k, i, t, b, a in changes],
            open(ROOT + "audit/changes.json", "w", encoding="utf-8"), ensure_ascii=False, indent=0)

if __name__ == "__main__":
    main()
