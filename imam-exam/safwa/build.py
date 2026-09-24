# يبني صفحات الصفوة: Markdown → HTML مطبوع → PDF
import markdown, pathlib, subprocess, sys, os
D = pathlib.Path(__file__).parent
CSS = """
@page{size:A4}
:root{--ink:#16211C;--muted:#5A6660;--line:#D5DAD5;--accent:#145C49;--soft:#EEF3F0;--gold:#86672A}
body{font-family:"IBM Plex Sans Arabic",Tahoma,sans-serif;color:var(--ink);font-size:10.6pt;line-height:1.62;direction:rtl;margin:0}
h1{font-size:19pt;color:var(--accent);margin:0 0 4px;border-bottom:2px solid var(--accent);padding-bottom:6px}
h1+p{color:var(--muted);font-size:10pt;margin:0 0 10px}
h2{font-size:13.5pt;color:var(--accent);margin:16px 0 6px;break-after:avoid}
h3{font-size:11.8pt;margin:12px 0 4px;break-after:avoid}
p{margin:4px 0}
ul,ol{margin:4px 0;padding-inline-start:20px}
li{margin:2px 0}
strong{color:#0d4436}
table{border-collapse:collapse;width:100%;margin:6px 0 10px;font-size:9.6pt;break-inside:auto}
tr{break-inside:avoid}
th{background:var(--soft);color:var(--accent);font-weight:700}
th,td{border:1px solid var(--line);padding:3px 5px;vertical-align:top;text-align:right}
blockquote{margin:6px 0;padding:6px 10px;border-right:3px solid var(--gold);background:#F6F2E8;font-family:"Noto Naskh Arabic",serif}
hr{border:0;border-top:1px solid var(--line);margin:10px 0}
"""
def build(name):
    md = (D / f"{name}.md").read_text(encoding="utf-8")
    body = markdown.markdown(md, extensions=["tables", "sane_lists"])
    title = md.split("\n", 1)[0].lstrip("# ").strip()
    html = f"""<!doctype html><html lang="ar" dir="rtl"><head><meta charset="utf-8"><title>{title}</title>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@400;600;700&family=Noto+Naskh+Arabic:wght@400;600&display=swap">
<style>{CSS}</style></head><body>{body}</body></html>"""
    (D / f"{name}.html").write_text(html, encoding="utf-8")
    return str(D / f"{name}.html")
names = sys.argv[1:] or [p.stem for p in D.glob("*.md")]
paths = [build(n) for n in names]
subprocess.run(["node", str(D / "topdf.js"), *paths], check=True, env={**os.environ, "NODE_PATH": subprocess.check_output(["npm", "root", "-g"], text=True).strip()})
