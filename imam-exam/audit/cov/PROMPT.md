# Task: would a student who memorised «مفيد الصاحب» answer these fiqh questions?

Read the memo completely: /home/user/abdullah/imam-exam/audit/cov/memo.md (the memo's summary notes + all its Q&A cards; the «تصحيح من دليل الطالب» lines are NOT in the memo — ignore them when judging, except to detect contradictions).

Batch: /home/user/abdullah/imam-exam/audit/cov/items_N.json — fiqh exam questions with their correct answer (per دليل الطالب). For EACH item decide, strictly, whether a student who knows ONLY the memo (word for word) would get it right:
- "y": the memo states the fact needed, clearly enough to answer (for MCQ, enough to pick the right option; for essay/fill, the main content of the answer).
- "p": partly — the memo gives some of it (e.g. part of a list, or the topic but not the specific detail) so the student might guess or get partial marks.
- "n": the memo doesn't contain it.
- "x": the memo says something that contradicts the correct answer (student would answer wrong).
Be strict: general knowledge or "could reason it out" doesn't count; only what the memo says.

Write /home/user/abdullah/imam-exam/audit/cov/res_N.json: a JSON list of {"k","i","v","topic"} where topic is a short Arabic chapter label (e.g. "الطهارة: المياه", "الحج: المحظورات", "البيوع"). Save progress as you go.
Final reply: counts of y/p/n/x, and the 10 biggest gaps (topics with many "n").
