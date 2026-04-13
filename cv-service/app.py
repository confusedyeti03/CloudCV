# =============================================================================
# CloudCV FastAPI Application
# =============================================================================
# PURPOSE: API with /visits counter and PDF generation
#
# WHAT TO DO:
# 1. Install dependencies: pip install -r requirements.txt
# 2. Run: uvicorn app:app --reload
# 3. Docs: http://localhost:8000/docs
#
# ENDPOINTS:
# - GET  /visits     → Returns current counter
# - POST /visits     → Increments counter
# - GET  /pdf?lang=  → Generates PDF with WeasyPrint (ca/es/en)
# - GET  /health     → Health check
#
# SECURITY:
# - CORS restricted to allowed origins
# - Language parameter validated (whitelist)
# - Path traversal protection
# - Modern lifespan pattern for startup/shutdown
# =============================================================================

import os
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
import yaml
from pathlib import Path

from database import Database
from pdf_generator import generate_pdf

# Configuration from environment with safe defaults
ALLOWED_ORIGINS = os.getenv(
    "CORS_ORIGINS",
    "https://lnoval.dev,https://www.lnoval.dev"
).split(",")

# Valid languages (whitelist)
VALID_LANGUAGES = {"ca", "es", "en"}

# Base paths
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
TEMPLATES_DIR = BASE_DIR / "templates"
STATIC_DIR = BASE_DIR / "static"
ASSETS_DIR = BASE_DIR / "assets"
FALLBACK_ASSETS_DIR = BASE_DIR.parent / "web" / "assets"
GENERATED_DIR = BASE_DIR / "generated"


def resolve_assets_dir() -> Path:
    """
    Resolve the assets directory used for static serving
    """
    if (ASSETS_DIR / "photo.webp").exists():
        return ASSETS_DIR
    if FALLBACK_ASSETS_DIR.exists():
        return FALLBACK_ASSETS_DIR
    return ASSETS_DIR


SERVE_ASSETS_DIR = resolve_assets_dir()

# Templates
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))

