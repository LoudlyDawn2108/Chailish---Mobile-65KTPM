"""Cấu hình ứng dụng đọc từ biến môi trường / file .env (pydantic-settings)."""

from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore",
    )

    # --- Ứng dụng ---
    PROJECT_NAME: str = "ChaiLish API"
    VERSION: str = "1.0.0"
    API_V1_STR: str = "/api"
    ENVIRONMENT: str = "development"  # development | test | production
    DEBUG: bool = False
    CORS_ORIGINS: list[str] = ["*"]

    # --- Cơ sở dữ liệu ---
    DATABASE_URL: str = "postgresql+psycopg2://postgres:postgres@localhost:5432/chailish_db"
    DB_ECHO: bool = False

    # --- Bảo mật / JWT ---
    SECRET_KEY: str = "chailish_secret_key_development_only_2026"
    JWT_ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30

    # --- Dịch vụ bên ngoài ---
    ANTHROPIC_API_KEY: str = ""
    AZURE_SPEECH_KEY: str = ""
    AZURE_SPEECH_REGION: str = "southeastasia"


@lru_cache
def get_settings() -> Settings:
    return Settings()


settings = get_settings()
