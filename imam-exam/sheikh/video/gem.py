# استدعاء جيمناي على فيديو يوتيوب (المفتاح يُضاف تلقائياً من إعدادات البيئة)
import json, sys, urllib.request, time
URL = "https://www.youtube.com/watch?v=S3gZAPjS65s"
def ask(prompt, start=None, end=None, model="gemini-3.1-pro-preview", fps=0.2, tries=4):
    part = {"file_data": {"file_uri": URL, "mime_type": "video/*"}}
    vm = {"fps": fps}
    if start is not None: vm["start_offset"] = f"{int(start)}s"
    if end is not None: vm["end_offset"] = f"{int(end)}s"
    part["video_metadata"] = vm
    body = {"contents": [{"parts": [part, {"text": prompt}]}],
            "generationConfig": {"temperature": 0.1, "maxOutputTokens": 32000}}
    req = urllib.request.Request(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent",
                                 data=json.dumps(body).encode(), headers={"Content-Type": "application/json"})
    for t in range(tries):
        try:
            r = json.load(urllib.request.urlopen(req, timeout=600))
            return "".join(p.get("text", "") for p in r["candidates"][0]["content"]["parts"])
        except Exception as e:
            err = e.read().decode()[:500] if hasattr(e, "read") else str(e)
            print("retry", t, err, file=sys.stderr)
            if getattr(e, "code", 500) in (400, 401, 403, 404): break
            time.sleep(10 * (t + 1))
    raise SystemExit("failed")
if __name__ == "__main__":
    print(ask(sys.argv[1], *(float(x) for x in sys.argv[2:4]) if len(sys.argv) > 2 else ()))
