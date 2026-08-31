from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.models import Student
from app.schemas import LoginRequest, TokenResponse
from app.security import create_access_token

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/login", response_model=TokenResponse)
async def login(payload: LoginRequest, db: AsyncSession = Depends(get_db)):
    """تسجيل دخول الطالب بالرقم المدني أو رقم الطالب (بلا كلمة مرور).

    يفترض أن بيانات الطلاب مستوردة مسبقاً من نظام المدرسة (استيراد دفعي
    أو تكامل SSO)؛ هذه النقطة تطابق فقط ولا تنشئ حسابات جديدة.
    """
    if payload.id_type == "civil_id":
        stmt = select(Student).where(Student.civil_id == payload.identifier)
    elif payload.id_type == "student_number":
        stmt = select(Student).where(Student.student_number == payload.identifier)
    else:
        raise HTTPException(status_code=400, detail="نوع تعريف غير مدعوم")

    student = (await db.execute(stmt)).scalar_one_or_none()
    if student is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="لم يُعثر على طالب بهذا الرقم. تأكد من الرقم أو راجع إدارة المدرسة",
        )

    token = create_access_token(student.id)
    return TokenResponse(access_token=token, student_id=student.id, full_name=student.full_name)
