"""
Centralized application configuration.

All secrets and environment-dependent values are loaded from environment
variables via pydantic-settings. Nothing here is hard-coded, and this module
is the ONLY place that should call os.environ / read a .env file.
"""
from functools import lru_cache
from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # --- App ---
    APP_NAME: str = "Sai Krishna Enterprises API"
    APP_ENV: str = "development"
    DEBUG: bool = True
    API_V1_PREFIX: str = "/api/v1"
    CORS_ORIGINS: str = "http://localhost:3000,https://ske-business-app.vercel.app"

    # --- Supabase ---
    SUPABASE_URL: str
    SUPABASE_ANON_KEY: str
    SUPABASE_SERVICE_ROLE_KEY: str
    SUPABASE_JWT_SECRET: str

    # --- Database ---
    DATABASE_URL: str

    # --- Storage ---
    SUPABASE_STORAGE_BUCKET_INVOICES: str = "invoices"
    SUPABASE_STORAGE_BUCKET_IMPORTS: str = "imports"

    # --- Security ---
    SECRET_KEY: str

    # --- Background jobs ---
    REDIS_URL: str = "redis://localhost:6379/0"

    # --- Logging ---
    LOG_LEVEL: str = "INFO"

    @property
    def cors_origins_list(self) -> List[str]:
        return [origin.strip() for origin in self.CORS_ORIGINS.split(",") if origin.strip()]

    @property
    def cors_origin_regex(self) -> str | None:
        """
        Outside production, allow any localhost/127.0.0.1 port.

        `flutter run -d chrome` serves the app from an ephemeral port that
        changes on every run, so a static allowlist can never match it and the
        browser blocks every request.

        In production this matches only the exact Vercel domain. It's kept
        as a regex (rather than relying solely on the CORS_ORIGINS
        allowlist) because CORS_ORIGINS is normally set via an env var on
        the host and may not include this domain.
        """
        if self.is_production:
            return r"^https://ske-business-app\.vercel\.app$"
        return r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$"

    @property
    def is_production(self) -> bool:
        return self.APP_ENV == "production"


@lru_cache
def get_settings() -> Settings:
    """Cached settings instance — reads environment once per process."""
    return Settings()
