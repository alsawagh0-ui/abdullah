"""مهام Celery غير المتزامنة: خط الأنابيب الكامل من نص الدرس إلى شرح جاهز.

يُشغَّل الـ worker بأمر منفصل عن API:
    celery -A app.tasks worker --loglevel=info
"""

import asyncio
from datetime import datetime

from celery import Celery
from sqlalchemy import select

from app.config import settings
from app.database import async_session
from app.models import GeneratedContent, Lesson
from app.services.ai_service import generate_lesson_script
from app.services.tts_service import synthesize_slide_audio

celery_app = Celery("edu_platform", broker=settings.redis_url, backend=settings.redis_url)


@celery_app.task(name="generate_lesson_content")
def generate_lesson_content_task(lesson_id: str) -> str:
    """المهمة المُشغَّلة من نقطة النهاية POST /lessons/{id}/generate."""
    return asyncio.run(_generate_lesson_content(lesson_id))


async def _generate_lesson_content(lesson_id: str) -> str:
    async with async_session() as db:
        lesson = (await db.execute(select(Lesson).where(Lesson.id == lesson_id))).scalar_one()
        lesson.status = "processing"
        await db.commit()

        try:
            # 1) LLM: تبسيط النص إلى بنية شرائح (بلا صوت بعد)
            script = generate_lesson_script(lesson.extracted_text)

            # 2) TTS: توليد صوت لكل شريحة ورفعه، وحساب المدة الفعلية
            total_duration = 0
            for index, slide in enumerate(script["slides"]):
                slide["slide_index"] = index
                narration = slide["body_text"]
                audio_url, duration = synthesize_slide_audio(narration, lesson_id, index)
                slide["audio_url"] = audio_url
                slide["duration_seconds"] = round(duration, 1)
                slide.setdefault("image_url", None)
                total_duration += duration

            lesson_script = {
                "lesson_id": lesson_id,
                "subject": lesson.subject.name if lesson.subject else "",
                "title": script.get("title", lesson.title),
                "generated_at": datetime.utcnow().isoformat(),
                "total_duration_seconds": round(total_duration),
                "slides": script["slides"],
            }

            db.add(
                GeneratedContent(
                    lesson_id=lesson.id,
                    lesson_script=lesson_script,
                    llm_model_used=settings.llm_model,
                    total_duration_seconds=round(total_duration),
                )
            )
            lesson.status = "ready"
            await db.commit()
            return "ready"

        except Exception:
            lesson.status = "failed"
            await db.commit()
            raise
