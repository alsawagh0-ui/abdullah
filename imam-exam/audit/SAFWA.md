# Task: «الصفوة» — the 10 highest-yield pages for one subject

A student preparing for the Kuwaiti imam/muezzin written exam (in ~12 days) wants ONE document per subject: ~10 A4 pages that contain «صفوة الصفوة», so that studying only this is the best possible bet. Owner's rules: **every fact must come from the prescribed book** (follow the author where scholars differ); no counts the author doesn't state; **no Quran verse text** (a surah name or a single word is fine); plain clear Arabic.

Work in /home/user/abdullah/imam-exam. Inputs:
- The book: `python3 audit/nf_find.py SID "عبارة" [n]` / `python3 audit/nf_find.py SID -p PAGE` (OCR of the real book; SID = nahw, aqeedah, hadith, tajweed, mithaq). Page images: PDFs in /tmp/claude-0/-home-user-abdullah/3ddf3da9-bf47-5c93-b82c-0df8e8bb7451/scratchpad/books (nahw src03, hadith src02, aqeedah src04, mithaq src01, tajweed src06) — render with pymupdf and Read when OCR is unclear.
- Clean summaries of the book (extracted, not verbatim; verify against the book before relying on them): see SUMMARY below.
- The audited question banks (what gets asked): mcq.json, tf.json, fill.json, questions.json — items with `s == SID` and no `rej`; each has `e` (book quote) and `src` (chapter). Use them to measure **which topics are asked most** (count items per chapter/topic) and prioritize accordingly. Every fact tested by a frequent question should appear in the safwa.
- The beginner lesson (already corrected against the book): LESSON.

Output: `/home/user/abdullah/imam-exam/safwa/SID.md` in Markdown:
- Title line `# صفوة <subject name>` and one line saying the source book.
- Organized by the book's chapters, most-asked first where sensible; use short bullets, compact tables for lists/counts, **bold** for the exact word that is asked. Each bullet ends with the page in the form `(ص N)` using the page number nf_find uses.
- Include a final section «أسئلة تتكرر» — 15–25 one-line Q → A pairs of the most frequently asked facts.
- Length: about 3,000–3,800 Arabic words (≈10 printed pages). Dense but readable; no fluff, no advice paragraphs.
- Before finishing, re-read every line against the book and remove anything you cannot point to in it.

Final reply: word count, the topic-frequency table you used (topic → number of bank questions), and anything you excluded as unsupported.
