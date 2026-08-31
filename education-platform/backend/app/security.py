import uuid
from datetime import datetime, timedelta

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt

from app.config import settings

bearer_scheme = HTTPBearer()


def create_access_token(student_id: uuid.UUID) -> str:
    expire = datetime.utcnow() + timedelta(minutes=settings.jwt_expire_minutes)
    payload = {"sub": str(student_id), "exp": expire}
    return jwt.encode(payload, settings.jwt_secret_key, algorithm=settings.jwt_algorithm)


def get_current_student_id(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
) -> uuid.UUID:
    try:
        payload = jwt.decode(
            credentials.credentials, settings.jwt_secret_key, algorithms=[settings.jwt_algorithm]
        )
        return uuid.UUID(payload["sub"])
    except (JWTError, KeyError, ValueError):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="جلسة الدخول غير صالحة أو منتهية"
        )
