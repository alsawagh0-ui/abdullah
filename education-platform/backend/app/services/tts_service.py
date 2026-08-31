"""تحويل نص كل شريحة إلى ملف صوتي MP3 ورفعه للتخزين الكائني.

مبسّط عمداً: تنفيذ فعلي لموفّر TTS (ElevenLabs/OpenAI/Azure) يُستبدل هنا
حسب الاختيار النهائي في القسم 1.1 من الوثيقة. الواجهة (signature)
مستقرة: نص عربي داخل → رابط MP3 + مدة بالثواني خارج.
"""

import io
import uuid

import boto3
import requests

from app.config import settings

s3_client = boto3.client(
    "s3",
    region_name=settings.s3_region,
    aws_access_key_id=settings.s3_access_key,
    aws_secret_access_key=settings.s3_secret_key,
)


def synthesize_slide_audio(text: str, lesson_id: str, slide_index: int) -> tuple[str, float]:
    """يرسل النص لخدمة TTS، يرفع الناتج لـ S3، ويعيد (audio_url, duration_seconds)."""
    audio_bytes = _call_tts_provider(text)
    key = f"audio/{lesson_id}/slide_{slide_index}.mp3"

    s3_client.upload_fileobj(
        io.BytesIO(audio_bytes),
        settings.s3_bucket,
        key,
        ExtraArgs={"ContentType": "audio/mpeg", "ACL": "public-read"},
    )
    audio_url = f"https://{settings.s3_bucket}.s3.{settings.s3_region}.amazonaws.com/{key}"

    duration_seconds = _get_mp3_duration(audio_bytes)
    return audio_url, duration_seconds


def _call_tts_provider(text: str) -> bytes:
    if settings.tts_provider == "elevenlabs":
        response = requests.post(
            "https://api.elevenlabs.io/v1/text-to-speech/arabic-voice-id",
            headers={"xi-api-key": settings.tts_api_key},
            json={
                "text": text,
                "model_id": "eleven_multilingual_v2",
                "voice_settings": {"stability": 0.5, "similarity_boost": 0.75},
            },
            timeout=60,
        )
        response.raise_for_status()
        return response.content

    if settings.tts_provider == "openai":
        response = requests.post(
            "https://api.openai.com/v1/audio/speech",
            headers={"Authorization": f"Bearer {settings.tts_api_key}"},
            json={"model": "tts-1", "voice": "alloy", "input": text, "response_format": "mp3"},
            timeout=60,
        )
        response.raise_for_status()
        return response.content

    raise ValueError(f"موفّر TTS غير مدعوم: {settings.tts_provider}")


def _get_mp3_duration(audio_bytes: bytes) -> float:
    from mutagen.mp3 import MP3

    return MP3(io.BytesIO(audio_bytes)).info.length


def gen_id() -> str:
    return str(uuid.uuid4())
