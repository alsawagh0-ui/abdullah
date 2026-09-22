#!/bin/bash
# يبني الموقع وينشره إلى مستودع alsawagh0-ui/imam-exam (يتحدّث الرابط تلقائياً)
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PUB="${PUB_DIR:?حدد PUB_DIR: مسار نسخة مستودع imam-exam}"
python3 "$ROOT/imam-exam/build.py"
cp "$ROOT/website/exam/index.html" "$PUB/index.html"
mkdir -p "$PUB/src"
cp "$ROOT/imam-exam/build.py" "$ROOT/imam-exam/template.html" "$PUB/src/"
cp "$ROOT"/imam-exam/*.json "$ROOT"/imam-exam/*.md "$PUB/src/"
cd "$PUB"
git add -A
git diff --cached --quiet && { echo "لا تغييرات"; exit 0; }
git -c user.email=alsawagh0@gmail.com -c user.name="Abdullah" commit -q -m "${1:-تحديث المحتوى}"
git push -q origin main
echo "نُشر: https://alsawagh0-ui.github.io/imam-exam/"
