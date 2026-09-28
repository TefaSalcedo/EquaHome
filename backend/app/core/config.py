from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_prefix="EQUAHOME_", extra="ignore")

    database_url: str = "postgresql+psycopg://equahome:equahome@localhost:5432/equahome"
    jwt_secret: str = "dev-only-change-me"
    jwt_algorithm: str = "HS256"
    access_token_minutes: int = 15
    refresh_token_days: int = 30
    invite_code_length: int = 8
    invite_expiry_days: int = 7
    storage_dir: str = "./uploads"
    ai_provider: str = "mock"
    grok_api_key: str = ""
    grok_model: str = ""
    grok_base_url: str = "https://api.x.ai/v1"


settings = Settings()
