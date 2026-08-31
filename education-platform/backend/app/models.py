import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Integer, String, Text, DateTime, JSON
from sqlalchemy.dialects.postgresql import UUID, JSONB
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


def gen_uuid() -> uuid.UUID:
    return uuid.uuid4()


class Student(Base):
    __tablename__ = "students"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    civil_id: Mapped[str | None] = mapped_column(String(20), unique=True, nullable=True)
    student_number: Mapped[str | None] = mapped_column(String(30), unique=True, nullable=True)
    full_name: Mapped[str] = mapped_column(String(200))
    grade_level: Mapped[str] = mapped_column(String(20))
    school_id: Mapped[str] = mapped_column(String(50))
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    enrollments: Mapped[list["Enrollment"]] = relationship(back_populates="student")


class Subject(Base):
    __tablename__ = "subjects"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    name: Mapped[str] = mapped_column(String(120))
    grade_level: Mapped[str] = mapped_column(String(20))
    school_id: Mapped[str] = mapped_column(String(50))

    lessons: Mapped[list["Lesson"]] = relationship(back_populates="subject")


class Enrollment(Base):
    __tablename__ = "enrollments"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    subject_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("subjects.id"))
    enrolled_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    student: Mapped[Student] = relationship(back_populates="enrollments")
    subject: Mapped[Subject] = relationship()


class Lesson(Base):
    __tablename__ = "lessons"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    subject_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("subjects.id"))
    title: Mapped[str] = mapped_column(String(300))
    source_file_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    extracted_text: Mapped[str | None] = mapped_column(Text, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="pending")  # pending|processing|ready|failed
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    subject: Mapped[Subject] = relationship(back_populates="lessons")
    generated_content: Mapped["GeneratedContent"] = relationship(back_populates="lesson", uselist=False)


class GeneratedContent(Base):
    __tablename__ = "generated_content"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    lesson_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lessons.id"), unique=True)
    lesson_script: Mapped[dict] = mapped_column(JSONB)
    llm_model_used: Mapped[str] = mapped_column(String(50))
    total_duration_seconds: Mapped[int] = mapped_column(Integer)
    generated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    lesson: Mapped[Lesson] = relationship(back_populates="generated_content")


class Quiz(Base):
    __tablename__ = "quizzes"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    lesson_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("lessons.id"))
    quiz_type: Mapped[str] = mapped_column(String(20), default="instant")  # instant|comprehensive
    question_count: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    questions: Mapped[list["QuizQuestion"]] = relationship(back_populates="quiz")


class QuizQuestion(Base):
    __tablename__ = "quiz_questions"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    quiz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quizzes.id"))
    question_text: Mapped[str] = mapped_column(Text)
    choices: Mapped[list] = mapped_column(JSON)  # [{"id": "a", "text": "..."}]
    correct_choice_id: Mapped[str] = mapped_column(String(10))
    explanation: Mapped[str | None] = mapped_column(Text, nullable=True)
    order_index: Mapped[int] = mapped_column(Integer, default=0)

    quiz: Mapped[Quiz] = relationship(back_populates="questions")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    quiz_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quizzes.id"))
    student_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("students.id"))
    score: Mapped[int] = mapped_column(Integer, default=0)
    total_questions: Mapped[int] = mapped_column(Integer)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    submitted_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class QuizAnswer(Base):
    __tablename__ = "quiz_answers"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=gen_uuid)
    attempt_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quiz_attempts.id"))
    question_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("quiz_questions.id"))
    selected_choice_id: Mapped[str] = mapped_column(String(10))
    is_correct: Mapped[bool] = mapped_column(default=False)
