# Task: make a beginner lesson file agree 100% with its book

Site rule (owner accepts zero errors): lessons may use simple wording, but **every factual statement must be supported by the prescribed book**; where scholars differ, **follow the book's author**; anything the book doesn't say that could be examined must be removed or reworded to what the book says. **No Quran verse text** anywhere in lessons or exercises (a single word used as a tajweed/nahw example is allowed only if the book itself uses it; prefer non-Quranic examples otherwise).

Work in /home/user/abdullah/imam-exam. Book tools: `python3 audit/nf_find.py SID "عبارة" [n]` searches the OCR of the real book; `python3 audit/nf_find.py SID -p PAGE` prints a page. Clean summaries (not the book, but extracted from it): nahw 14-النحو-التحفة-السنية.md, aqeedah 13-العقيدة-بريق-الجمان-الأصل.md, hadith 12-الحديث-شرح-ابن-دقيق.md, tajweed 08-غاية-المريد-التجويد.md, mithaq 09-ميثاق-المسجد.md. Page images: PDFs in /tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books (nahw src03, hadith src02, aqeedah src04, mithaq src01, tajweed src06) — render a page with pymupdf and Read the png when OCR is unclear.

Steps:
1. Fix every reported problem listed in your assignment (verify each against the book first; if a report is wrong, leave it and say why).
2. Then re-read the WHOLE lesson file yourself sentence by sentence against the book and fix anything else unsupported or wrong (the reviewer may have missed things).
3. Update the lesson's exercises in lesson_q/SID.json: fix any exercise whose answer changed, remove/replace exercises on removed content; each exercise's `e` must be a verbatim snippet of that same lesson's text (the validator checks this). Keep 4 options, one correct.
4. Run `python3 audit/check_lesson_q.py SID` until 0 errors. Keep lesson titles (## lines) unchanged unless necessary; if you rename one, rename its key in lesson_q/SID.json too.
Edit only your lesson .md file and lesson_q/SID.json.

Final reply: list every change (before → after, with book page), and anything you judged the reviewer wrong about.
