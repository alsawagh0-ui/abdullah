# بحث في نص دليل الطالب (أصل المتن) المستخرج آلياً من صور الصفحات
# الاستعمال: python3 mfind.py "كلمة1" "كلمة2" ...  (كل الكلمات في نفس السطر أو السطرين المتجاورين)
import sys, re, glob, os
DM = "/tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/dm"

def norm(s):
    s = re.sub(r"[ً-ْـٰ]", "", s)
    s = re.sub("[إأآٱ]", "ا", s).replace("ى", "ي").replace("ة", "ه").replace("ؤ", "و").replace("ئ", "ي")
    return s

def pages():
    for f in sorted(glob.glob(DM + "/*.txt")):
        yield int(os.path.basename(f)[:3]), open(f).read().splitlines()

def find(words, ctx=1, limit=12):
    ws = [norm(w) for w in words]
    hits = 0
    for p, lines in pages():
        nl = [norm(l) for l in lines]
        for i in range(len(lines)):
            win = " ".join(nl[i:i+2])
            if all(w in win for w in ws):
                print(f"--- pdf {p} line {i}")
                for l in lines[max(0, i-ctx):i+2+ctx]: print("   ", l)
                hits += 1
                if hits >= limit: return
                break

if __name__ == "__main__":
    find(sys.argv[1:])