# Initialize database
db = Database()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifespan context manager for startup and shutdown events.
    Replaces deprecated @app.on_event decorators.
    """
    # Startup
    db.init_db()
    GENERATED_DIR.mkdir(parents=True, exist_ok=True)
    warmup_pdfs()
    yield
    # Shutdown
    db.close_all_connections()


# Initialize FastAPI app with lifespan
app = FastAPI(
    title="CloudCV API",
    description="API per comptador de visites i generació PDF",
    version="1.0.0",
    lifespan=lifespan
)

# Static files
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
app.mount("/assets", StaticFiles(directory=str(SERVE_ASSETS_DIR)), name="assets")

# CORS middleware - restricted to allowed origins
# In development, add "http://localhost:3000" to CORS_ORIGINS env var
app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type", "Accept", "Accept-Language"],
)


def get_cv_data_path(lang: str) -> Path:
    """
    Resolve and validate CV data path for language
    """
    data_path = (DATA_DIR / f"cv_{lang}.yml").resolve()
    if not str(data_path).startswith(str(DATA_DIR.resolve())):
        raise HTTPException(
            status_code=400,
            detail="Invalid language parameter"
        )
    if not data_path.exists():
        raise HTTPException(
            status_code=404,
            detail=f"CV data not found for language: {lang}"
        )
    return data_path


def load_cv_data(lang: str) -> dict:
    """
    Load CV data from YAML for a given language
    """
    data_path = get_cv_data_path(lang)
    with open(data_path, "r", encoding="utf-8") as file:
        cv_data = yaml.safe_load(file)

    if not cv_data or not isinstance(cv_data, dict):
        raise HTTPException(
            status_code=500,
            detail="Invalid CV data format"
        )

    return cv_data


def get_pdf_path(lang: str) -> Path:
    """
    Build the cached PDF path for a language
    """
    return GENERATED_DIR / f"cv_{lang}.pdf"


def needs_regeneration(lang: str, pdf_path: Path) -> bool:
    """
    Determine if a PDF should be regenerated based on source timestamps
    """
    if not pdf_path.exists():
        return True

    sources = [
        get_cv_data_path(lang),
        TEMPLATES_DIR / "cv.html",
    ]

    photo_path = SERVE_ASSETS_DIR / "photo.webp"
    if photo_path.exists():
        sources.append(photo_path)

    latest_source = max(source.stat().st_mtime for source in sources if source.exists())
    return pdf_path.stat().st_mtime < latest_source


def generate_and_cache_pdf(lang: str) -> Path:
    """
    Generate PDF and store in cache directory
    """
    cv_data = load_cv_data(lang)
    assets_base = SERVE_ASSETS_DIR.parent
    pdf_bytes = generate_pdf(cv_data, lang, base_url=str(assets_base))

    if not pdf_bytes:
        raise HTTPException(
            status_code=500,
            detail="PDF generation returned empty result"
        )

    pdf_path = get_pdf_path(lang)
    pdf_path.write_bytes(pdf_bytes)
    return pdf_path


def ensure_pdf(lang: str) -> Path:
    """
    Ensure a cached PDF exists and is fresh
    """
    pdf_path = get_pdf_path(lang)
    if needs_regeneration(lang, pdf_path):
        return generate_and_cache_pdf(lang)
    return pdf_path


def warmup_pdfs() -> None:
    """
    Pre-generate all PDFs on startup
    """
    import logging

    for lang in sorted(VALID_LANGUAGES):
        try:
            ensure_pdf(lang)
        except Exception as exc:
            logging.warning(f"PDF warmup failed for {lang}: {exc}")


@app.get("/visits")
async def get_visits():
    """
    Get current visit count
    
    Returns:
        dict: {"count": int}
    """
    count = db.get_visit_count()
    return {"count": count}


@app.post("/visits")
async def increment_visits():
    """
    Increment visit counter and return new value
    
    Returns:
        dict: {"count": int}
    """
    new_count = db.increment_visits()
    return {"count": new_count}


@app.get("/")
async def cv_page(request: Request):
    """
    Serve the CV HTML page with PDF preview
    """
    return templates.TemplateResponse(
        "cv_page.html",
        {
            "request": request,
        }
    )


@app.get("/preview/{lang}")
async def preview_cv_pdf(lang: str):
    """
    Serve the PDF inline for preview
    """
    if lang not in VALID_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid language. Must be one of: {', '.join(sorted(VALID_LANGUAGES))}"
        )

    try:
        pdf_path = ensure_pdf(lang)
        filename = f"CV_Lluis_Noval_{lang}.pdf"
        return FileResponse(
            path=pdf_path,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'inline; filename="{filename}"',
                "X-Content-Type-Options": "nosniff",
                "Cache-Control": "no-store, max-age=0"
            }
        )
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.error(f"PDF preview failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail="PDF preview failed. Please try again later."
        )


@app.get("/download/{lang}")
async def download_cv_pdf(lang: str):
    """
    Serve the PDF as attachment for download
    """
    if lang not in VALID_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid language. Must be one of: {', '.join(sorted(VALID_LANGUAGES))}"
        )

    try:
        pdf_path = ensure_pdf(lang)
        filename = f"CV_Lluis_Noval_{lang}.pdf"
        return FileResponse(
            path=pdf_path,
            media_type="application/pdf",
            headers={
                "Content-Disposition": f'attachment; filename="{filename}"',
                "X-Content-Type-Options": "nosniff",
                "Cache-Control": "no-store, max-age=0"
            }
        )
    except HTTPException:
        raise
    except Exception as exc:
        import logging
        logging.error(f"PDF download failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail="PDF download failed. Please try again later."
        )


@app.get("/pdf")
async def generate_cv_pdf(lang: str = Query("ca", regex="^(ca|es|en)$")):
    """
    Generate PDF from YAML data using WeasyPrint
    
    This is the fallback for users without JavaScript.
    
    Args:
        lang: Language code (ca, es, en)
    
    Returns:
        PDF file as downloadable response
    """
    # Defense in depth: validate language even though Query regex should catch it
    if lang not in VALID_LANGUAGES:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid language. Must be one of: {', '.join(sorted(VALID_LANGUAGES))}"
        )
    
    return await download_cv_pdf(lang)


@app.get("/health")
async def health_check():
    """
    Health check endpoint for monitoring
    
    Returns:
        dict: {"status": "healthy"}
    """
    return {"status": "healthy"}
