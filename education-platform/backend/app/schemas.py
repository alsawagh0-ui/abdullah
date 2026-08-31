import uuid
from datetime import datetime

from pydantic import BaseModel


class LoginRequest(BaseModel):
    identifier: str  # الرقم المدني أو رقم الطالب
    id_type: str = "civil_id"  # "civil_id" | "student_number"


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    student_id: uuid.UUID
    full_name: str


class SubjectOut(BaseModel):
    id: uuid.UUID
    name: str
    grade_level: str

    class Config:
        from_attributes = True


class LessonOut(BaseModel):
    id: uuid.UUID
    title: str
    status: str

    class Config:
        from_attributes = True


class GenerateLessonResponse(BaseModel):
    lesson_id: uuid.UUID
    status: str
    task_id: str


class LessonSlide(BaseModel):
    slide_index: int
    type: str  # intro | example | summary
    title: str
    body_text: str
    bullet_points: list[str] = []
    audio_url: str | None = None
    duration_seconds: float = 0
    image_url: str | None = None


class LessonScript(BaseModel):
    lesson_id: str
    subject: str
    title: str
    generated_at: datetime
    total_duration_seconds: int
    slides: list[LessonSlide]


class QuizChoice(BaseModel):
    id: str
    text: str


class QuizQuestionOut(BaseModel):
    id: uuid.UUID
    question_text: str
    choices: list[QuizChoice]
    order_index: int

    class Config:
        from_attributes = True


class QuizOut(BaseModel):
    id: uuid.UUID
    quiz_type: str
    questions: list[QuizQuestionOut]

    class Config:
        from_attributes = True


class SubmitAnswerItem(BaseModel):
    question_id: uuid.UUID
    selected_choice_id: str


class SubmitQuizRequest(BaseModel):
    attempt_id: uuid.UUID
    answers: list[SubmitAnswerItem]


class QuizResultItem(BaseModel):
    question_id: uuid.UUID
    is_correct: bool
    correct_choice_id: str
    explanation: str | None = None


class QuizResultOut(BaseModel):
    attempt_id: uuid.UUID
    score: int
    total_questions: int
    results: list[QuizResultItem]
