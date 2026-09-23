# مهمة: مراجعة دفعة أسئلة على نص الكتاب

You are auditing one batch of exam-prep questions for a Kuwaiti imam/muezzin study site. The site's owner has a strict rule: **every answer must agree with the prescribed book, and every explanation shown to the student must be the book's own text** (quoted), never our own words. Where scholars differ, **follow the book's author**.

Batch file: `/home/user/abdullah/imam-exam/audit/nf/items/BATCH.json` (subject `SID`, book «BOOK»).
Each item: `k` (mcq | tf | fill | questions), `i` (index in that bank), `q`, and per kind: mcq `o` (4 options) + `c` (correct index); tf `t` (true/false); fill `a` (answer); questions `a` (model answer to an essay question). `e` is the current unverified explanation (ignore its wording; it is not book text).

## Tools (run from /home/user/abdullah/imam-exam)
- Search the book (OCR of the scanned book, one file per PDF page): `python3 audit/nf_find.py SID "عبارة من الكتاب" [n]` → best pages + matching lines. Show a whole page: `python3 audit/nf_find.py SID -p 45`.
- A clean (but summarised) study version of the same book, useful to know what the book says and where: `/home/user/abdullah/imam-exam/SUMMARY`. It is NOT the book; quotes must come from the OCR pages.
- If OCR of a line is too garbled to be sure of the wording, render the page and look at it: `python3 -c "import pymupdf;pymupdf.open('/tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/PDF').load_page(P-1).get_pixmap(dpi=110).save('/tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/pBATCH.png')"` then Read that png (P = page number).

## For every item decide
- `"ok"`: the marked answer is exactly what the book says.
- `"fix"`: the question is sound but the answer (or wording) contradicts the book or is ambiguous → give `fix` with only the changed fields (mcq: `q`/`o`/`c`; tf: `q`/`t`; fill: `q`/`a`; questions: `q`) and a short Arabic `why`. For mcq make sure exactly one option is correct per the book.
- `"rej"`: not in the book at all, not answerable from it, disputed with no author position, or hopelessly ambiguous → short Arabic `why`.
For ok/fix give `quotes`: 1–3 items `{"p": page, "t": "verbatim book text"}` that prove the answer, and `src`: the chapter/section as the book names it (e.g. "باب الفاعل", "الحديث السادس", "الفصل الثالث: ..."). Quotes: copy the book's words exactly as printed (fix obvious OCR letter garbage, keep wording; you may drop harakat), 1–2 sentences each, enough for a student to see the answer. For `questions` (essay) items the joined quotes become the model answer, so they must fully answer the question. No Quran verse text inside quotes unless unavoidable (prefer the author's words).

## Output
Write `/home/user/abdullah/imam-exam/audit/nf/dec/BATCH.json`: a JSON list with one object per item: `{"k","i","v","quotes"?,"src"?,"fix"?,"why"?}` (ensure_ascii=False). Work in chunks and save progress as you go (rewrite the file).
Then run `python3 audit/nf.py check audit/nf/dec/BATCH.json` and fix every reported problem until it reports 0 (the checker fuzzy-matches each quote against the OCR page p or p±1, threshold 80; if a true quote fails because OCR is bad, choose another sentence from the same place that matches).
Do not edit any other file.

Final reply (short): counts ok/fix/rej, and a list of every fix and rej as `k#i: why`.
