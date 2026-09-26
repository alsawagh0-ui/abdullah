# Task: verify the sheikh's fiqh Q&A against دليل الطالب and produce memorisation cards

Context: a student's exam (Kuwaiti imam/muezzin written exam) fiqh part is said to come from these questions (a course by الشيخ عبدالسلام الفيلكاوي). The answers were transcribed by an AI (Gemini) from the course and may contain mistakes. The prescribed book is «دليل الطالب لنيل المطالب» (مرعي الكرمي، الحنابلة). Rule: the answer the student memorises must match the book's own wording/ruling; where the course answer differs from the book, follow the book and flag it.

Input: /home/user/abdullah/imam-exam/sheikh/part_N.json — list of {id, book, chap, q, a}.

Book tools (run from /home/user/abdullah/imam-exam):
- `python3 audit/mfind.py "كلمة1" "كلمة2"` searches the OCR of the Dalil matn (pdf page files in /tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/dm/NNN.txt; printed page = pdf page + 8). Read whole pages with `cat` of that file.
- Clean, verified Dalil quotes: 27-الفقه-نصوص-دليل-الطالب.md and 07-دليل-الطالب-العبادات.md (summary), numbers.json (verified counts), and the verified bank questions.json/mcq.json/tf.json/fill.json (s=="fiqh", fields e=Dalil quote, src=page).
- Page image if OCR unclear: render /tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/dalil_matn.pdf page with pymupdf and Read the png.

For EACH item produce:
- `a`: the answer to memorise — short, in the book's words, COMPLETE (if the question says «اذكر…» and the course answer is vague like «(تُذكر 5 من الكتاب)» or only gives a count, write the book's full list; if the question asks for 5 of a long list, give the book's list and bold nothing — just list them). Keep it as short as possible while complete; lists separated by «،». Drop non-book additions (e.g. «90 كيلو», «85 غرام», «قبل الظهر بـ5 دقائق») unless the book says them — you may keep a modern equivalent only in `note`.
- `st`: "ok" (course answer matches the book), "fix" (course answer wrong/incomplete in substance — corrected), or "nb" (not found in the book / can't verify).
- `why`: for fix/nb, one short Arabic line saying what differed (e.g. «الكتاب: الأشرف لا الأشهر»).
- `p`: printed Dalil page (int) supporting it, or 0.
- `mn` (optional): a short mnemonic/memory hook in Arabic if the answer is a list of 4+ items (e.g. first letters), only if genuinely helpful.

Output: /home/user/abdullah/imam-exam/sheikh/ver_N.json — list of {id, a, st, why?, p, mn?} for every input id (keep order). Save progress as you go.
Final reply: counts ok/fix/nb and the list of every fix/nb as `id: why`.
