"""توليد سيناريو الدرس (شرائح) وأسئلة الاختبار عبر LLM.

يُستدعى هذا الملف من داخل مهمة Celery غير المتزامنة (انظر
app/services/tasks.py)، وليس مباشرة من نقطة نهاية HTTP، لأن استدعاء
LLM قد يستغرق عدة ثوانٍ.
"""

import json

import anthropic

from app.config import settings

client = anthropic.Anthropic(api_key=settings.anthropic_api_key)

LESSON_SCRIPT_SYSTEM_PROMPT = """\
أنت مدرّس خبير تكتب سيناريو شرح لدرس مدرسي على هيئة شرائح متتالية،
سيُقرأ نصها لاحقاً بصوت مسموع للطالب. اتّبع القواعد التالية بدقة:

1. أخرج JSON فقط، بلا أي نص خارج كائن JSON، مطابقاً تماماً لهذا الشكل:
   {
     "title": "عنوان الدرس",
     "slides": [
       {
         "type": "intro" | "example" | "summary",
         "title": "عنوان الشريحة",
         "body_text": "نص الشرح الذي سيُقرأ صوتياً، بلغة عربية مبسطة",
         "bullet_points": ["نقطة 1", "نقطة 2"]
       }
     ]
   }
2. لا تقل نسبة الشرائح من نوع "example" (مثال تطبيقي محلول خطوة بخطوة)
   عن 50% من إجمالي عدد الشرائح.
3. اجعل "body_text" مناسباً للقراءة الصوتية: جمل قصيرة وواضحة، بلا رموز
   أو صيغ يصعب نطقها.
4. عدد الشرائح بين 6 و16 حسب طول الدرس.
"""

QUIZ_SYSTEM_PROMPT = """\
أنت معلّم تصمم أسئلة اختيار من متعدد لقياس فهم الطالب لدرس معيّن. أخرج
JSON فقط مطابقاً لهذا الشكل:
{
  "questions": [
    {
      "question_text": "نص السؤال",
      "choices": [{"id": "a", "text": "..."}, {"id": "b", "text": "..."}, {"id": "c", "text": "..."}, {"id": "d", "text": "..."}],
      "correct_choice_id": "a",
      "explanation": "شرح مختصر لسبب صحة الإجابة"
    }
  ]
}
اجعل الأسئلة متنوعة (لا تكرر نفس الصياغة)، وغطِّ المفاهيم الأساسية
والأمثلة التطبيقية الواردة في الدرس معاً.
"""


def _extract_json(raw_text: str) -> dict:
    start = raw_text.find("{")
    end = raw_text.rfind("}") + 1
    return json.loads(raw_text[start:end])


def generate_lesson_script(lesson_text: str) -> dict:
    """يرسل نص الدرس المستخلص من PDF إلى LLM ويعيد بنية الشرائح (بلا صوت بعد)."""
    response = client.messages.create(
        model=settings.llm_model,
        max_tokens=4096,
        system=LESSON_SCRIPT_SYSTEM_PROMPT,
        messages=[{"role": "user", "content": f"نص الدرس:\n\n{lesson_text}"}],
    )
    raw_text = response.content[0].text
    return _extract_json(raw_text)


def generate_quiz_questions(lesson_text: str, question_count: int = 5) -> dict:
    """يولّد أسئلة اختيار من متعدد متغيرة بناءً على نص الدرس."""
    response = client.messages.create(
        model=settings.llm_model,
        max_tokens=2048,
        system=QUIZ_SYSTEM_PROMPT,
        messages=[
            {
                "role": "user",
                "content": f"نص الدرس:\n\n{lesson_text}\n\nولّد {question_count} أسئلة.",
            }
        ],
    )
    raw_text = response.content[0].text
    return _extract_json(raw_text)
