# Task: finalise the sheikh's fiqh questions for one part of the course

Context: a fiqh course (Hanbali, book «دليل الطالب لنيل المطالب») for the Kuwaiti imam/muezzin exam, taught as question-and-answer; the sheikh said the exam's fiqh questions will come from his questions. Students memorise them as flashcards. Owner's rule: every answer must agree with the book's wording/ruling (follow the book where the spoken answer differs) — but the student must never see that anything was corrected.

Work in /home/user/abdullah/imam-exam/sheikh/video. Inputs for part N:
- `chunk_N.txt`: the auto-generated YouTube Arabic transcript of this part ([h:mm:ss] lines; ASR errors — fix from fiqh context).
- `chunk_N_pro.json`: questions another assistant already extracted from this part: {وقت, باب, س, ج, كان_سؤالاً, _i}.
- `existing_174.json`: cards the student already has (from an earlier extraction of the same course): {id, b, q, a}.
Book tools (from /home/user/abdullah/imam-exam): `python3 audit/mfind.py "كلمة" "كلمة"` (Dalil OCR; printed page = pdf page + 8; page files /tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books/dm/NNN.txt), clean quotes 27-الفقه-نصوص-دليل-الطالب.md, 07-دليل-الطالب-العبادات.md, numbers.json, verified sheikh/cards.json.

Steps:
1. Read `chunk_N.txt` fully yourself. Find every question the sheikh poses/dictates (or says will come in the exam) that is MISSING from chunk_N_pro.json; add them (with time).
2. For each question (pro + added): if it duplicates a card in existing_174.json (same question, even if worded differently), set `dup` to that id and do nothing else for it. Also merge duplicates within this part.
3. For each remaining (new) question produce a card:
   - `t` time "h:mm:ss", `b` book (one of: الطهارة، الصلاة، الجنائز، الزكاة، الصيام والاعتكاف، الحج والأضحية، البيوع، النكاح وما يتبعه، الصيد والذبائح، الأطعمة، الأيمان والنذور، or another Dalil book name), `m` 1 if it belongs to المعاملات (بيوع، نكاح، طلاق، عدة، رضاع، نفقات، أطعمة، صيد، ذكاة، أيمان، نذور، جنايات…) else 0.
   - `q`: clear question in good Arabic (keep the sheikh's intent); `a`: the answer to memorise — the book's ruling/wording, short but complete (full lists). Check against the Dalil; if the spoken answer differs, use the book. If not in the Dalil at all, keep the sheikh's answer. Drop pure course-logistics items (e.g. «ما طريقة الشرح») unless they carry a fiqh fact.
   - `ex`: 2–4 short sentences (≤60 words) explaining it simply from the book (no reasons the book doesn't give; never mention course/sheikh/AI/corrections).
   - `w`: exactly 3 plausible but wrong options for multiple choice (same form as `a`, or as `ca` if you give one); `ca` optional short correct form (≤25 words) when `a` is long.
   - `mn` optional memory hook for lists of 4+.
   - `n` optional neutral note (e.g. modern equivalent); no mention of errors.
   - `p` printed Dalil page or 0.
Output `final_N.json`: list of {src:"pro"|"added", _i?, t, dup?} for duplicates, and full card objects {src,_i?,t,b,m,q,a,ex,w,ca?,mn?,n?,p} for new ones, in time order. Save progress as you go.
Final reply: counts (pro items, added, duplicates, new cards) and any doubtful items.
