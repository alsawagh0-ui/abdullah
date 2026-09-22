import sys
from dalil import *
for phrase in sys.argv[1:]:
    k=key(phrase); hits=[i for i,c in enumerate(chunks) if k in key(c["txt"])]
    print(f"== «{phrase}» →", hits[:8])
    for i in hits[:3]:
        t=clean(chunks[i]["txt"]); p=key(t).find(k)
        # قصّ حول الموضع تقريباً
        print(f"   c{i}[{chunks[i]['book']}]: {t[:260]}")
