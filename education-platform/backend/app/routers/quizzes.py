import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Lesson, Quiz, QuizAnswer, QuizAttempt, QuizQuestion
from app.schemas import QuizOut, QuizResultItem, QuizResultOut, SubmitQuizRequest
from app.security import get_current_student_id
from app.services.ai_service import generate_quiz_questions

router = APIRouter(prefix="/quiz", tags=["quiz"])


@router.post("/{lesson_id}/generate", response_model=QuizOut)
async def generate_instant_quiz(
    lesson_id: uuid.UUID,
    question_count: int = 5,
    db: AsyncSession = Depends(get_db),
):
    """اختبار فوري متغيّر بعد إنهاء الدرس (الميزة 4 في المتطلبات)."""
    lesson = (await db.execute(select(Lesson).where(Lesson.id == lesson_id))).scalar_one_or_none()
    if lesson is None or not lesson.extracted_text:
        raise HTTPException(status_code=404, detail="الدرس غير موجود أو بلا نص")

    generated = generate_quiz_questions(lesson.extracted_text, question_count)

    quiz = Quiz(lesson_id=lesson_id, quiz_type="instant", question_count=len(generated["questions"]))
    db.add(quiz)
    await db.flush()

    for index, q in enumerate(generated["questions"]):
        db.add(
            QuizQuestion(
                quiz_id=quiz.id,
                question_text=q["question_text"],
                choices=q["choices"],
                correct_choice_id=q["correct_choice_id"],
                explanation=q.get("explanation"),
                order_index=index,
            )
        )

    await db.commit()
    await db.refresh(quiz, attribute_names=["questions"])
    return quiz


@router.post("/attempts/{quiz_id}/start")
async def start_attempt(
    quiz_id: uuid.UUID,
    student_id: uuid.UUID = Depends(get_current_student_id),
    db: AsyncSession = Depends(get_db),
):
    quiz = (await db.execute(select(Quiz).where(Quiz.id == quiz_id))).scalar_one_or_none()
    if quiz is None:
        raise HTTPException(status_code=404, detail="الاختبار غير موجود")

    attempt = QuizAttempt(quiz_id=quiz_id, student_id=student_id, total_questions=quiz.question_count)
    db.add(attempt)
    await db.commit()
    await db.refresh(attempt)
    return {"attempt_id": attempt.id}


@router.post("/submit", response_model=QuizResultOut)
async def submit_quiz(payload: SubmitQuizRequest, db: AsyncSession = Depends(get_db)):
    """تصحيح تلقائي فوري لكل إجابات الطالب."""
    attempt = (
        await db.execute(select(QuizAttempt).where(QuizAttempt.id == payload.attempt_id))
    ).scalar_one_or_none()
    if attempt is None:
        raise HTTPException(status_code=404, detail="المحاولة غير موجودة")

    results: list[QuizResultItem] = []
    score = 0

    for answer in payload.answers:
        question = (
            await db.execute(select(QuizQuestion).where(QuizQuestion.id == answer.question_id))
        ).scalar_one_or_none()
        if question is None:
            continue

        is_correct = question.correct_choice_id == answer.selected_choice_id
        if is_correct:
            score += 1

        db.add(
            QuizAnswer(
                attempt_id=attempt.id,
                question_id=question.id,
                selected_choice_id=answer.selected_choice_id,
                is_correct=is_correct,
            )
        )
        results.append(
            QuizResultItem(
                question_id=question.id,
                is_correct=is_correct,
                correct_choice_id=question.correct_choice_id,
                explanation=question.explanation,
            )
        )

    attempt.score = score
    from datetime import datetime

    attempt.submitted_at = datetime.utcnow()
    await db.commit()

    return QuizResultOut(
        attempt_id=attempt.id,
        score=score,
        total_questions=attempt.total_questions,
        results=results,
    )
