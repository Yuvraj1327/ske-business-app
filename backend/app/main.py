"""
Application entrypoint.

Run locally with:
    uvicorn app.main:app --reload --port 8000
"""
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from loguru import logger
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.api.v1.router import api_router
from app.config import get_settings
from app.core.exception_handlers import register_exception_handlers

settings = get_settings()

# --- Logging setup ---
logger.remove()
logger.add(sys.stderr, level=settings.LOG_LEVEL, backtrace=False, diagnose=settings.DEBUG)

# --- Rate limiting (basic, per-IP) ---
limiter = Limiter(key_func=get_remote_address)

app = FastAPI(
    title=settings.APP_NAME,
    debug=settings.DEBUG,
    version="1.0.0",
    docs_url="/docs" if not settings.is_production else None,
    redoc_url="/redoc" if not settings.is_production else None,
)

app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_origin_regex=settings.cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)

app.include_router(api_router, prefix=settings.API_V1_PREFIX)


@app.on_event("startup")
async def on_startup():
    logger.info(f"{settings.APP_NAME} starting in '{settings.APP_ENV}' mode")


@app.get("/")
async def root():
    return {"message": settings.APP_NAME, "docs": "/docs", "api": settings.API_V1_PREFIX}
