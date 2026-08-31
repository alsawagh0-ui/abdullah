from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str
    redis_url: str = "redis://localhost:6379/0"

    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_expire_minutes: int = 1440

    anthropic_api_key: str
    llm_model: str = "claude-sonnet-5"

    tts_provider: str = "elevenlabs"
    tts_api_key: str = ""

    s3_bucket: str = ""
    s3_region: str = ""
    s3_access_key: str = ""
    s3_secret_key: str = ""

    class Config:
        env_file = ".env"


settings = Settings()
