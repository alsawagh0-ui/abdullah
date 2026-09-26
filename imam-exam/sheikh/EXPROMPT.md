# Task: teaching material for fiqh flashcards (explanation + multiple-choice distractors)

A student memorises these fiqh Q&A cards for a written exam (Hanbali, book «دليل الطالب»). Each card's `a` is already verified against the book. When the student fails a card, the app (1) explains it, (2) quizzes it as multiple choice, (3) asks recall, (4) asks them to write it. You produce the material for (1) and (2).

Input: /home/user/abdullah/imam-exam/sheikh/ex_in_N.json — list of {id, b (book), q, a}.
Book tools (from /home/user/abdullah/imam-exam): `python3 audit/mfind.py "كلمة" "كلمة"` searches the Dalil OCR; clean quotes in 27-الفقه-نصوص-دليل-الطالب.md, 07-دليل-الطالب-العبادات.md, numbers.json.

For each card write:
- `ex`: a short explanation in simple Arabic (2–4 short sentences, ≤ 60 words) that makes the answer UNDERSTANDABLE and memorable: the idea/reason behind it, how the parts relate, a way to remember the list (grouping, count, first letters, a contrast with a similar rule). Stay consistent with `a` and the book — do not add rulings that aren't in the book; do not contradict `a`. No Quran verse text. Never mention any course, sheikh, AI, or corrections.
- `wrong`: exactly 3 wrong options for a multiple-choice version of the card. Each must be plausible (same form and length as `a`, e.g. a different number, a swapped ruling يكره/يحرم/يسن, a list with one item replaced by an item from a neighbouring list) but clearly wrong according to the book. If `a` is long, you may instead write a shortened correct form `ca` (≤ 25 words, still correct and complete enough to be recognisable) and make the 3 wrong options in the same short form.

Output /home/user/abdullah/imam-exam/sheikh/ex_N.json: list of {id, ex, wrong:[3], ca?} for every input id, same order. Save progress as you go. Final reply: count done and any card where you had doubts.
