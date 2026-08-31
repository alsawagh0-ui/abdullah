import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Enrollment, GeneratedContent, Lesson, Subject
from app.schemas import GenerateLessonResponse, LessonOut, LessonScript, SubjectOut
from app.security import get_current_student_id
from app.services.pdf_service import extract_text_from_pdf
from app.tasks import generate_lesson_content_task

router = APIRouter(tags=["lessons"])


@router.get("/subjects/me", response_model=list[SubjectOut])
async def my_subjects(
    student_id: uuid.UUID = Depends(get_current_student_id),
    db: AsyncSession = Depends(get_db),
):
    """جميع المواد المقررة على الطالب — تُعرض فور تسجيل الدخول (Dashboard)."""
    stmt = select(Subject).join(Enrollment).where(Enrollment.student_id == student_id)
    subjects = (await db.execute(stmt)).scalars().all()
    return subjects


@router.get("/subjects/{subject_id}/lessons", response_model=list[LessonOut])
async def subject_lessons(subject_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    stmt = select(Lesson).where(Lesson.subject_id == subject_id)
    lessons = (await db.execute(stmt)).scalars().all()
    return lessons


@router.post("/lessons/{subject_id}/upload", response_model=LessonOut)
async def upload_lesson(
    subject_id: uuid.UUID,
    title: str,
    file: UploadFile,
    db: AsyncSession = Depends(get_db),
):
    """رفع كتاب/درس PDF واستخلاص نصه تمهيداً للتوليد."""
    file_bytes = await file.read()
    extracted_text = extract_text_from_pdf(file_bytes)

    lesson = Lesson(
        subject_id=subject_id,
        title=title,
        extracted_text=extracted_text,
        status="pending",
    )
    db.add(lesson)
    await db.commit()
    await db.refresh(lesson)
    return lesson


@router.post("/lessons/{lesson_id}/generate", response_model=GenerateLessonResponse)
async def generate_lesson(lesson_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """يبدأ توليد الشرح (نص+أمثلة+صوت) في الخلفية عبر Celery ويعيد فوراً."""
    lesson = (await db.execute(select(Lesson).where(Lesson.id == lesson_id))).scalar_one_or_none()
    if lesson is None:
        raise HTTPException(status_code=404, detail="الدرس غير موجود")
    if not lesson.extracted_text:
        raise HTTPException(status_code=400, detail="لا يوجد نص مستخلص لهذا الدرس بعد")

    task = generate_lesson_content_task.delay(str(lesson_id))
    return GenerateLessonResponse(lesson_id=lesson_id, status="processing", task_id=task.id)


@router.get("/lessons/{lesson_id}/status")
async def lesson_status(lesson_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """يستطلعه تطبيق Flutter كل بضع ثوانٍ حتى تصبح الحالة ready."""
    lesson = (await db.execute(select(Lesson).where(Lesson.id == lesson_id))).scalar_one_or_none()
    if lesson is None:
        raise HTTPException(status_code=404, detail="الدرس غير موجود")
    return {"lesson_id": lesson_id, "status": lesson.status}


@router.get("/lessons/{lesson_id}/script", response_model=LessonScript)
async def lesson_script(lesson_id: uuid.UUID, db: AsyncSession = Depends(get_db)):
    """سيناريو الدرس الجاهز (شرائح + روابط صوت) — يعرضه مشغّل «الفيديو» في Flutter."""
    content = (
        await db.execute(
            select(GeneratedContent).where(GeneratedContent.lesson_id == lesson_id)
        )
    ).scalar_one_or_none()
    if content is None:
        raise HTTPException(status_code=404, detail="الشرح غير جاهز بعد")
    return content.lesson_script
