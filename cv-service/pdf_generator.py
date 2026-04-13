# =============================================================================
# PDF Generator using WeasyPrint
# =============================================================================
# PURPOSE: Genera PDF des de dades CV usant Jinja2 templates i WeasyPrint
#
# WHAT TO DO:
# 1. Template HTML a templates/cv_template.html
# 2. Jinja2 renderitza el template amb les dades
# 3. WeasyPrint converteix HTML a PDF
#
# NOTE: WeasyPrint requereix dependencies del sistema (GTK, Pango, etc.)
#       A Ubuntu: apt install libpango-1.0-0 libpangocairo-1.0-0
# =============================================================================

from weasyprint import HTML
from jinja2 import Environment, FileSystemLoader
from pathlib import Path


def generate_pdf(cv_data: dict, lang: str, base_url: str | None = None) -> bytes:
    """
    Generate PDF from CV data using WeasyPrint
    
    Args:
        cv_data: Dictionary with CV information (from YAML)
        lang: Language code (ca/es/en) for template labels
    
    Returns:
        PDF file as bytes
    
    Example:
        pdf_bytes = generate_pdf(cv_data, 'ca')
        with open('cv.pdf', 'wb') as f:
            f.write(pdf_bytes)
    """
    # Setup Jinja2 environment
    templates_dir = Path(__file__).parent / "templates"
    env = Environment(loader=FileSystemLoader(str(templates_dir)))
    
    # Load template
    template = env.get_template("cv.html")
    
    # Render HTML with CV data
    html_content = template.render(
        cv=cv_data,
        lang=lang
    )
    
    # Generate PDF using WeasyPrint
    if base_url is None:
        base_url = str(Path(__file__).parent)

    pdf = HTML(string=html_content, base_url=base_url).write_pdf()
    
    return pdf
